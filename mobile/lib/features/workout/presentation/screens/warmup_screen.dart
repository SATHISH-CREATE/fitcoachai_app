import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:ui';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_background.dart';

class WarmUpScreen extends StatefulWidget {
  final String exercise;
  const WarmUpScreen({super.key, required this.exercise});

  @override
  State<WarmUpScreen> createState() => _WarmUpScreenState();
}

class _WarmUpScreenState extends State<WarmUpScreen> {
  int _secondsLeft = 300; // 5 minutes
  Timer? _timer;
  bool _isRunning = false;

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      _isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_secondsLeft > 0) {
            _secondsLeft--;
          } else {
            _timer?.cancel();
            _isRunning = false;
            _proceedToWorkout();
          }
        });
      });
      setState(() {});
    }
  }

  void _proceedToWorkout() {
    _timer?.cancel();
    context.pushReplacement('/workout?exercise=${Uri.encodeComponent(widget.exercise)}');
  }

  Widget _buildWarmupRow(String name, String duration, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(name, 
              style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Text(duration, 
            style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_secondsLeft / 60).floor();
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () {
            _timer?.cancel();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Text('PRE-WORKOUT', 
                  style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 13, letterSpacing: 3, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('WARM UP', 
                  style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Prepare for ${widget.exercise}', 
                  style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 48),
                
                // Timer Section
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: _secondsLeft / 300,
                        strokeWidth: 16,
                        backgroundColor: AppColors.bgSoft,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formattedTime, 
                          style: GoogleFonts.outfit(
                            color: AppColors.textPrimary, 
                            fontSize: 72, 
                            fontWeight: FontWeight.w900, 
                            fontFeatures: [const FontFeature.tabularFigures()]
                          )),
                        Text('MINUTES', 
                          style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 48),
                
                // Movement List
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.cardBorder, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RECOMMENDED MOVEMENTS', 
                        style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 20),
                      _buildWarmupRow('1. Jumping Jacks', '60s', 0),
                      _buildWarmupRow('2. Arm & Hip Circles', '60s', 1),
                      _buildWarmupRow('3. Bodyweight Squats', '60s', 2),
                      _buildWarmupRow('4. High Knees / Jog', '60s', 3),
                      _buildWarmupRow('5. Dynamic Stretching', '60s', 4),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Controls
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.redAccent : Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                      shadowColor: (_isRunning ? Colors.redAccent : Colors.teal).withOpacity(0.4),
                    ),
                    onPressed: _toggleTimer,
                    child: Text(_isRunning ? 'STOP TIMER' : 'START WARMUP', 
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _proceedToWorkout,
                  child: Text('SKIP TO WORKOUT', 
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
