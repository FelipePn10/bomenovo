import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/dates.dart';

/// Card de uma tarefa na lista.
///
/// Gestos: tocar = editar | arrastar para a direita = concluir/reabrir
///         arrastar para a esquerda = excluir
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const TaskCard({super.key, required this.task, required this.onToggle, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Dismissible(
      key: ValueKey(task.id),
      background: _swipeBackground(task.done ? Icons.undo : Icons.check, Colors.green, Alignment.centerLeft),
      secondaryBackground: _swipeBackground(Icons.delete_outline, colors.error, Alignment.centerRight),
      // Sempre retorna false: quem atualiza a lista é a tela de tarefas,
      // o Dismissible só serve para capturar o gesto.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggle();
        } else {
          await onDelete();
        }
        return false;
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          // IntrinsicHeight faz a faixa colorida ter a mesma altura do conteúdo
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Faixa lateral com a cor da prioridade
                Container(width: 5, color: task.done ? colors.outlineVariant : task.priority.color),
                IconButton(
                  onPressed: onToggle,
                  tooltip: task.done ? 'Marcar como pendente' : 'Concluir',
                  icon: Icon(
                    task.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: task.done ? Colors.green : colors.outline,
                    size: 28,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          task.title,
                          style: text.titleMedium?.copyWith(
                            decoration: task.done ? TextDecoration.lineThrough : null,
                            color: task.done ? colors.onSurfaceVariant : null,
                          ),
                        ),
                        if (task.description?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Tag(icon: Icons.flag, label: task.priority.label, color: task.priority.color),
                            if (task.dueDate != null)
                              _Tag(
                                icon: Icons.event,
                                label: task.done ? formatDate(task.dueDate!) : dueDateLabel(task.dueDate!),
                                color: task.isOverdue ? colors.error : colors.primary,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(leading: Icon(Icons.edit), title: Text('Editar')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Excluir')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeBackground(IconData icon, Color color, Alignment alignment) => Container(
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
    child: Icon(icon, color: Colors.white),
  );
}

/// Etiqueta pequena (prioridade, data limite).
class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
