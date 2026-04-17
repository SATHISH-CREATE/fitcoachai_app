import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:flutter_pose_detection/flutter_pose_detection.dart';
import 'package:gal/gal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_background.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/web_utils.dart';
import '../../../../shared/utils/auth_utils.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../shared/providers/notifications_provider.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  final String exercise;
  const WorkoutScreen({super.key, required this.exercise});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> with TickerProviderStateMixin {
  CameraController? _cameraController;
  NpuPoseDetector? _poseDetector;
  bool _isInitialized = false;
  String? _initError;
  bool _isRecording = false;
  bool _isDetecting = false;
  bool _isProcessing = false;
  bool _isSyncing = false;
  bool _isBackendAlive = false;
  
  int _counter = 0;
  String _feedback = "Ready to start";
  double _angle = 0;
  double _target = 0;
  String _stage = "--";
  double _accuracy = 0;
  String _sessionLog = "Position your body in view";
  int _recordingSeconds = 0;
  int _activeSeconds = 0;
  bool _isCorrectPosture = true;
  List<int> _incorrectIndices = [];
  Timer? _recordingTimer;
  Timer? _activeTimer;
  int _frameCounter = 0; // HYBRID LSTM UPGRADE - Performance tracking

  final ValueNotifier<List<dynamic>> _landmarkNotifier = ValueNotifier([]);
  final List<List<dynamic>> _landmarkBuffer = [];
  int _lastDetectionFrame = 0;
  final int _bufferSize = 3; // Slight smoothing but still fast
  late AnimationController _feedbackAnim;

  @override
  void initState() {
    super.initState();
    _feedbackAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    
    // Defer initialization slightly to ensure build context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
      final userId = ref.read(authProvider).user?.id;
      ApiService.resetSession(userId: userId);
    });
    
    _initVoiceCommandListener();
  }

  void _initVoiceCommandListener() async {
    // Request microphone permission with better handling
    final status = await Permission.microphone.status;
    if (status.isDenied) {
      final requested = await Permission.microphone.request();
      if (!requested.isGranted) {
        debugPrint("VOICE DEBUG: Microphone permission denied");
        return;
      }
    }
    
    if (await Permission.microphone.isGranted) {
      debugPrint("VOICE DEBUG: Starting Voice Command Listener...");
      VoiceService.startListening((command) {
        if (!mounted) return;
        debugPrint("VOICE COMMAND RECEIVED: $command");
        
        final lowerCommand = command.toLowerCase();

        if (lowerCommand.contains("finish") || lowerCommand.contains("done") || lowerCommand.contains("complete")) {
          _finishWorkout();
        } 
        else if (lowerCommand.contains("pause") || lowerCommand.contains("stop") || lowerCommand.contains("hold") || lowerCommand.contains("wait")) {
          if (_isDetecting) _togglePoseDetection();
        } 
        else if (lowerCommand.contains("start") || lowerCommand.contains("resume") || lowerCommand.contains("go") || lowerCommand.contains("begin")) {
          if (!_isDetecting) _togglePoseDetection();
        } 
        else if (lowerCommand.contains("record") || lowerCommand.contains("video") || lowerCommand.contains("save") || lowerCommand.contains("film")) {
          _toggleRecording();
        } 
        else if (lowerCommand.contains("flip") || lowerCommand.contains("switch") || lowerCommand.contains("camera") || lowerCommand.contains("reverse")) {
          _flipCamera();
        }
        else if (lowerCommand.contains("how many") || lowerCommand.contains("count") || lowerCommand.contains("reps") || lowerCommand.contains("stats")) {
          VoiceService.speak("You have completed $_counter reps so far.");
        }
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.dispose();
    _feedbackAnim.dispose();
    _landmarkNotifier.dispose();
    _activeTimer?.cancel();
    _recordingTimer?.cancel();
    if (kIsWeb) WebSync.stopPose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      // 🚨 CRITICAL: Request permissions FIRST to prevent native crash
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted) {
        throw 'Camera permission is required to analyze your workout.';
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) throw 'No cameras found';
      
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first
      );
      
      try {
        _cameraController = CameraController(
          front, 
          ResolutionPreset.low, 
          enableAudio: micStatus.isGranted,
          imageFormatGroup: kIsWeb ? null : (Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888),
        );
        await _cameraController!.initialize();
      } catch (e) {
        debugPrint('CAMERA DEBUG: Primary init failed, trial fallback: $e');
        _cameraController = CameraController(
          front, 
          ResolutionPreset.low, 
          enableAudio: false,
          imageFormatGroup: kIsWeb ? null : (Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888),
        );
        await _cameraController!.initialize();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _initError = null;
        });
      }

      if (!kIsWeb) {
        try {
          // HYBRID LSTM UPGRADE - Optimized for performance
          // Initialize with smaller models or faster acceleration if available
          var config = PoseDetectorConfig(
            preferredAcceleration: AccelerationMode.gpu,
          );
          _poseDetector = NpuPoseDetector(config: config);
          
          // Timeout the initialization to prevent 5-minute hang
          final initFuture = _poseDetector!.initialize();
          final mode = await initFuture.timeout(const Duration(seconds: 15), onTimeout: () {
            debugPrint('POSE DEBUG: GPU Initialization timed out');
            throw 'Initialization timed out';
          });
          
          debugPrint('POSE DEBUG: Pose Detector initialized with GPU: $mode');
        } catch (e) {
          debugPrint('POSE DEBUG: GPU failed or timed out, falling back to CPU: $e');
          var config = PoseDetectorConfig(preferredAcceleration: AccelerationMode.cpu);
          _poseDetector = NpuPoseDetector(config: config);
          await _poseDetector!.initialize().timeout(const Duration(seconds: 15));
          debugPrint('POSE DEBUG: CPU Initialization complete');
        }
      }
    } catch (e) {
      debugPrint('Camera Error: $e');
      if (mounted) setState(() => _initError = "Camera Error: $e");
    }
  }

  void _togglePoseDetection() async {
    if (AuthUtils.requireLogin(context: context, ref: ref)) return;

    if (_isDetecting) {
      if (kIsWeb) {
        WebSync.stopPose();
      } else {
        _cameraController?.stopImageStream();
      }
      
      setState(() {
        _isDetecting = false;
        _isBackendAlive = false;
        _landmarkNotifier.value = [];
        _feedback = "AI Paused";
      });
      // Do not stop listening so user can say "start" or "resume"
    } else {
      final micStatus = await Permission.microphone.status;
      if (micStatus.isDenied) {
        await Permission.microphone.request();
      }
      
      ApiService.resetSession();
      setState(() {
        _isDetecting = true;
        _isBackendAlive = false; 
        _feedback = "Connecting to AI...";
        _counter = 0;
        _landmarkNotifier.value = [];
      });
      
      VoiceService.speak("Starting ${widget.exercise}. Get ready!");

      if (kIsWeb) {
        WebSync.startPose(_handleLandmarks);
      } else {
        _isSyncing = false;
        _frameCounter = 0;
        
        // Start image stream immediately, don't wait 500ms
        if (_cameraController != null) {
          try {
            debugPrint("POSE DEBUG: Starting image stream...");
            try { await _cameraController!.stopImageStream(); } catch (_) {}
            
            await _cameraController!.startImageStream((image) {
              if (_isDetecting) _processImage(image);
            });
            debugPrint("POSE DEBUG: Image stream started");
          } catch (e) {
            debugPrint("POSE DEBUG: Stream Error: $e");
          }
        }
      }

      _activeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted && _isDetecting) setState(() => _activeSeconds++);
      });

      // Voice Service listener is now initialized in initState
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (!_isDetecting) return;
    if (_isProcessing) {
       // Frame skipping is normal, but let's log if it's constant
       if (_frameCounter % 30 == 0) debugPrint("POSE DEBUG: Skipping frame (busy)");
       return;
    }
    _isProcessing = true;
    _frameCounter++; 
    if (_frameCounter % 10 == 0) debugPrint("POSE DEBUG: Processing Frame #$_frameCounter");

    try {
      final planes = image.planes.map((p) => {
        'bytes': p.bytes,
        'bytesPerRow': p.bytesPerRow,
        'bytesPerPixel': p.bytesPerPixel,
      }).toList();
      
      final isFront = _cameraController!.description.lensDirection == CameraLensDirection.front;
      final result = await _poseDetector!.processFrame(
        planes: planes,
        width: image.width,
        height: image.height,
        format: Platform.isAndroid ? 'nv21' : 'bgra8888',
        rotation: isFront ? 270 : 90,
      ).timeout(const Duration(milliseconds: 500));
      
      final bool hasPosesFound = result.poses.isNotEmpty;
      if (hasPosesFound) {
        _lastDetectionFrame = _frameCounter;
        final List<dynamic> landmarks = [];
        final pose = result.poses.first;
        final poseLandmarks = pose.landmarks;
        
        for (int i = 0; i < 33; i++) {
          if (i < poseLandmarks.length) {
            final lm = poseLandmarks[i];
            landmarks.add({
              'x': lm.x, 'y': lm.y, 'z': lm.z, 'worldZ': lm.z, 'likelihood': lm.visibility,
            });
          } else {
            landmarks.add({'x': 0.0, 'y': 0.0, 'z': 0.0, 'worldZ': 0.0, 'likelihood': 0.0});
          }
        }
        
        final smoothed = _smoothLandmarks(landmarks);
        
        if (mounted) {
          _landmarkNotifier.value = smoothed;
          _updateLocalMetrics(smoothed);

          if (!_isSyncing) {
            unawaited(_processExercise(smoothed));
          }
        }
      } else {
        // If detection is lost briefly, don't clear lines immediately to avoid flickering
        // Keep lines for 5 frames (~150-200ms)
        if (_frameCounter - _lastDetectionFrame > 5) {
          if (mounted && _landmarkNotifier.value.isNotEmpty) {
            _landmarkNotifier.value = [];
          }
        }
      }
    } catch (e) {
      // debugPrint('Pose Detection Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  List<dynamic> _smoothLandmarks(List<dynamic> current) {
    if (_landmarkBuffer.length >= _bufferSize) _landmarkBuffer.removeAt(0);
    _landmarkBuffer.add(current);
    if (_landmarkBuffer.length < 2) return current;
    
    final int len = current.length;
    final int bufLen = _landmarkBuffer.length;
    final List<dynamic> smooth = List.filled(len, null);
    
    for (int i = 0; i < len; i++) {
      double sumX = 0, sumY = 0, sumZ = 0, sumW = 0, sumL = 0;
      for (var frame in _landmarkBuffer) {
        sumX += frame[i]['x']; sumY += frame[i]['y']; sumZ += frame[i]['z']; sumW += frame[i]['worldZ'] ?? 0.0; sumL += frame[i]['likelihood'];
      }
      smooth[i] = {
        'x': sumX / bufLen,
        'y': sumY / bufLen,
        'z': sumZ / bufLen,
        'worldZ': sumW / bufLen,
        'likelihood': sumL / bufLen,
      };
    }
    return smooth;
  }

  void _updateLocalMetrics(List<dynamic> landmarks) {
    if (landmarks.length < 33) return;
    
    // Quick local angle calculation for visual display
    // Uses the same logic as backend but purely for UI smoothing
    // Pick the side that is more visible (Safe Compare)
    final double lLikelihood = (landmarks[11]['likelihood'] as num?)?.toDouble() ?? 0.0;
    final double rLikelihood = (landmarks[12]['likelihood'] as num?)?.toDouble() ?? 0.0;
    
    if (rLikelihood > lLikelihood) {
      sIdx = 12; eIdx = 14; wIdx = 16;
    }
    
    final s = landmarks[sIdx];
    final e = landmarks[eIdx];
    final w = landmarks[wIdx];
    
    final double angle = _calculateLocalAngle(
      Offset(s['x'], s['y']), 
      Offset(e['x'], e['y']), 
      Offset(w['x'], w['y'])
    );
    
    if (mounted) {
      setState(() {
        _angle = angle;
      });
    }
  }

  double _calculateLocalAngle(Offset a, Offset b, Offset c) {
    final double radians = atan2(c.dy - b.dy, c.dx - b.dx) - atan2(a.dy - b.dy, a.dx - b.dx);
    double angle = (radians * 180 / pi).abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  void _handleLandmarks(String json) {
    if (!mounted || !_isDetecting) return;
    try {
      final List<dynamic> raw = jsonDecode(json);
      _landmarkNotifier.value = raw;
      _processExercise(raw);
    } catch (e) { debugPrint('Pose Error: $e'); }
  }

  Future<void> _processExercise(List<dynamic> landmarks) async {
    if (landmarks.isEmpty || landmarks.length < 33 || !_isDetecting || _isSyncing) {
       if (_isSyncing && _frameCounter % 10 == 0) debugPrint("POSE DEBUG: Syncing busy...");
       return;
    }
    
    // Maximum Sync Frequency: Send every frame if not busy
    // if (_frameCounter % 2 != 0) return;
    
    // debugPrint("POSE DEBUG: Attempting Sync for ${widget.exercise}");

    _isSyncing = true;
    try {
      final authState = ref.read(authProvider);
      final userId = authState.user?.id ?? "mobile_user";
      
      final result = await ApiService.processLandmarks(
        userId, 
        List<Map<String, dynamic>>.from(landmarks), 
        widget.exercise
      ).timeout(const Duration(milliseconds: 3000), onTimeout: () {
         debugPrint("POSE DEBUG: Backend sync timed out (3s)");
         return {};
      });
      
      debugPrint("POSE DEBUG: Backend responded with ${result.keys.length} fields");

      if (mounted && result.isNotEmpty) {
        _isBackendAlive = true;
        final newCount = result['rep_count'] ?? 0;
        final hasNewRep = newCount > _counter;
        
        setState(() {
          _counter = newCount;
          _stage = result['form'] ?? "--";
          _angle = (result['current_angle'] as num?)?.toDouble() ?? 0.0;
          _target = (result['target_angle'] as num?)?.toDouble() ?? 0.0;
          _accuracy = (result['accuracy'] as num?)?.toDouble() ?? 0.0;
          _isCorrectPosture = result['is_correct'] ?? true;
          _incorrectIndices = List<int>.from(result['incorrect_indices'] ?? []);
          
          final newFeedback = result['feedback'] ?? _feedback;
          if (newFeedback != "Ready" && newFeedback.isNotEmpty) {
            _sessionLog = newFeedback;
            _feedback = newFeedback;
          }
          
           if (hasNewRep) {
             unawaited(VoiceService.announceRep(newCount));
             _updateFeedback(newFeedback, announce: true);
             unawaited(VoiceService.motivate(newCount));
           } else if (_feedback != newFeedback && newFeedback.isNotEmpty) {
             _updateFeedback(newFeedback, announce: false);
           }
        });
      }
    } catch (e) { 
      debugPrint('Sync Error: $e'); 
      if (mounted) setState(() => _isBackendAlive = false);
    } finally { 
      _isSyncing = false; 
    }
  }

  void _updateFeedback(String msg, {bool announce = false}) {
    if (!mounted) return;
    _feedbackAnim.forward(from: 0);
    if (announce) unawaited(VoiceService.speak(msg));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildPoseOverlay(),
          _buildUiOverlay(),
        ],
      ),
    );
  }

  Widget _buildUiOverlay() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  top: 20, left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildClassicStats(),
                      const SizedBox(height: 16),
                      _buildListeningIndicator(),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 20, left: 20, right: 20,
                  child: _buildSessionLog(),
                ),
              ],
            ),
          ),
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(widget.exercise.toUpperCase(), 
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
          ),
          const SizedBox(width: 40), // Placeholder to keep title centered
        ],
      ),
    );
  }

  Widget _buildListeningIndicator() {
    if (!_isDetecting) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).scale(duration: 600.ms, begin: const Offset(1,1), end: const Offset(1.5, 1.5)).then().scale(duration: 600.ms, begin: const Offset(1.5,1.5), end: const Offset(1, 1)),
          const SizedBox(width: 8),
          Text('AI LISTENING', style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }


  Widget _buildClassicStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COUNT:', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text('$_counter', style: GoogleFonts.outfit(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold, height: 1.0)),
        const SizedBox(height: 12),
        Text('Angle: ${_angle.round()}°', style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 14)),
        Text('Target: ${_target.round()}°', style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 14)),
        Text('Stage: $_stage', style: GoogleFonts.outfit(color: Colors.cyan, fontSize: 14)),
        Text('Accuracy: ${_accuracy.round()}%', style: GoogleFonts.outfit(color: Colors.cyan, fontSize: 14)),
      ],
    );
  }

  Widget _buildSessionLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SESSION LOG:', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
          child: Text(_sessionLog, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          Row(
            children: [
              _controlBtn(
                _isDetecting ? "PAUSE" : "START", 
                _isDetecting ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                _isDetecting ? Colors.black.withOpacity(0.4) : AppColors.primary, 
                _isDetecting ? Colors.white : Colors.white,
                _togglePoseDetection,
                isPrimary: !_isDetecting,
              ),
              const SizedBox(width: 12),
              _controlBtn(
                _isRecording ? "STOP REC" : "RECORD", 
                _isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded, 
                _isRecording ? Colors.redAccent : Colors.white.withOpacity(0.1), 
                Colors.white, 
                _toggleRecording
              ),
              const SizedBox(width: 12),
               _controlBtn("FINISH", Icons.check_rounded, Colors.tealAccent.shade700, Colors.black, _finishWorkout),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _controlBtn(
                "FLIP CAMERA", 
                Icons.flip_camera_ios_rounded, 
                Colors.white.withOpacity(0.2), 
                Colors.white, 
                _flipCamera
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlBtn(String label, IconData icon, Color bg, Color textCol, VoidCallback onTap, {bool isPrimary = false}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isPrimary ? [BoxShadow(color: bg.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textCol, size: 20),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.outfit(color: textCol, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isInitialized && _cameraController != null) {
      final isFront = _cameraController!.description.lensDirection == CameraLensDirection.front;
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize!.height,
            height: _cameraController!.value.previewSize!.width,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(isFront ? -1.0 : 1.0, 1.0, 1.0),
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
  }

  Widget _buildPoseOverlay() {
    if (!_isInitialized || !_isDetecting || _cameraController == null) return const SizedBox.shrink();
    final isFront = _cameraController!.description.lensDirection == CameraLensDirection.front;
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
            child: ValueListenableBuilder<List<dynamic>>(
              valueListenable: _landmarkNotifier,
              builder: (context, data, _) => CustomPaint(
                painter: _PosePainter(data, _isCorrectPosture, _incorrectIndices, _angle, isFront),
              ),
            ),
        ),
      ),
    );
  }

  void _flipCamera() async {
    if (_cameraController == null || _isProcessing) return;
    
    final wasDetecting = _isDetecting;
    if (wasDetecting) {
      if (kIsWeb) {
        WebSync.stopPose();
      } else {
        await _cameraController!.stopImageStream();
      }
    }

    final cameras = await availableCameras();
    final current = _cameraController!.description;
    final next = cameras.firstWhere(
      (c) => c.lensDirection != current.lensDirection,
      orElse: () => cameras.firstWhere((c) => c != current, orElse: () => current),
    );

    await _cameraController?.dispose();
    
    _cameraController = CameraController(
      next, 
      ResolutionPreset.medium, 
      enableAudio: true,
      imageFormatGroup: kIsWeb ? null : (Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888),
    );
    
    try {
      await _cameraController!.initialize();
      if (wasDetecting && mounted) {
        if (kIsWeb) {
          WebSync.startPose(_handleLandmarks);
        } else {
          await _cameraController!.startImageStream(_processImage);
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Flip Error: $e');
      if (mounted) setState(() => _initError = "Camera Flip Error: $e");
    }
  }

  Future<void> _toggleRecording() async {
    if (AuthUtils.requireLogin(context: context, ref: ref) || _cameraController == null) return;
    if (_isRecording) {
      setState(() => _isRecording = false);
      _recordingTimer?.cancel();
      try {
        final video = await _cameraController!.stopVideoRecording();
        
        // Save to Gallery
        await Gal.putVideo(video.path);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video saved to Gallery!', style: GoogleFonts.outfit()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        setState(() => _isSyncing = true);
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final fileName = 'workout_${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
          await Supabase.instance.client.storage.from('workout_videos').upload(fileName, File(video.path));
          final videoUrl = Supabase.instance.client.storage.from('workout_videos').getPublicUrl(fileName);
          await Supabase.instance.client.from('workout_sessions').insert({
            'user_id': userId, 'exercise_name': widget.exercise, 'video_url': videoUrl, 'video_path': fileName,
            'reps_count': _counter, 'accuracy_score': _accuracy, 'duration_seconds': _recordingSeconds,
          });
        }
        await StorageService.addWorkoutHistory({
          'exercise': widget.exercise, 'reps': _counter, 'duration': _formatTime(_recordingSeconds),
          'date': DateTime.now().toIso8601String(), 'video_path': video.path,
        });
        _updateFeedback("Workout Cloud-Synced!", announce: true);
      } catch (e) { 
        debugPrint('Sync Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving video: $e'), backgroundColor: Colors.red),
          );
        }
      }
      finally { setState(() { _isSyncing = false; _recordingSeconds = 0; }); }
    } else {
      try {
        await _cameraController!.prepareForVideoRecording();
        await _cameraController!.startVideoRecording();
        setState(() { _isRecording = true; _recordingSeconds = 0; });
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) { if(mounted) setState(() => _recordingSeconds++); });
      } catch (e) { debugPrint('Rec Start Error: $e'); }
    }
  }

  void _finishWorkout() async {
    if (AuthUtils.requireLogin(context: context, ref: ref)) return;
    if (_isRecording) await _toggleRecording();
    if (_isDetecting) _togglePoseDetection();
    VoiceService.stopListening();
    
    await StorageService.addWorkoutHistory({
      'exercise': widget.exercise,
      'reps': _counter,
      'duration': _formatTime(_activeSeconds),
      'date': DateTime.now().toIso8601String(),
    });

    final met = _getMET();
    final calories = (met * 0.01225 * _activeSeconds + _counter * 0.4).round();
    
    ref.read(notificationsProvider.notifier).addNotification(
      title: 'Workout Complete!',
      description: 'You crushed ${widget.exercise} with $_counter reps.',
      icon: Icons.fitness_center_rounded,
      color: Colors.orange,
    );
    if (mounted) {
      context.pushReplacement('/workout-summary', extra: {
        'exercise': widget.exercise, 'reps': _counter.toString(), 'duration': _formatTime(_activeSeconds),
        'accuracy': _accuracy.toStringAsFixed(1), 'calories': calories.toString(),
      });
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double _getMET() {
    final name = widget.exercise.toLowerCase();
    if (name.contains('push-up') || name.contains('chest')) return 8.0;
    if (name.contains('squat') || name.contains('leg')) return 5.0;
    if (name.contains('jack')) return 8.0;
    if (name.contains('plank')) return 3.0;
    return 4.5;
  }
}

class _PosePainter extends CustomPainter {
  final List<dynamic> landmarks;
  final bool isCorrect;
  final List<int> incorrectIndices;
  final double latestAngle;
  final bool isMirrored;

  _PosePainter(this.landmarks, this.isCorrect, this.incorrectIndices, this.latestAngle, this.isMirrored);

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final List<Offset> points = landmarks.map((l) {
      double x = (l['x'] as num?)?.toDouble() ?? 0.0;
      double y = (l['y'] as num?)?.toDouble() ?? 0.0;
      
      // MIRRORING FIX: If in selfie mode, mirrors the X coordinate so right is right and left is left
      double finalX = isMirrored ? (1.0 - x) : x;
      return Offset(finalX * size.width, y * size.height);
    }).toList();

    void drawSimpleLine(int start, int end) {
      if (start >= points.length || end >= points.length) return;
      
      final l1 = landmarks[start];
      final l2 = landmarks[end];
      
      final isIncorrect = incorrectIndices.contains(start) || incorrectIndices.contains(end);
      final Color baseColor = isIncorrect ? Colors.redAccent : Colors.lightBlueAccent;
      
      final linePaint = Paint()
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..color = baseColor;

      canvas.drawLine(points[start], points[end], linePaint);
    }

    // Main Skeleton Connections - Standard 33 landmarks
    if (points.length >= 33) {
      // Upper body
      drawSimpleLine(11, 12); // Shoulders
      drawSimpleLine(11, 23); // Left shoulder to hip
      drawSimpleLine(12, 24); // Right shoulder to hip
      drawSimpleLine(11, 13); // Left shoulder to elbow
      drawSimpleLine(13, 15); // Left elbow to wrist
      drawSimpleLine(12, 14); // Right shoulder to elbow
      drawSimpleLine(14, 16); // Right elbow to wrist
      
      // Lower body
      drawSimpleLine(23, 24); // Hips
      drawSimpleLine(23, 25); // Left hip to knee
      drawSimpleLine(25, 27); // Left knee to ankle
      drawSimpleLine(24, 26); // Right hip to knee
      drawSimpleLine(26, 28); // Right knee to ankle
      
      // Hands
      drawSimpleLine(15, 17); drawSimpleLine(15, 19); drawSimpleLine(15, 21);
      drawSimpleLine(16, 18); drawSimpleLine(16, 20); drawSimpleLine(16, 22);

      // Feet & Toes
      drawSimpleLine(27, 29); drawSimpleLine(27, 31); drawSimpleLine(29, 31);
      drawSimpleLine(28, 30); drawSimpleLine(28, 32); drawSimpleLine(30, 32);
    }
    
    // Draw Joints
    final List<int> jointIndices = [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28, 31, 32];
    for (int i in jointIndices) {
      if (i >= points.length) continue;
      
      final isIncorrect = incorrectIndices.contains(i);
      Color dotColor = isIncorrect ? Colors.redAccent : Colors.yellowAccent;
      
      canvas.drawCircle(
        points[i], 
        8.0, 
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill
      );
    }

    // Draw Labels and Angles
    void drawText(String text, Offset pos, Color color, [double fontSize = 24.0]) {
      final textSpan = TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(pos.dx + 15, pos.dy - 10));
    }

    if (points.length >= 33) {
      // Determine dominant side (usually closer to camera / higher visibility)
      int shoulder = landmarks[12]['likelihood'] > landmarks[11]['likelihood'] ? 12 : 11;
      int hip = landmarks[24]['likelihood'] > landmarks[23]['likelihood'] ? 24 : 23;
      int knee = landmarks[26]['likelihood'] > landmarks[25]['likelihood'] ? 26 : 25;
      int ankle = landmarks[28]['likelihood'] > landmarks[27]['likelihood'] ? 28 : 27;

      drawText("Shoulder", points[shoulder], Colors.white, 20.0);
      drawText("Hip", points[hip], Colors.white, 20.0);
      drawText("Knee", points[knee], Colors.white, 20.0);
      drawText("Ankle", points[ankle], Colors.white, 20.0);
      
      // Draw dynamic angle near knee
      if (latestAngle > 0) {
        drawText(latestAngle.toInt().toString(), Offset(points[knee].dx + 25, points[knee].dy + 15), Colors.purpleAccent, 30.0);
      }
    }
  }

  @override
  bool shouldRepaint(_PosePainter oldDelegate) => true;
}
