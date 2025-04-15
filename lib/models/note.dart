import 'package:flutter/material.dart';

class Note {
  String id;
  String title;
  String content;
  bool isPinned;
  DateTime createdAt;
  Color color;
  List<String> imagePaths;
  DateTime? deletedAt; // New field for trash bin

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.isPinned = false,
    DateTime? createdAt,
    Color? color,
    List<String>? imagePaths,
    this.deletedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        color = color ?? Colors.white,
        imagePaths = imagePaths ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
    'color': color.value.toRadixString(16).padLeft(8, '0'),
    'imagePaths': imagePaths,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    isPinned: json['isPinned'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
    color: Color(int.parse(json['color'], radix: 16)),
    imagePaths: List<String>.from(json['imagePaths'] ?? []),
    deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt']) : null,
  );
}