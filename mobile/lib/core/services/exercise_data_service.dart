import 'dart:convert';
import 'package:flutter/services.dart';

class Exercise {
  final String name;
  final String description;
  final List<String> tags;
  final String videoUrl;
  final String imageUrl;
  final int recoveryTime;

  Exercise({
    required this.name,
    required this.description,
    required this.tags,
    required this.videoUrl,
    required this.imageUrl,
    required this.recoveryTime,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      videoUrl: json['videoUrl'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      recoveryTime: json['recoveryTime'] ?? 60,
    );
  }
}

class Subcategory {
  final String title;
  final List<Exercise> exercises;

  Subcategory({
    required this.title,
    required this.exercises,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      title: json['title'] ?? '',
      exercises: (json['exercises'] as List?)
          ?.map((e) => Exercise.fromJson(e))
          .toList() ?? [],
    );
  }
}

class Category {
  final String name;
  final List<Subcategory> subcategories;

  Category({
    required this.name,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      name: json['name'] ?? '',
      subcategories: (json['subcategories'] as List?)
          ?.map((e) => Subcategory.fromJson(e))
          .toList() ?? [],
    );
  }

  List<Exercise> get allExercises {
    return subcategories.expand((sub) => sub.exercises).toList();
  }
}

class ExerciseDataService {
  static List<Category>? _cachedCategories;

  static Future<List<Category>> loadCategories() async {
    if (_cachedCategories != null) {
      return _cachedCategories!;
    }

    final jsonString = await rootBundle.loadString('assets/exercises.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    _cachedCategories = jsonList.map((e) => Category.fromJson(e)).toList();
    return _cachedCategories!;
  }

  static Future<Category?> getCategory(String name) async {
    final categories = await loadCategories();
    try {
      return categories.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  static Future<Exercise?> getExercise(String name) async {
    final categories = await loadCategories();
    for (final category in categories) {
      for (final exercise in category.allExercises) {
        if (exercise.name == name) {
          return exercise;
        }
      }
    }
    return null;
  }
}
