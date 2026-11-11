import 'package:flutter/material.dart';

import '../theme.dart';

import '../models/task.dart';

/// Resumo no topo da lista: porcentagem concluída e contadores.
class ProgressCard extends StatelessWidget {
  final List<Task> tasks;
  const ProgressCard({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.done).length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    final dueToday = tasks.where((t) => t.isDueToday).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: appGradient),
      // merge: mantém a fonte do tema e só troca a cor do texto para branco
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Seu progresso', style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        '$done de ${tasks.length} concluídas',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Counter(icon: Icons.pending_actions, value: tasks.length - done, label: 'Pendentes'),
                _Counter(icon: Icons.today, value: dueToday, label: 'Para hoje'),
                _Counter(icon: Icons.warning_amber_rounded, value: overdue, label: 'Atrasadas'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  const _Counter({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    const color = Colors.white;
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text('$value $label', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
