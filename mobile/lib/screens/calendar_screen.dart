import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/api_service.dart';
import '../utils/dates.dart';
import '../widgets/feedback.dart';
import '../widgets/responsive_center.dart';
import 'task_form_screen.dart';

/// Calendário mensal: marca os dias que têm tarefas e lista as do dia escolhido.
/// Carrega as tarefas sozinho para continuar atualizado depois de criar/editar.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Task> _tasks = [];
  bool _loading = true;
  DateTime _month = DateTime(today().year, today().month); // mês exibido (sempre dia 1)
  DateTime _selected = today();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await api.listTasks();
      setState(() => _tasks = tasks);
    } on ApiException catch (e) {
      if (mounted) showFeedback(context, e.message, type: FeedbackType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Task> _tasksOn(DateTime day) => _tasks.where((t) => t.dueDate != null && dateOnly(t.dueDate!) == day).toList();

  /// [delta] = -1 volta um mês, +1 avança. O DateTime ajusta o ano sozinho (mês 13 vira janeiro).
  void _changeMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _openForm({Task? task}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(task: task, initialDueDate: _selected),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dayTasks = _tasksOn(_selected);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendário')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ResponsiveCenter(
                maxWidth: 560,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                                Expanded(
                                  child: Text(monthYear(_month), style: text.titleMedium, textAlign: TextAlign.center),
                                ),
                                IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _MonthGrid(
                              month: _month,
                              selected: _selected,
                              tasksOn: _tasksOn,
                              onSelect: (day) => setState(() => _selected = day),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Text(dueDateLabel(_selected), style: text.titleMedium)),
                        Text(formatDate(_selected), style: text.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (dayTasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Nenhuma tarefa com data limite neste dia.', textAlign: TextAlign.center),
                      )
                    else
                      for (final t in dayTasks)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              t.done ? Icons.check_circle : Icons.circle,
                              color: t.done ? Colors.green : t.priority.color,
                              size: t.done ? 24 : 14,
                            ),
                            title: Text(
                              t.title,
                              style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null),
                            ),
                            subtitle: Text('${t.category.label} · prioridade ${t.priority.label.toLowerCase()}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openForm(task: t),
                          ),
                        ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nova tarefa neste dia'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Grade do mês: 7 colunas (segunda a domingo).
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final List<Task> Function(DateTime day) tasksOn;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({required this.month, required this.selected, required this.tasksOn, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Dia 0 do mês seguinte = último dia deste mês
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Quantos espaços vazios antes do dia 1 (weekday: 1 = segunda ... 7 = domingo)
    final blanks = month.weekday - 1;

    return Column(
      children: [
        Row(
          children: [
            for (final d in ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'])
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true, // ocupa só o espaço necessário dentro da coluna
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < blanks; i++) const SizedBox(),
            for (var day = 1; day <= daysInMonth; day++) _dayCell(context, DateTime(month.year, month.month, day)),
          ],
        ),
      ],
    );
  }

  Widget _dayCell(BuildContext context, DateTime day) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = day == selected;
    final isToday = day == today();
    final tasks = tasksOn(day);

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => onSelect(day),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? colors.primary : null,
          border: isToday && !isSelected ? Border.all(color: colors.primary, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}', style: TextStyle(color: isSelected ? colors.onPrimary : null)),
            // Até 3 pontinhos: um por tarefa, com a cor da prioridade (cinza se concluída)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final t in tasks.take(3))
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? colors.onPrimary : (t.done ? colors.outline : t.priority.color),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
