import 'package:flutter/material.dart';

import '../models/task.dart';
import 'dates.dart';

/// Uma conquista (medalha). [current] é o progresso atual e [target] a meta.
class Achievement {
  final IconData icon;
  final String title;
  final String description;
  final int current;
  final int target;

  const Achievement(this.icon, this.title, this.description, this.current, this.target);

  bool get unlocked => current >= target;
  double get progress => (current / target).clamp(0, 1).toDouble();
}

/// Dias diferentes em que o usuário concluiu pelo menos uma tarefa.
Set<DateTime> _completionDays(List<Task> tasks) => {
  for (final t in tasks)
    if (t.completedAt != null) dateOnly(t.completedAt!),
};

/// Sequência: quantos dias seguidos (até hoje) o usuário concluiu alguma tarefa.
/// Se ainda não concluiu nada hoje, a sequência de ontem continua valendo.
int currentStreak(List<Task> tasks) {
  final days = _completionDays(tasks);
  var day = days.contains(today()) ? today() : today().subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Maior número de tarefas concluídas em um único dia.
int _bestDay(List<Task> tasks) {
  final perDay = <DateTime, int>{};
  for (final t in tasks) {
    if (t.completedAt != null) perDay.update(dateOnly(t.completedAt!), (n) => n + 1, ifAbsent: () => 1);
  }
  return perDay.values.fold(0, (best, n) => n > best ? n : best);
}

/// Lista de conquistas calculadas a partir das tarefas.
/// Tudo é calculado no app; tarefas excluídas deixam de contar.
List<Achievement> buildAchievements(List<Task> tasks) {
  final done = tasks.where((t) => t.done).length;
  final focus = tasks.fold(0, (sum, t) => sum + t.focusMinutes);
  final categories = tasks.map((t) => t.category).toSet().length;
  final overdue = tasks.where((t) => t.isOverdue).length;
  final streak = currentStreak(tasks);

  return [
    Achievement(Icons.flag_rounded, 'Primeiro passo', 'Conclua sua primeira tarefa', done, 1),
    Achievement(Icons.workspace_premium, 'Produtivo', 'Conclua 10 tarefas', done, 10),
    Achievement(Icons.emoji_events, 'Imparável', 'Conclua 50 tarefas', done, 50),
    Achievement(Icons.bolt, 'Dia cheio', 'Conclua 5 tarefas no mesmo dia', _bestDay(tasks), 5),
    Achievement(Icons.local_fire_department, 'Constância', 'Mantenha uma sequência de 3 dias', streak, 3),
    Achievement(Icons.whatshot, 'Hábito formado', 'Mantenha uma sequência de 7 dias', streak, 7),
    Achievement(Icons.timer, 'Focado', 'Acumule 60 minutos no Modo Foco', focus, 60),
    Achievement(Icons.category, 'Organizado', 'Use 3 categorias diferentes', categories, 3),
    // "Em dia": ter pelo menos 5 tarefas e nenhuma atrasada (conta 1 quando a condição vale)
    Achievement(
      Icons.verified,
      'Em dia',
      'Tenha 5+ tarefas e nenhuma atrasada',
      tasks.length >= 5 && overdue == 0 ? 1 : 0,
      1,
    ),
  ];
}
