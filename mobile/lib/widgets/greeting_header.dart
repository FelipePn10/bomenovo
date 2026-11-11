import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/dates.dart';

/// Cabeçalho da tela inicial: data, saudação com o nome e um resumo do dia.
class GreetingHeader extends StatelessWidget {
  final String name;
  final List<Task> tasks;
  const GreetingHeader({super.key, required this.name, required this.tasks});

  /// Ícone e cor mudam conforme o período do dia (manhã, tarde, noite).
  (IconData, Color) get _periodIcon {
    final hour = DateTime.now().hour;
    if (hour < 12) return (Icons.wb_sunny_rounded, const Color(0xFFF59E0B));
    if (hour < 18) return (Icons.wb_twilight_rounded, const Color(0xFFEA580C));
    return (Icons.nightlight_round, const Color(0xFF6366F1));
  }

  /// "1 tarefa" / "3 tarefas"
  String _count(int n, String singular, String plural) => '$n ${n == 1 ? singular : plural}';

  /// Frase de resumo: mostra primeiro o que é mais urgente.
  (IconData, String) get _summary {
    final overdue = tasks.where((t) => t.isOverdue).length;
    final dueToday = tasks.where((t) => t.isDueToday).length;
    final pending = tasks.where((t) => !t.done).length;

    if (tasks.isEmpty) return (Icons.add_task, 'Que tal criar sua primeira tarefa?');
    if (overdue > 0) return (Icons.warning_amber_rounded, _count(overdue, 'tarefa atrasada', 'tarefas atrasadas'));
    if (dueToday > 0) return (Icons.today, '${_count(dueToday, 'tarefa', 'tarefas')} para hoje');
    if (pending == 0) return (Icons.verified_rounded, 'Tudo em dia por aqui!');
    return (Icons.pending_actions, _count(pending, 'tarefa pendente', 'tarefas pendentes'));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (periodIcon, periodColor) = _periodIcon;
    final (summaryIcon, summaryText) = _summary;
    final date = longDate(DateTime.now());

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primeira letra maiúscula: "Quarta-feira, 11 de novembro"
              Text(
                date[0].toUpperCase() + date.substring(1),
                style: text.labelLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: '${greeting()}, ',
                  children: [
                    TextSpan(
                      text: name,
                      style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                style: text.headlineSmall,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(summaryIcon, size: 18, color: colors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(summaryText, style: TextStyle(color: colors.onSurfaceVariant)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: periodColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(periodIcon, size: 30, color: periodColor),
        ),
      ],
    );
  }
}
