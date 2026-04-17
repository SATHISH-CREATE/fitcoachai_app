import 'dart:convert';
import 'package:flutter/material.dart';

class ImageUtils {
  static ImageProvider? getAvatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final base64Data = url.split(',').last;
        return MemoryImage(base64Decode(base64Data));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(url);
  }
}
