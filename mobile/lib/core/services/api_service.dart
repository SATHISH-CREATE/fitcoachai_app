import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../network/api_constants.dart';
import 'storage_service.dart';

class ApiService {
  static Future<Map<String, dynamic>> chat(
      String message, Map<String, dynamic> userProfile, List history) async {
    try {
      final url = await getBaseUrl();
      final res = await http.post(
        Uri.parse('$url${ApiConstants.chat}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'context': {'user_profile': userProfile, 'history': history}
        }),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      // Return fallback
    }
    return {
      'response': 'Hey! I\'m your FIT COACH AI. Ask me anything about workouts, nutrition, or form!',
      'model_type': 'fallback'
    };
  }

  static Future<Map<String, dynamic>> generateDiet(
      Map<String, dynamic> userProfile, int calories, Map<String, dynamic> macros,
      {String dietType = 'non-veg', bool includeWhey = false, double? targetWeight}) async {
    try {
      final url = await getBaseUrl();
      final res = await http.post(
        Uri.parse('$url${ApiConstants.generateDiet}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_profile': userProfile,
          'calorie_goal': calories,
          'macros': macros,
          'diet_type': dietType,
          'include_whey': includeWhey,
          'target_weight': targetWeight,
        }),
      ).timeout(const Duration(seconds: 60)); // Long timeout for AI generation
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      // ignore
    }
    return {};
  }

  static String? _resolvedBaseUrl;

  static void setBaseUrl(String? url) {
    _resolvedBaseUrl = url;
  }

  static Future<String> getBaseUrl() async {
    if (_resolvedBaseUrl != null) return _resolvedBaseUrl!;
    
    // List of URLs to probe in order of priority
    List<String> urlsToTry = [];
    
    // 1. User-defined custom override
    final customUrl = StorageService.getItem('backend_url');
    if (customUrl != null && customUrl.toString().isNotEmpty) {
      urlsToTry.add(customUrl.toString());
    }

    // 2. Localhost (Works for Web, Desktop, and physical Android via USB 'adb reverse')
    urlsToTry.add('http://127.0.0.1:8086');

    // 3. Current Machine IP from ApiConstants (Works for physical Android via Wi-Fi)
    urlsToTry.add(ApiConstants.baseUrl);

    // 4. Android Emulator Gateway
    if (defaultTargetPlatform == TargetPlatform.android) {
      urlsToTry.add(ApiConstants.emulatorIP);
    }

    // Try each URL until one responds
    for (String url in urlsToTry) {
      if (await _tryUrl(url)) {
        _resolvedBaseUrl = url;
        print('Backend connected at: $url');
        return url;
      }
    }

    // If all probes fail, return the primary built-in URL as a last resort
    return ApiConstants.baseUrl;
  }


  static Future<bool> _tryUrl(String url) async {
    try {
      final res = await http.get(Uri.parse('$url/health')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String _lastError = "No check performed yet";
  static String get lastError => _lastError;

  static Future<bool> checkHealth() async {
    try {
      _lastError = "Probing for working URL...";
      final url = await getBaseUrl();
      _lastError = "Trying $url/health...";
      final res = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        _lastError = "Connected to $url";
        return true;
      } else {
        _lastError = "HTTP ${res.statusCode} at $url";
        return false;
      }
    } catch (e) {
      _lastError = e.toString().contains("Timeout") ? "Connection Timeout" : "Error: $e";
      print('Health Check FAILED: $e');
      return false;
    }
  }


  static Future<Map<String, dynamic>> processLandmarks(
      String userId, List<Map<String, dynamic>> landmarks, String exercise) async {
    try {
      final url = await getBaseUrl();
      final res = await http.post(
        Uri.parse('$url${ApiConstants.processLandmarks}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'landmarks': landmarks,
          'exercise': exercise,
        }),
      ).timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      print('Landmarks network error: $e');
    }
    return {};
  }

  static Future<Map<String, dynamic>> processFrame(
      String userId, String imageBase64, String exercise) async {
    try {
      final url = await getBaseUrl();
      final res = await http.post(
        Uri.parse('$url/process_frame'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'image': imageBase64,
          'exercise': exercise,
        }),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      // ignore
    }
    return {};
  }

  static Future<List<Map<String, dynamic>>> getNearbyGyms(double lat, double lon, {String? query}) async {
    return await _getTomTomGyms(lat, lon, query);
  }

  static String _formatOSMAddress(Map<String, dynamic> tags) {
    List<String> parts = [];
    
    if (tags['addr:street'] != null) parts.add(tags['addr:street']);
    if (tags['addr:housenumber'] != null) parts.add(tags['addr:housenumber']);
    if (tags['addr:city'] != null) parts.add(tags['addr:city']);
    if (tags['area'] != null) parts.add(tags['area']);
    
    if (parts.isEmpty) {
      if (tags['location'] != null) return tags['location'];
      return 'Address not available';
    }
    
    return parts.join(', ');
  }

  static Future<List<Map<String, dynamic>>> _getTomTomGyms(double lat, double lon, String? query) async {
    try {
      final String key = ApiConstants.tomTomApiKey;
      List<Map<String, dynamic>> allResults = [];
      final seenIds = <String>{};

      // Ensure we ONLY do one strict category search. Doing keyword (poiSearch) 
      // fetches random non-category items like Auto Mechanics and triples loading time.
      await _fetchTomTomGyms(
        'https://api.tomtom.com/search/2/nearbySearch/.json?key=$key&lat=$lat&lon=$lon&radius=20000&limit=50&categorySet=7320002',
        allResults, seenIds,
      );

      return allResults;
    } catch (e) {
      print('TomTom fallback error: $e');
    }
    
    return [];
  }

  static Future<void> _fetchTomTomGyms(String url, List<Map<String, dynamic>> allResults, Set<String> seenIds) async {
    final List<String> gymPlaceholders = [
      'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400', // Modern gym
      'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400', // Weights
      'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400', // Treadmills
      'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=400', // Yoga/Open space
      'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400', // Ropes/Crossfit
    ];

    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        for (int i = 0; i < results.length; i++) {
          var item = results[i];
          final pos = item['position'] ?? {};
          final poi = item['poi'] ?? {};
          final addr = item['address'] ?? {};
          
          final id = item['id']?.toString() ?? '';
          if (seenIds.contains(id)) continue;
          
          final name = poi['name']?.toString() ?? '';
          
          // Extract TomTom category names for smarter filtering
          final categories = poi['categories'] as List? ?? [];
          final classifications = poi['classifications'] as List? ?? [];
          final categoryNames = <String>[];
          for (final c in classifications) {
            final code = c['code']?.toString().toLowerCase() ?? '';
            categoryNames.add(code);
            final names = c['names'] as List? ?? [];
            for (final n in names) {
              categoryNames.add((n['name'] ?? n['nameLocale'] ?? '').toString().toLowerCase());
            }
          }
          for (final c in categories) {
            categoryNames.add(c.toString().toLowerCase());
          }

          if (_isActualGym(name.toLowerCase(), categoryNames)) {
            seenIds.add(id);
            allResults.add({
              'id': id,
              'name': name.isNotEmpty ? name : 'Gym',
              'lat': (pos['lat'] as num?)?.toDouble() ?? 0.0,
              'lon': (pos['lon'] as num?)?.toDouble() ?? 0.0,
              'address': addr['freeformAddress'] ?? 'Address unavailable',
              'rating': poi['rating']?.toString() ?? '4.0',
              'reviews': 0,
              'image': gymPlaceholders[allResults.length % gymPlaceholders.length],
            });
          }
        }
      }
    } catch (e) {
      // Silently continue
    }
  }

  /// Strict gym detection — whitelist-only approach.
  /// A result MUST contain a gym/fitness keyword in its name to be accepted.
  /// A comprehensive blocklist rejects known non-gym categories first.
  static bool _isActualGym(String name, List<String> categoryNames) {
    // ── STEP 1: Hard blocklist — immediately reject obvious non-gyms ──
    final blockTerms = [
      // Educational / Government
      'school', 'college', 'university', 'vidyalaya', 'kendriya',
      'institute', 'shiksha', 'paathshala', 'polytechnic', 'iit', 'nit',
      'academia', 'academy',
      // Medical
      'hospital', 'clinic', 'pharmacy', 'medical', 'nursing', 'diagnostic',
      'pathology', 'dental', 'ayurvedic', 'homeopathy',
      // Religious / Spiritual / Yoga / Mission
      'temple', 'mosque', 'church', 'gurudwara', 'mandir', 'masjid',
      'ashram', 'asramam', 'ashramam', 'asahramam', 'mission',
      'math ', 'dargah', 'chapel', 'meditation', 'yoga',
      'spiritual', 'vedic', 'veda', 'dharma',
      // Commercial / Food
      'restaurant', 'hotel', 'bakery', 'cafe', 'bar ', 'dhaba', 'biryani',
      'pizza', 'chicken', 'sweets', 'mess ', 'canteen', 'tiffin',
      // Beauty / Leisure / Non-gym wellness
      'salon', 'beauty', 'parlour', 'parlor', 'spa ', 'spa-',
      'massage', 'nail ', 'hair ',
      // Sports venues that are NOT gyms
      'ground', 'playground', 'stadium', 'arena', 'cricket', 'football',
      'tennis', 'badminton', 'court', 'swimming pool', 'pool ',
      'golf', 'bowling', 'billiard', 'snooker', 'sports complex',
      // Dance / Martial arts / Non-gym activities
      'dance', 'karate', 'judo', 'taekwondo', 'martial art',
      'kung fu', 'aikido', 'kendo', 'wushu',
      // Clubs / Recreation (generic)
      'recreation', 'club house', 'community hall', 'welfare',
      'association', 'sangam', 'samaj', 'sabha', 'sangha', 'mandal',
      'sena ', 'dal ',
      // Indian village/place name suffixes & infrastructure
      'palli', 'palle', 'puram', 'peta', 'guda', 'gudem', 'palem',
      'cheruvu', 'kunta', 'vari', 'wadi', 'ganj', 'pur',
      'street', 'road', 'lane', 'nagar', 'colony', 'layout',
      'apartment', 'flat', 'tower', 'residency', 'enclave',
      'plot ', 'survey', 'block ',
      // Auto / Industrial
      'mechanic', 'auto', 'garage', 'workshop', 'brick', 'factory',
      'warehouse', 'godown', 'mill ', 'forge',
      // Misc non-gym
      'office', 'bank', 'atm', 'post office', 'police', 'fire station',
      'petrol', 'gas station', 'fuel', 'park', 'garden',
      'library', 'museum', 'theatre', 'theater', 'cinema',
      'shop', 'store', 'market', 'mall', 'supermarket', 'kirana',
      'tailor', 'laundry', 'dry clean',
      'kandram', 'kendram', 'kendra',
      'rama', 'chandra', 'krishna', 'hanuman', 'lakshmi', 'devi',
      'foundation', 'trust', 'society', 'charity',
    ];

    if (blockTerms.any((t) => name.contains(t))) return false;

    // ── STEP 2: Whitelist — name MUST contain a gym/fitness keyword ──
    // This is the strictest possible filter: if the name doesn't explicitly
    // say gym/fitness, we reject it regardless of TomTom category.
    final gymKeywords = [
      'gym', 'fitness', 'workout', 'crossfit', 'cross fit',
      'bodybuilding', 'body building', 'powerlifting', 'power lifting',
      'weight training', 'strength', 'muscle',
      'health club', 'fit zone', 'fitzone', 'fitlife', 'fit life',
      'iron', 'flex', 'pump', 'beast', 'hulk', 'titan',
      'physique', 'shred', 'ripped', 'gains',
      'akhada', 'akhara', 'vyayamshala', 'vyayam',
      'dumbbell', 'barbell', 'kettlebell',
      'fitpro', 'fitmax', 'fitclub', 'powerhouse',
      'body fuel', 'six pack', 'transformation',
    ];

    if (gymKeywords.any((kw) => name.contains(kw))) return true;

    // If name has no gym keyword, reject — no category fallback.
    // TomTom category 7320002 is "Sports Center" which is too broad.
    return false;
  }

  static Future<Map<String, dynamic>?> getDirections(double startLat, double startLon, double endLat, double endLon) async {
    try {
      final String key = ApiConstants.tomTomApiKey;
      final url = 'https://api.tomtom.com/routing/1/calculateRoute/$startLat,$startLon:$endLat,$endLon/json?key=$key&routeType=fastest&traffic=true';
      
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final points = route['legs'][0]['points'] as List;
          final summary = route['summary'];
          
          return {
            'points': points.map((p) => {'lat': p['latitude'], 'lon': p['longitude']}).toList(),
            'distance': (summary['lengthInMeters'] as num).toDouble() / 1000.0,
            'duration': (summary['travelTimeInSeconds'] as num).toDouble() / 60.0,
          };
        }
      }
    } catch (e) {
      print('Route error: $e');
    }
    return null;
  }

  static Future<Map<String, double>?> geocodeLocation(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final key = ApiConstants.tomTomApiKey;
      
      final url = 'https://api.tomtom.com/search/2/geocode/$encoded.json?key=$key&limit=1&countrySet=IN';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final pos = results[0]['position'];
          return {
            'lat': (pos['lat'] as num).toDouble(),
            'lon': (pos['lon'] as num).toDouble(),
          };
        }
      }
    } catch (e) {
      print('Location search error: $e');
    }
    return null;
  }

  static Future<void> resetSession({String? userId}) async {
    try {
      final url = await getBaseUrl();
      await http.post(
        Uri.parse('$url/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId ?? 'default'}),
      );
    } catch (e) {
      // ignore
    }
  }
}
