import 'package:flutter/foundation.dart';

class ApiConstants {
  // Production URL for Render Free Tier
  static const String liveBackendUrl = 'https://fitcoachai-app.onrender.com';

  static String get baseUrl {
    // We now use the Render live link for all platforms to ensure cloud functionality
    return liveBackendUrl;
  }

  // Debugging IPs (Pre-configured for local testing if needed)
  static const String machineIP = 'http://192.168.31.146:8086';
  static const String emulatorIP = 'http://10.0.2.2:8086';

  // API Endpoints
  static const String chat = '/chat';
  static const String generateDiet = '/generate_diet';
  static const String processLandmarks = '/process_landmarks';
  static const String reset = '/reset';
  
  // External APIs
  static const String tomTomApiKey = 'm9lOlbApSsjn50K7e68ZtsuZ1PQQroX3';
}
