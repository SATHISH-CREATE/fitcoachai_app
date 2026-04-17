import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://192.168.31.146:8086'; 
    }
    
    // Android Handling
    if (defaultTargetPlatform == TargetPlatform.android) {
       // If you are using a physical device, this MUST be your computer's IP
       // If you are using an emulator, it should be '10.0.2.2'
       // Current user's PC IP is: 192.168.31.146
       return 'http://192.168.31.146:8086'; 
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // For iOS simulator use 127.0.0.1, for physical iOS use machine IP
      return 'http://192.168.31.146:8086';
    }

    return 'http://192.168.31.146:8086';
  }

  // Common Backend IPs for debugging
  static const String emulatorIP = 'http://192.168.31.146:8086';
  static const String machineIP = 'http://192.168.31.146:8086';
  static const String localIP = 'http://192.168.31.146:8086';


  static const String chat = '/chat';
  static const String generateDiet = '/generate_diet';
  static const String processLandmarks = '/process_landmarks';
  static const String reset = '/reset';
  
  // External APIs
  static const String tomTomApiKey = 'm9lOlbApSsjn50K7e68ZtsuZ1PQQroX3';
}
