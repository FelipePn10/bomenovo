import 'package:flutter/material.dart';

import '../utils/dates.dart';

/// Prioridades aceitas pela API. O "name" do enum (baixa, media, alta) é o valor enviado no JSON.
enum Priority {
  baixa('Baixa', Color(0xFF16A34A)),
  media('Média', Color(0xFFF59E0B)),
  alta('Alta', Color(0xFFDC2626));

  const Priority(this.label, this.color);
  final String label;
  final Color color;

  static Priority fromApi(String? value) =>
      Priority.values.firstWhere((p) => p.name == value, orElse: () => Priority.media);
}

/// Representa uma tarefa retornada pela API.
class Task {
  final int id;
  final String title;
  final String? description;
  final bool done;
  final Priority priority;
  final DateTime? dueDate;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.done,
    required this.priority,
    this.dueDate,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    done: json['done'],
    priority: Priority.fromApi(json['priority']),
    dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date']),
    createdAt: DateTime.parse(json['created_at']).toLocal(),
  );

  /// Pendente e com data limite já passada.
  bool get isOverdue => !done && dueDate != null && dueDate!.isBefore(today());

  /// Pendente e com data limite para hoje.
  bool get isDueToday => !done && dueDate != null && dateOnly(dueDate!) == today();
}
