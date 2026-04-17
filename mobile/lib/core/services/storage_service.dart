import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static T safeParse<T>(String key, T fallback) {
    try {
      final val = _prefs?.getString(key);
      if (val == null || val == 'null' || val.isEmpty) return fallback;
      return jsonDecode(val) as T;
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> setItem(String key, dynamic value) async {
    await _prefs?.setString(key, jsonEncode(value));
  }

  static dynamic getItem(String key) {
    final val = _prefs?.getString(key);
    if (val == null) return null;
    try {
      return jsonDecode(val);
    } catch (_) {
      return val;
    }
  }

  static Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  // Typed helpers
  static Map<String, dynamic> getProfile() =>
      safeParse<Map<String, dynamic>>('user_profile', {});

  static Future<void> saveProfile(Map<String, dynamic> profile) =>
      setItem('user_profile', profile);

  static bool hasProfile() {
    final profile = getProfile();
    return profile.isNotEmpty && profile['name'] != null;
  }

  static List<dynamic> getWorkoutHistory() =>
      safeParse<List<dynamic>>('workout_history', []);

  static Future<void> saveWorkoutHistory(List<dynamic> history) =>
      setItem('workout_history', history);

  static Future<void> addWorkoutHistory(Map<String, dynamic> record) async {
    final history = getWorkoutHistory();
    history.insert(0, record);
    // Keep last 100 sessions
    if (history.length > 100) history.removeLast();
    await saveWorkoutHistory(history);
  }

  static Map<String, dynamic> getMacroPlan() =>
      safeParse<Map<String, dynamic>>('user_macro_plan', {});

  static Future<void> saveMacroPlan(Map<String, dynamic> plan) =>
      setItem('user_macro_plan', plan);

  static String? getMealPlanResponse() =>
      _prefs?.getString('meal_plan_response');

  static Future<void> saveMealPlanResponse(String plan) async =>
      await _prefs?.setString('meal_plan_response', plan);

  static List<Map<String, dynamic>> get6DayPlan() {
    try {
      final val = _prefs?.getString('my_6day_plan');
      if (val == null || val == 'null' || val.isEmpty) return [];
      final decoded = jsonDecode(val);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> save6DayPlan(List<dynamic> plan) =>
      setItem('my_6day_plan', plan);

  static int getWater(String dateKey) =>
      safeParse<int>('water_$dateKey', 0);

  static Future<void> saveWater(String dateKey, int ml) =>
      setItem('water_$dateKey', ml);

  static int getRepsPerSet() =>
      safeParse<int>('reps_per_set', 10); // Default to 10

  static Future<void> saveRepsPerSet(int reps) =>
      setItem('reps_per_set', reps);

  static bool isVoiceAssistantEnabled() =>
      safeParse<bool>('voice_assistant_enabled', true);

  static Future<void> setVoiceAssistantEnabled(bool enabled) =>
      setItem('voice_assistant_enabled', enabled);

  static Future<void> clear() async {
    await _prefs?.clear();
  }
}
