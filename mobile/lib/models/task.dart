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

/// Categorias aceitas pela API. Cada uma tem um nome e um ícone para a tela.
enum Category {
  faculdade('Faculdade', Icons.school_outlined),
  trabalho('Trabalho', Icons.work_outline),
  pessoal('Pessoal', Icons.person_outline),
  casa('Casa', Icons.home_outlined),
  saude('Saúde', Icons.favorite_outline),
  outros('Outros', Icons.label_outline);

  const Category(this.label, this.icon);
  final String label;
  final IconData icon;

  static Category fromApi(String? value) =>
      Category.values.firstWhere((c) => c.name == value, orElse: () => Category.outros);
}

/// Representa uma tarefa retornada pela API.
class Task {
  final int id;
  final String title;
  final String? description;
  final bool done;
  final Priority priority;
  final Category category;
  final DateTime? dueDate;
  final DateTime? completedAt; // quando foi concluída (null se pendente)
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.done,
    required this.priority,
    required this.category,
    this.dueDate,
    this.completedAt,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    done: json['done'],
    priority: Priority.fromApi(json['priority']),
    category: Category.fromApi(json['category']),
    dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date']),
    completedAt: json['completed_at'] == null ? null : parseApiDateTime(json['completed_at']),
    createdAt: parseApiDateTime(json['created_at']),
  );

  /// Converte para o formato que a API recebe no POST /tasks.
  /// Usado para "desfazer" uma exclusão e para duplicar uma tarefa.
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'done': done,
    'priority': priority.name,
    'category': category.name,
    'due_date': dueDate == null ? null : toApiDate(dueDate!),
  };

  /// Pendente e com data limite já passada.
  bool get isOverdue => !done && dueDate != null && dueDate!.isBefore(today());

  /// Pendente e com data limite para hoje.
  bool get isDueToday => !done && dueDate != null && dateOnly(dueDate!) == today();
}
