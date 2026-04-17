import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'storage_service.dart';
import '../utils/web_utils.dart';
import 'package:flutter/foundation.dart';

class VoiceService {
  static final FlutterTts _tts = FlutterTts();
  static final SpeechToText _stt = SpeechToText();
  static bool _isTtsInitialized = false;
  static bool _isSttInitialized = false;

  static Future<void> init() async {
    if (_isTtsInitialized) return;
    try {
      if (!kIsWeb) {
        await _tts.setLanguage("en-US");
        await _tts.setPitch(1.0);
        await _tts.setSpeechRate(0.5);
      }
      _isTtsInitialized = true;
    } catch (e) {
      debugPrint("Voice Init Error: $e");
    }
  }

  static Future<void> speak(String text) async {
    if (!StorageService.isVoiceAssistantEnabled()) return;
    
    if (kIsWeb) {
      WebSync.speak(text);
    } else {
      if (!_isTtsInitialized) await init();
      await _tts.speak(text);
    }
  }

  static Future<void> motivate(int count) async {
    if (count > 10 && count % 3 == 0) {
      final intenseMotivations = [
        "Unstoppable! Keep pushing!",
        "You're a beast! Don't stop now!",
        "Breaking limits! Focus on the form!",
        "Amazing endurance! You've got this!",
        "Sensational! Push for five more!",
      ];
      final msg = intenseMotivations[(count ~/ 3) % intenseMotivations.length];
      await speak(msg);
    } else if (count % 5 == 0 && count > 0) {
      final motivations = [
        "Great job! Keep going!",
        "You are doing amazing!",
        "Stay strong!",
        "Push yourself!",
        "Excellent form!",
      ];
      final msg = motivations[(count ~/ 5) % motivations.length];
      await speak(msg);
    }
  }

  static Future<void> announceRep(int count) async {
    await speak("$count");
  }

  static bool _shouldListen = false;
  static bool _isListening = false;

  static Future<void> startListening(Function(String) onResult) async {
    if (kIsWeb) return; 
    _shouldListen = true;
    
    try {
      if (!_isSttInitialized) {
        bool available = await _stt.initialize(
          onError: (error) {
            debugPrint('STT Error: $error');
            _isListening = false;
            if (_shouldListen) _restartListening(onResult);
          },
          onStatus: (status) {
            debugPrint('STT Status: $status');
            if (status == 'notListening' || status == 'done') {
              _isListening = false;
              if (_shouldListen) _restartListening(onResult);
            } else if (status == 'listening') {
              _isListening = true;
            }
          },
        );
        if (!available) {
          debugPrint('STT not available');
          return;
        }
        _isSttInitialized = true;
      }
      
      _listen(onResult);
    } catch (e) {
      debugPrint('STT Init Error: $e');
    }
  }

  static void _listen(Function(String) onResult) {
    if (!_shouldListen || _isListening) return;
    
    // Commands should still work even if Voice Assistant feedback is OFF
    // unless the user specifically wants everything OFF. 
    // Usually "Voice Assistant" setting in apps controls BOTH.
    if (!StorageService.isVoiceAssistantEnabled()) return;

    _stt.listen(
      onResult: (result) {
        final words = result.recognizedWords.toLowerCase();
        if (words.isNotEmpty) {
          onResult(words);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 10),
      cancelOnError: false,
      partialResults: true,
      listenMode: ListenMode.deviceDefault,
    );
  }

  static void _restartListening(Function(String) onResult) {
    if (!_shouldListen) return;
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_shouldListen) _listen(onResult);
    });
  }

  static void stopListening() {
    _shouldListen = false;
    _isListening = false;
    if (!kIsWeb) {
      _stt.stop();
    }
  }
}
