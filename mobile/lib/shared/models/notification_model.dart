import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'icon_code': icon.codePoint,
    'color_value': color.value,
    'timestamp': timestamp.toIso8601String(),
    'is_read': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      icon: IconData(json['icon_code'], fontFamily: 'MaterialIcons'),
      color: Color(json['color_value']),
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['is_read'] ?? false,
    );
  }
}
