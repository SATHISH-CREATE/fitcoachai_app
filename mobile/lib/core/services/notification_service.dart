import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'storage_service.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap
        },
      );
    } catch (e) {
      debugPrint("Notification Initialization Error: $e");
    }
  }

  /// Call this AFTER the user has logged in to request permission and schedule reminders.
  static Future<void> requestAndSchedule() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      await scheduleDailyReminders();
    } catch (e) {
      debugPrint("Notification Schedule Error: $e");
    }
  }

  static Future<void> scheduleDailyReminders() async {
    // Cancel existing to avoid duplicates
    await _notifications.cancelAll();

    // 1. Morning Reminder: Daily Focus & Goals (8:00 AM)
    await _scheduleNotification(
      id: 1,
      title: "Today's Blueprint",
      body: _getMorningMessage(),
      hour: 8,
      minute: 0,
    );

    // 2. Afternoon Reminder: Hydration Check (2:00 PM)
    await _scheduleNotification(
      id: 2,
      title: "Hydration Check 💧",
      body: _getHydrationMessage(),
      hour: 14,
      minute: 0,
    );

    // 3. Evening Reminder: Goal Completion (7:00 PM)
    await _scheduleNotification(
      id: 3,
      title: "Evening Progress Check",
      body: _getEveningMessage(),
      hour: 19,
      minute: 0,
    );
  }

  static String _getMorningMessage() {
    final now = DateTime.now();
    final plan = StorageService.get6DayPlan();
    final dayIndex = (now.weekday - 1) % 7; // Monday = 0
    
    String focus = "REST DAY";
    if (plan.isNotEmpty && dayIndex < plan.length) {
      focus = plan[dayIndex]['title'] ?? "REST DAY";
    }

    final macroPlan = StorageService.getMacroPlan();
    final targetCals = macroPlan['calories'] ?? 2000;

    return "Focus: $focus | Calorie Goal: $targetCals kcal. Let's conquer the day!";
  }

  static String _getHydrationMessage() {
    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final water = StorageService.getWater(dateKey);
    final goal = StorageService.getItem('water_goal') ?? 3500;
    
    if (water >= goal) return "You've crushed your water goal! Stay legendary.";
    return "You've drank $water ml. Target is $goal ml. Keep sipping! 🌊";
  }

  static String _getEveningMessage() {
    final macroPlan = StorageService.getMacroPlan();
    final targetCals = macroPlan['calories'] ?? 2000;
    return "Reflect on your gains. Target was $targetCals kcal. Log your meals to stay on track!";
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fitcoach_reminders',
          'Daily Reminders',
          channelDescription: 'Daily goals, hydration, and training focus reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
