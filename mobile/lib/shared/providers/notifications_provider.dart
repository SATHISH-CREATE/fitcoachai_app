import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../models/notification_model.dart';
import 'dart:convert';

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<AppNotification>>((ref) {
  return NotificationsNotifier();
});

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier() : super([]) {
    _loadNotifications();
  }

  void _loadNotifications() {
    final List<dynamic> saved = StorageService.getItem('app_notifications') ?? [];
    state = saved.map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item))).toList();
    
    // Sort by timestamp descending
    state.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  void _saveNotifications() {
    final List<Map<String, dynamic>> jsonList = state.map((n) => n.toJson()).toList();
    StorageService.setItem('app_notifications', jsonList);
  }

  void addNotification({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final newNoti = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      icon: icon,
      color: color,
      timestamp: DateTime.now(),
    );
    
    state = [newNoti, ...state];
    _saveNotifications();
  }

  void markAsRead() {
    state = [
      for (final n in state)
        n..isRead = true
    ];
    _saveNotifications();
  }

  void clearAll() {
    state = [];
    _saveNotifications();
  }

  bool get hasUnread => state.any((n) => !n.isRead);
}
