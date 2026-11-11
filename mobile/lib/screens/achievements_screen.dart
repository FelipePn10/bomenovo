import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme.dart';
import '../utils/achievements.dart';
import '../widgets/responsive_center.dart';

/// Sequência de dias e medalhas (gamificação). Tudo calculado a partir das tarefas.
class AchievementsScreen extends StatelessWidget {
  final List<Task> tasks;
  const AchievementsScreen({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final streak = currentStreak(tasks);
    final achievements = buildAchievements(tasks);
    final unlocked = achievements.where((a) => a.unlocked).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Conquistas')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          maxWidth: 700,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StreakCard(streak: streak),
              const SizedBox(height: 24),
              Text(
                'Medalhas: $unlocked de ${achievements.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // 2 colunas no celular, 3 em telas largas
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 560 ? 3 : 2;
                  final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final a in achievements)
                        SizedBox(
                          width: width,
                          child: _BadgeCard(achievement: a),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: appGradient, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, size: 56, color: Color(0xFFFDBA74)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak == 1 ? '1 dia seguido' : '$streak dias seguidos',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  streak == 0
                      ? 'Conclua uma tarefa hoje para começar sua sequência.'
                      : 'Conclua pelo menos uma tarefa por dia para não perder a sequência.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Medalha: colorida quando desbloqueada; cinza com barra de progresso quando não.
class _BadgeCard extends StatelessWidget {
  final Achievement achievement;
  const _BadgeCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final a = achievement;
    final color = a.unlocked ? const Color(0xFFF59E0B) : colors.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(a.unlocked ? a.icon : Icons.lock_outline, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              a.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              a.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            if (a.unlocked)
              const Text(
                'Desbloqueada!',
                style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: a.progress, minHeight: 6),
              ),
              const SizedBox(height: 4),
              Text('${a.current.clamp(0, a.target)}/${a.target}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
