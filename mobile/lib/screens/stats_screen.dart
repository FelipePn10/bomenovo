import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/dates.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive_center.dart';

/// Estatísticas calculadas a partir da lista de tarefas (não chama a API).
/// Os gráficos são feitos só com Containers, sem pacote de gráficos.
class StatsScreen extends StatelessWidget {
  final List<Task> tasks;
  const StatsScreen({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.done).length;
    final rate = tasks.isEmpty ? 0 : (done / tasks.length * 100).round();
    final overdue = tasks.where((t) => t.isOverdue).length;

    // Últimos 7 dias, do mais antigo até hoje
    final days = [for (var i = 6; i >= 0; i--) today().subtract(Duration(days: i))];
    final doneByDay = [
      for (final day in days) tasks.where((t) => t.completedAt != null && dateOnly(t.completedAt!) == day).length,
    ];
    final doneThisWeek = doneByDay.fold(0, (sum, n) => sum + n);

    final pending = tasks.where((t) => !t.done).toList();
    final totalFocus = tasks.fold(0, (sum, t) => sum + t.focusMinutes);
    // As 3 tarefas com mais tempo de foco
    final topFocus = tasks.where((t) => t.focusMinutes > 0).toList()
      ..sort((a, b) => b.focusMinutes.compareTo(a.focusMinutes));

    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: tasks.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.insights,
                title: 'Sem dados ainda',
                message: 'Crie algumas tarefas para ver as estatísticas.',
              ),
            )
          : SingleChildScrollView(
              child: ResponsiveCenter(
                maxWidth: 700,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _NumberTile(value: '$rate%', label: 'Concluídas'),
                        const SizedBox(width: 12),
                        _NumberTile(value: '$doneThisWeek', label: 'Feitas em 7 dias'),
                        const SizedBox(width: 12),
                        _NumberTile(value: '$overdue', label: 'Atrasadas'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Concluídas nos últimos 7 dias',
                      child: _WeekChart(days: days, values: doneByDay),
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Pendentes por prioridade',
                      child: Column(
                        children: [
                          for (final p in Priority.values.reversed)
                            _HorizontalBar(
                              icon: Icons.flag,
                              iconColor: p.color,
                              label: p.label,
                              value: pending.where((t) => t.priority == p).length,
                              max: pending.length,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Modo foco: ${formatMinutes(totalFocus)} no total',
                      child: topFocus.isEmpty
                          ? const Text('Use o Modo foco (menu ⋮ de uma tarefa) para registrar seu tempo.')
                          : Column(
                              children: [
                                for (final t in topFocus.take(3))
                                  _HorizontalBar(
                                    icon: Icons.timer_outlined,
                                    label: t.title,
                                    value: t.focusMinutes,
                                    max: topFocus.first.focusMinutes,
                                    valueText: formatMinutes(t.focusMinutes),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Tarefas por categoria',
                      child: Column(
                        children: [
                          for (final c in Category.values)
                            _HorizontalBar(
                              icon: c.icon,
                              label: c.label,
                              value: tasks.where((t) => t.category == c).length,
                              max: tasks.length,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Número grande com legenda embaixo.
class _NumberTile extends StatelessWidget {
  final String value;
  final String label;
  const _NumberTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(value, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: text.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card com título, usado para envolver cada gráfico.
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Gráfico de colunas: uma coluna por dia. A altura é proporcional ao maior valor.
class _WeekChart extends StatelessWidget {
  final List<DateTime> days;
  final List<int> values;
  const _WeekChart({required this.days, required this.values});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    const maxHeight = 120.0;
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Column(
              children: [
                Text('${values[i]}', style: small),
                const SizedBox(height: 4),
                Container(
                  width: 24,
                  // Dia sem tarefas ainda mostra uma "base" de 3px para o gráfico não ficar vazio
                  height: maxValue == 0 ? 3 : 3 + (maxHeight - 3) * values[i] / maxValue,
                  decoration: BoxDecoration(
                    color: values[i] == 0 ? colors.outlineVariant : colors.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(i == days.length - 1 ? 'hoje' : weekdayShort(days[i]), style: small),
              ],
            ),
          ),
      ],
    );
  }
}

/// Barra horizontal: ícone + nome, barra proporcional e o valor no final.
class _HorizontalBar extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final int value;
  final int max;
  final String? valueText; // texto no lugar do número (ex.: "1h 25min")
  const _HorizontalBar({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
    required this.max,
    this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fraction = max == 0 ? 0.0 : value / max;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? colors.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                color: colors.primary,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
          ),
          SizedBox(
            width: valueText == null ? 36 : 72,
            child: Text(valueText ?? '$value', textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
