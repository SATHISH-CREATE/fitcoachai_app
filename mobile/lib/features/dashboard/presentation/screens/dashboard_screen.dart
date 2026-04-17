import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/widgets/app_background.dart';
import '../../../../shared/utils/auth_utils.dart';
import '../../../../shared/utils/image_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/network/api_constants.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';
import '../../../../shared/providers/notifications_provider.dart';
import '../../../../shared/models/notification_model.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Removed _hasUnread local state as we'll use the provider

  void _showNotificationsDialog() {
    final notifications = ref.read(notificationsProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            if (notifications.isNotEmpty)
              TextButton(
                onPressed: () {
                  ref.read(notificationsProvider.notifier).clearAll();
                  Navigator.pop(context);
                },
                child: Text('CLEAR ALL', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
              ),
          ],
        ),
        content: notifications.isEmpty 
          ? SizedBox(
              height: 100,
              child: Center(
                child: Text('No new notifications', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            )
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: notifications.length,
                itemBuilder: (ctx, idx) {
                  final n = notifications[idx];
                  return _notiItem(n.title, n.description, n.icon, n.color);
                },
              ),
            ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), 
            child: Text('CLOSE', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.primary))),
        ],
      ),
    );
  }

  Widget _notiItem(String title, String desc, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(desc, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _macroPlan = {};
  List<dynamic> _plan = [];
  int _waterMl = 0;
  int _waterGoal = 3500;
  String _dateKey = '';
  int _streak = 0;
  String? _mealPlanText;

  StreamSubscription<StepCount>? _stepCountSubscription;
  int _steps = 0;
  int _baseSteps = -1;
  bool _isPedometerActive = false;
  int _stepGoal = 10000;
  List<double> _weeklyStats = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1];
  
  String _intensity = "Moderate";
  String _consistency = "0%";
  String _recovery = "Good";
  
  Set<String> _checkedMeals = {};
  int _eatenCals = 0;
  Timer? _healthTimer;
  late ConfettiController _confettiController;
  bool _lastComplete = false;


  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _load();
    _requestInitialPermissions();
  }

  Future<void> _requestInitialPermissions() async {
    // Request Camera and Microphone permissions once at Home
    // This avoids interrupting the workout flow later
    final status = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    
    if (status[Permission.camera] == PermissionStatus.granted) {
      debugPrint("PERMISSIONS: Camera granted");
    }
    if (status[Permission.microphone] == PermissionStatus.granted) {
      debugPrint("PERMISSIONS: Microphone granted");
    }
  }


  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _confettiController.dispose();
    super.dispose();
  }



  void _startPedometer() async {
    if (_isPedometerActive) return;
    if (await Permission.activityRecognition.request().isGranted) {
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          if (mounted) {
            setState(() { 
              if (_baseSteps == -1) {
                final storedBase = StorageService.getItem('base_steps_$_dateKey');
                if (storedBase != null) {
                  _baseSteps = (storedBase as num).toInt();
                } else {
                  _baseSteps = event.steps;
                  StorageService.setItem('base_steps_$_dateKey', _baseSteps);
                }
              }
              final newSteps = (event.steps - _baseSteps).clamp(0, 999999); 
              int diff = newSteps - _steps;
              if (diff > 0) {
                 int currentHour = DateTime.now().hour;
                 Map<String, dynamic> hourly = StorageService.getItem('steps_hourly_$_dateKey') ?? {};
                 hourly[currentHour.toString()] = ((hourly[currentHour.toString()] as num?)?.toInt() ?? 0) + diff;
                 StorageService.setItem('steps_hourly_$_dateKey', hourly);
              }
              _steps = newSteps;
              StorageService.setItem('current_steps_$_dateKey', _steps);
              _isPedometerActive = true; 

              // Trigger Steps Notification (Once per day)
              if (_steps >= _stepGoal) {
                final lastNoti = StorageService.getItem('steps_noti_$_dateKey');
                if (lastNoti == null) {
                  ref.read(notificationsProvider.notifier).addNotification(
                    title: 'Step Goal Met!',
                    description: 'You crushed your $_stepGoal steps goal today!',
                    icon: Icons.directions_walk_rounded,
                    color: Colors.blue,
                  );
                  StorageService.setItem('steps_noti_$_dateKey', true);
                }
              }
            });
          }
        },
        onError: (error) {
          if (mounted) setState(() { _isPedometerActive = false; });
        },
      );
      if (mounted) setState(() => _isPedometerActive = true);
    }
  }

  void _load() {
    final now = DateTime.now();
    _dateKey = DateFormat('yyyy-MM-dd').format(now);
    
    final history = StorageService.getWorkoutHistory();
    List<double> performance = List.filled(7, 0.05);
    final nowTime = DateTime(now.year, now.month, now.day);
    for (int i = 0; i < 7; i++) {
        final day = DateTime(nowTime.year, nowTime.month, nowTime.day - (6 - i));
        final dayStr = DateFormat('yyyy-MM-dd').format(day);
        
        // Count workouts on that specific day
        final count = history.where((h) {
          final hDate = h['date'].toString();
          return hDate.contains(dayStr);
        }).length;
        
        performance[i] = (count > 0 ? 0.3 + (count * 0.15) : 0.05).clamp(0.05, 0.9);
    }

    final mealPlan = StorageService.getMealPlanResponse();
    final savedChecked = StorageService.getItem('checked_meals_$_dateKey') as List<dynamic>?;

    setState(() {
      _profile = StorageService.getProfile();
      _macroPlan = StorageService.getMacroPlan();
      _plan = StorageService.get6DayPlan();
      _waterMl = StorageService.getWater(_dateKey);
      _weeklyStats = performance;
      _mealPlanText = mealPlan;
      _checkedMeals = savedChecked?.map((e) => e.toString()).toSet() ?? {};
      
      final savedWaterGoal = StorageService.getItem('water_goal');
      _waterGoal = savedWaterGoal != null ? (savedWaterGoal as num).round() : 3500;
      
      final savedStepGoal = StorageService.getItem('step_goal');
      _stepGoal = savedStepGoal != null ? (savedStepGoal as num).round() : 10000;
      
      final savedCurrentSteps = StorageService.getItem('current_steps_$_dateKey');
      if (savedCurrentSteps != null) _steps = (savedCurrentSteps as num).toInt();
      
      _streak = _calcStreak();
      _calcEaten();
      _calculatePerformanceMetrics(history);
    });

    // Auto-start tracking if possible
    _startPedometer();
  }

  void _calcEaten() {
    final meals = _parseMeals();
    int total = 0;
    for (var m in meals) {
      if (_checkedMeals.contains(m['title'])) {
        total += (m['cals'] as int);
      }
    }
    setState(() => _eatenCals = total);
  }

  List<Map<String, dynamic>> _parseMeals() {
    if (_mealPlanText == null || _mealPlanText!.isEmpty) return _generateDefaultMeals();
    
    // 1. Determine the current day section (1-7)
    // DateTime.now().weekday: 1=Monday, 7=Sunday. This aligns with Day 1...Day 7 logic.
    final int todayIndex = DateTime.now().weekday;
    final String currentDayHeader = '--- DAY $todayIndex ---';
    final String nextDayHeader = '--- DAY ${todayIndex + 1} ---';

    String relevantText = _mealPlanText!;
    
    // If the text contains Day headers, try to isolate today's block
    if (_mealPlanText!.contains('--- DAY')) {
        int start = _mealPlanText!.indexOf(currentDayHeader);
        if (start != -1) {
            int end = _mealPlanText!.indexOf(nextDayHeader, start);
            if (end != -1) {
                relevantText = _mealPlanText!.substring(start, end);
            } else {
                relevantText = _mealPlanText!.substring(start);
            }
        }
    }

    final lines = relevantText.split('\n');
    List<Map<String, dynamic>> meals = [];
    
    final mealKeywords = ['meal', 'breakfast', 'lunch', 'dinner', 'snack', 'pre-workout', 'post-workout'];
    final List<String> excludeKeywords = ['target', 'goal', 'hydration', 'drink', 'water', '---', 'fitcoach', 'plan:'];
    final Set<String> seenTitles = {};
    
    final int totalGoalCals = (_macroPlan['calories'] ?? 2000) as int;
    final int fallbackCals = (totalGoalCals / 4).round();

    for (var line in lines) {
      final l = line.trim();
      if (l.isEmpty || l.length < 3) continue;
      
      final lowerLine = l.toLowerCase();
      
      // Strict exclusion check
      bool shouldExclude = false;
      for (final kw in excludeKeywords) {
          if (lowerLine.contains(kw)) {
              shouldExclude = true;
              break;
          }
      }
      if (shouldExclude) continue;

      bool isMealLine = mealKeywords.any((k) => lowerLine.startsWith(k)) || 
                        (l.contains(':') && l.split(':')[0].length < 25);


      if (isMealLine) {
        final parts = l.split(':');
        String title = parts[0].replaceAll(RegExp(r'[\*#_]'), '').trim();
        
        // Basic cleanup of common labels
        if (title.contains('---')) continue;
        
        // Prevent duplicates in the same day (just in case)
        if (seenTitles.contains(title.toLowerCase())) continue;
        
        // Robust calorie extraction
        final calMatch = RegExp(r'(\d+)\s*(kcal|calories|cals)', caseSensitive: false).firstMatch(line);
        int cals = calMatch != null ? int.parse(calMatch.group(1)!) : 0;
        
        if (cals == 0) {
            // Find any number that looks like calories
            final fallbackMatch = RegExp(r'\b([2-9]\d{2}|1\d{3})\b').firstMatch(line);
            cals = fallbackMatch != null ? int.parse(fallbackMatch.group(1)!) : fallbackCals;
        }

        if (title.length > 2) {
           meals.add({'title': title, 'cals': cals});
           seenTitles.add(title.toLowerCase());
        }
      }
    }

    
    if (meals.isEmpty) return _generateDefaultMeals();

    // Final Pass: Ensure calories add up correctly to the goal
    int totalParsed = 0;
    for (var m in meals) totalParsed += (m['cals'] as int);
    
    // If we rely heavily on fallbacks, redistribute to match the exact 1631 or whatever goal
    if (totalParsed != totalGoalCals) {
        int perMeal = (totalGoalCals / meals.length).round();
        for (int i = 0; i < meals.length; i++) {
            // Only override if it looks like a default/missing value
            if (meals[i]['cals'] == fallbackCals || meals[i]['cals'] == 0) {
                meals[i]['cals'] = perMeal;
            }
        }
    }

    return meals.take(6).toList();
  }



  List<Map<String, dynamic>> _generateDefaultMeals() {
      final total = (_macroPlan['calories'] ?? 2000) as int;
      final perMeal = (total / 4).round();
      return [
          {'title': 'Breakfast', 'cals': perMeal},
          {'title': 'Lunch', 'cals': perMeal},
          {'title': 'Dinner', 'cals': perMeal},
          {'title': 'Daily Snacks', 'cals': perMeal},
      ];
  }

  void _toggleMeal(String title) {
    setState(() {
      if (_checkedMeals.contains(title)) _checkedMeals.remove(title);
      else _checkedMeals.add(title);
      StorageService.setItem('checked_meals_$_dateKey', _checkedMeals.toList());
      _calcEaten();
      
      // Check for 100% completion blast
      final total = (_macroPlan['calories'] ?? 2000) as int;
      if (total > 0 && _eatenCals >= total) {
          if (!_lastComplete) {
              _confettiController.play();
              _lastComplete = true;
          }
      } else {
          _lastComplete = false;
      }
    });
  }


  void _showAdjustDialog(String title, int currentVal, Function(int) onSave) {
    AuthUtils.requireLogin(
      context: context,
      ref: ref,
      onAuthenticated: () {
        final TextEditingController ctrl = TextEditingController(text: currentVal.toString());
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(title, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: Text('CANCEL', style: GoogleFonts.outfit(color: AppColors.textSecondary))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final val = int.tryParse(ctrl.text);
                  if (val != null && val > 0) {
                    onSave(val);
                  }
                  Navigator.pop(ctx);
                },
                child: Text('SAVE', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  int _calcStreak() {
    final history = StorageService.getWorkoutHistory();
    if (history.isEmpty) return 0;
    int streak = 0;
    DateTime now = DateTime.now();
    DateTime day = DateTime(now.year, now.month, now.day);
    final String todayStr = DateFormat('yyyy-MM-dd').format(now);
    final Set<String> trainedDays = {};
    for (final h in history) {
      try {
        final d = DateTime.parse(h['date']);
        trainedDays.add(DateFormat('yyyy-MM-dd').format(d));
      } catch (_) {}
    }
    while (true) {
      final k = DateFormat('yyyy-MM-dd').format(day);
      if (trainedDays.contains(k)) {
        streak++;
        day = DateTime(day.year, day.month, day.day - 1);
      } else {
        // If they haven't trained today yet, don't break the streak immediately if they trained yesterday
        if (streak == 0 && k == todayStr) {
           day = DateTime(day.year, day.month, day.day - 1);
           continue; 
        }
        break;
      }
    }
    return streak;
  }

  void _calculatePerformanceMetrics(List<dynamic> history) {
    if (history.isEmpty) {
      _intensity = "N/A";
      _consistency = "0%";
      _recovery = "Ready";
      return;
    }

    final now = DateTime.now();
    int workoutsInWeek = 0;
    int totalReps = 0;
    Set<String> activeDays = {};

    for (var h in history) {
      try {
        final date = DateTime.parse(h['date']);
        if (now.difference(date).inDays < 7) {
          workoutsInWeek++;
          totalReps += (h['reps'] as num).toInt();
          activeDays.add(DateFormat('yyyy-MM-dd').format(date));
        }
      } catch (_) {}
    }

    // Intensity: Based on reps per workout
    double avgReps = workoutsInWeek > 0 ? totalReps / workoutsInWeek : 0;
    if (avgReps > 50) _intensity = "Elite";
    else if (avgReps > 30) _intensity = "Hi-Load";
    else if (avgReps > 15) _intensity = "Moderate";
    else _intensity = "Low";

    // Consistency: Active days vs 7 days
    double consistencyVal = (activeDays.length / 7) * 100;
    _consistency = "${consistencyVal.toInt()}%";

    // Recovery: If training every single day without rest
    if (activeDays.length >= 6) _recovery = "Needs Rest";
    else if (activeDays.length >= 4) _recovery = "Optimal";
    else _recovery = "High";
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String get _todayFocus {
    if (_plan.isEmpty) return 'Rest & Recovery';
    final dayOfWeek = DateTime.now().weekday;
    final idx = (dayOfWeek - 1).clamp(0, _plan.length - 1);
    return _plan[idx]['title'] ?? 'Morning Drill';
  }

  String get _todayDesc {
      final focus = _todayFocus.toLowerCase();
      if (focus.contains('chest')) return 'Power and definition\nin every rep.';
      if (focus.contains('leg')) return 'Build explosive power\nand endurance.';
      if (focus.contains('core')) return 'Sculpt your midsection\nwith precision.';
      if (focus.contains('back')) return 'Strength and posture\nfor total control.';
      return 'Stay consistent and\nfinish strong.';
  }

  String get _todayImg {
      final focus = _todayFocus.toLowerCase();
      if (focus.contains('chest')) return 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?q=80&w=500';
      if (focus.contains('leg')) return 'https://images.unsplash.com/photo-1434608519344-49d77a699e1d?q=80&w=500';
      if (focus.contains('back')) return 'https://images.unsplash.com/photo-1599058917233-358352662af3?q=80&w=500';
      if (focus.contains('core')) return 'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?q=80&w=500';
      return 'https://images.unsplash.com/photo-1594381898411-846e7d193883?q=80&w=500';

  }

  List<String> get _todayExercises {
    if (_plan.isEmpty) return ['Stretching Session'];
    final dayOfWeek = DateTime.now().weekday;
    final idx = (dayOfWeek - 1).clamp(0, _plan.length - 1);
    final ex = _plan[idx]['exercises'];
    if (ex == null || (ex as List).isEmpty) return ['Core Activation'];
    return List<String>.from(ex);
  }

  void _addWater(int ml) {
    setState(() {
      _waterMl = (_waterMl + ml).clamp(0, _waterGoal * 2);
    });
    StorageService.saveWater(_dateKey, _waterMl);

    // Trigger Water Notification (Once per day)
    if (_waterMl >= _waterGoal) {
      final lastNoti = StorageService.getItem('water_noti_$_dateKey');
      if (lastNoti == null) {
        ref.read(notificationsProvider.notifier).addNotification(
          title: 'Hydration Goal!',
          description: 'You reached your daily water goal of $_waterGoal ml.',
          icon: Icons.local_drink_rounded,
          color: Colors.cyan,
        );
        StorageService.setItem('water_noti_$_dateKey', true);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile ?? _profile;
    
    final macroData = StorageService.getMacroPlan();
    final hasMacroPlan = macroData.containsKey('calories');
    final calories = hasMacroPlan ? (macroData['calories'] as num).round() : 2000;
    
    final name = profile['name'] ?? 'Guest';

    return Stack(
      children: [
        AppBackground(
          useBlobs: true,
          isInternal: true,
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 24, bottom: 20),
                    child: Row(
                      children: [
                        Text('FITCOACH AI', 
                          style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.2, end: 0),
                  _buildPremiumHeader(name, profile),
                  const SizedBox(height: 24),
                  _buildActivityCard(),
                  const SizedBox(height: 24),
                  _buildHeroWorkoutSection(),
                  const SizedBox(height: 24),
                  _buildQuickStatsSection(),
                  const SizedBox(height: 24),
                  _buildHealthSection(hasMacroPlan, calories),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ),
      ],
    );
  }




  Widget _buildPremiumHeader(String name, Map<String, dynamic> profile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              backgroundImage: ImageUtils.getAvatarImage(profile['avatar_url']),
              child: profile['avatar_url'] == null 
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'G', 
                  style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 24))
                : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(name, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                const SizedBox(height: 4),
                Text(DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(), 
                  style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(notificationsProvider.notifier).markAsRead();
              _showNotificationsDialog();
            },
            child: Consumer(
              builder: (context, ref, _) {
                final hasUnread = ref.watch(notificationsProvider).any((n) => !n.isRead);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 24),
                    ),
                    if (hasUnread)
                      Positioned(
                        top: 0, right: 0,
                        child: Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildHeroWorkoutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Daily Focus', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            TextButton(
              onPressed: () {
                if (AuthUtils.requireLogin(context: context, ref: ref)) return;
                context.go('/schedules');
              },
              child: Text('View Plan', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 15))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(_todayImg, fit: BoxFit.cover),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.9)],
                      stops: const [0, 0.4, 0.9],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('AI PERSONALIZED', 
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 12),
                    Text(_todayFocus, style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1)),
                    const SizedBox(height: 8),
                    Text(_todayDesc.replaceAll('\n', ' '), 
                      style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () {
                              if (AuthUtils.requireLogin(context: context, ref: ref)) return;
                              final exercises = _todayExercises;
                              final firstEx = exercises.isNotEmpty ? exercises.first : 'Push-Ups';
                              context.push('/warmup?exercise=${Uri.encodeComponent(firstEx)}');
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text('START SESSION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 54, height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
                            onPressed: _showScheduledExercises,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 600.ms).scale(begin: const Offset(0.95, 0.95)),
      ],
    );
  }

  Widget _buildQuickStatsSection() {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _buildGlassStatCard(
              'Hydration',
              '${(_waterMl / 1000).toStringAsFixed(1)}L',
              Icons.water_rounded,
              Colors.blue,

              'Goal: ${(_waterGoal / 1000).toStringAsFixed(1)}L',
              _showWaterDialog,
              onEdit: () => _showAdjustDialog('Water Goal (ml)', _waterGoal, (val) {
                StorageService.setItem('water_goal', val);
                setState(() => _waterGoal = val);
              }),
            ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildGlassStatCard(
              'Move Count',
              '$_steps',
              Icons.directions_walk_rounded,
              Colors.orange,
              'Goal: $_stepGoal',
              () => context.push('/steps'),
              onEdit: () => _showAdjustDialog('Step Goal', _stepGoal, (val) {
                StorageService.setItem('step_goal', val);
                setState(() => _stepGoal = val);
              }),
            ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1, end: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassStatCard(String title, String value, IconData icon, Color color, String footer, VoidCallback onTap, {VoidCallback? onEdit}) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        if (title.contains('Hydration')) {
          _showAdjustDialog('Current Water (ml)', _waterMl, (val) => _addWater(val - _waterMl));
        } else if (title.contains('Move')) {
             _showAdjustDialog('Current Steps', _steps, (val) {
               final diff = val - _steps;
               if (diff > 0) {
                 int currentHour = DateTime.now().hour;
                 Map<String, dynamic> hourly = StorageService.getItem('steps_hourly_$_dateKey') ?? {};
                 hourly[currentHour.toString()] = ((hourly[currentHour.toString()] as num?)?.toInt() ?? 0) + diff;
                 StorageService.setItem('steps_hourly_$_dateKey', hourly);
               }
               setState(() => _steps = val);
               StorageService.setItem('current_steps_$_dateKey', val);
             });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (title.contains('Move') && _isPedometerActive)
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                     child: Text('LIVE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                   ),
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    child: Icon(Icons.edit_rounded, color: color.withOpacity(0.5), size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(footer, style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            // Progress Bar for tracking clearly
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _calculateProgress(title),
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateProgress(String title) {
    if (title.contains('Hydration')) {
      if (_waterGoal <= 0) return 0.0;
      return (_waterMl / _waterGoal).clamp(0.0, 1.0);
    } else if (title.contains('Move')) {
      if (_stepGoal <= 0) return 0.0;
      return (_steps / _stepGoal).clamp(0.0, 1.0);
    }
    return 0.0;
  }



  void _showScheduledExercises() {
      final exercises = _todayExercises;
      _showAITemplateModal(
          title: 'FITCOACH AI',
          subtitle: 'Today\'s Scheduled Drills',
          contentBuilder: (ctx) => Column(
              children: exercises.map((ex) => _buildAIItemCard(ex, Icons.fitness_center_rounded)).toList(),
          ),
      );
  }


  void _showWaterDialog() {
      _showAITemplateModal(
          title: 'QUICK HYDRATION LOG',
          subtitle: '',
          contentBuilder: (ctx) => Column(

            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                      _waterOptionTemplate(ctx, '250ml', 250),
                      _waterOptionTemplate(ctx, '500ml', 500),
                      _waterOptionTemplate(ctx, '750ml', 750),
                  ],
              ),
              const SizedBox(height: 10),
              Text('Select a quick amount to log hydration', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),


            ],
          ),
      );
  }


  void _showAITemplateModal({required String title, required String subtitle, required Widget Function(BuildContext) contentBuilder}) {
      showDialog(
          context: context,
          builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30)],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              color: AppColors.primary,
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                      Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
                                      IconButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                      ),
                                  ],


                              ),
                          ),
                          Padding(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      if (subtitle.isNotEmpty) ...[
                                        Row(
                                            children: [
                                                Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                                                    child: const Icon(Icons.water_rounded, color: AppColors.primary, size: 20),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                    child: Container(
                                                        padding: const EdgeInsets.all(16),
                                                        decoration: BoxDecoration(
                                                            color: const Color(0xFFF7F8FA),
                                                            borderRadius: const BorderRadius.only(
                                                                topRight: Radius.circular(24),
                                                                bottomLeft: Radius.circular(24),
                                                                bottomRight: Radius.circular(24),
                                                            ),
                                                        ),
                                                        child: Text(subtitle, style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 15)),
                                                    ),
                                                ),
                                            ],
                                        ),
                                        const SizedBox(height: 32),
                                      ],
                                      SingleChildScrollView(child: contentBuilder(ctx)),
                                  ],

                              ),
                          ),
                      ],
                  ),
              ),
          ),
      );
  }



  Widget _buildAIItemCard(String label, IconData icon, {VoidCallback? onTap}) {
      return GestureDetector(
          onTap: onTap,
          child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                  children: [
                      Icon(icon, color: AppColors.primary, size: 20),
                      const SizedBox(width: 16),
                      Text(label, style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
              ),
          ),
      );
  }

  Widget _waterOptionTemplate(BuildContext dialogCtx, String label, int ml) {
      return GestureDetector(
          onTap: () {
              HapticFeedback.lightImpact();
              _addWater(ml);
          },




          child: Column(
              children: [
                  Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.water_rounded, color: Colors.blue, size: 28),

                  ),
                  const SizedBox(height: 10),
                  Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black87)),
              ],
          ),
      );
  }

  Widget _buildActivityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Performance', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('Last 7 Days', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(height: 180, width: double.infinity, child: CustomPaint(painter: _ActivityChartPainter(_weeklyStats))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _getDaysLabels().map((day) {
              return Text(day, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted));
            }).toList(),
          ),
          const SizedBox(height: 32),
          _buildPerformanceMetrics(),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Column(
      children: [
        Row(
          children: [
            _metricItem('', 'INTENSITY', _intensity, Colors.orange),
            _metricItem('', 'CONSISTENCY', _consistency, Colors.blue),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _metricItem('', 'RECOVERY', _recovery, Colors.green),
            _metricItem('', 'STREAK', '$_streak Days', AppColors.primary),
          ],
        ),
      ],
    );
  }

  Widget _metricItem(String num, String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Text(num, style: GoogleFonts.outfit(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 8),
                Text(label, style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }


  List<String> _getDaysLabels() {
      final now = DateTime.now();
      return List.generate(7, (i) {
          final d = now.subtract(Duration(days: 6 - i));
          return DateFormat('EEE').format(d).toUpperCase();
      });
  }

  Widget _buildHealthSection(bool hasMacroPlan, int totalCals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Nutrition Tracker', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            GestureDetector(
              onTap: () => context.push('/calculators'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('Recalculate', style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildNutritionOverview(hasMacroPlan, totalCals),
      ],
    );
  }

  Widget _buildNutritionOverview(bool hasMacroPlan, int totalCals) {
    if (!hasMacroPlan) {
        return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
                children: [
                    const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 40),
                    const SizedBox(height: 16),
                    Text('No Diet Plan Found', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Let AI architect a perfect nutrition plan based on your metrics.', 
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 24),
                    _primaryBtn('GET STARTED', () => context.push('/calculators')),
                ],
            ),
        );
    }

    final meals = _parseMeals();
    final progress = totalCals > 0 ? (_eatenCals / totalCals).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Fuel Progress', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('$_eatenCals / $totalCals kcal consumed', 
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 20,
                  backgroundColor: AppColors.bgSoft,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text('${(progress * 100).toInt()}%', 
                    style: GoogleFonts.outfit(color: progress > 0.5 ? Colors.white : AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Today\'s Meal Selection', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Column(
              children: meals.map((m) => _buildMealTickRow(m)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTickRow(Map<String, dynamic> meal) {
      final isChecked = _checkedMeals.contains(meal['title']);
      return GestureDetector(
          onTap: () => _toggleMeal(meal['title']),
          child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: isChecked ? AppColors.primary.withOpacity(0.05) : AppColors.bgSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isChecked ? AppColors.primary.withOpacity(0.2) : Colors.transparent),
              ),
              child: Row(
                  children: [
                      Icon(isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, 
                        color: isChecked ? AppColors.primary : AppColors.textMuted, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(meal['title'], 
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600, color: isChecked ? AppColors.textPrimary : AppColors.textSecondary)),
                      ),
                      Text('${meal['cals']} kcal', 
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: isChecked ? AppColors.primary : AppColors.textMuted)),
                  ],
              ),
          ),
      );
  }

  Widget _primaryBtn(String label, VoidCallback onTap) {
      return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
              ),
              child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
      );
  }

}

class _ActivityChartPainter extends CustomPainter {
  final List<double> values;
  _ActivityChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = Colors.black.withOpacity(0.03)..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
        final y = size.height * (i / 3);
        canvas.drawLine(Offset(0, y), Offset(size.width, y) , linePaint);
    }
    
    final points = List.generate(7, (i) {
        return Offset(i * (size.width / 6), size.height * (1.0 - values[i]));
    });

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i+1];
        path.cubicTo(p1.dx + (p2.dx - p1.dx) / 2, p1.dy, p1.dx + (p2.dx - p1.dx) / 2, p2.dy, p2.dx, p2.dy);
    }

    final curvePaint = Paint()
      ..shader = LinearGradient(
          colors: [Colors.blue, AppColors.primary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
          colors: [Colors.blue.withOpacity(0.1), AppColors.primary.withOpacity(0.01)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, curvePaint);

    final dotPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()..color = AppColors.primary..style = PaintingStyle.stroke..strokeWidth = 3;

    for (int i = 0; i < points.length; i++) {
        if (values[i] > 0.1) {
            canvas.drawCircle(points[i], 6, dotPaint);
            canvas.drawCircle(points[i], 6, dotBorderPaint);
        }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}