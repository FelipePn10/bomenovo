import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/api_service.dart';
import '../utils/dates.dart';
import '../widgets/responsive_center.dart';

/// Formulário usado tanto para criar (POST /tasks) quanto para editar (PUT /tasks/{id}).
class TaskFormScreen extends StatefulWidget {
  final Task? task; // null = nova tarefa
  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // "late" permite usar widget.task na inicialização (preenche os campos ao editar)
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(text: widget.task?.description);
  late Priority _priority = widget.task?.priority ?? Priority.media;
  late DateTime? _dueDate = widget.task?.dueDate;
  late bool _done = widget.task?.done ?? false;
  bool _saving = false;

  bool get _isEditing => widget.task != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final description = _description.text.trim();
    // Corpo enviado para a API (mesmos nomes de campo do backend)
    final data = {
      'title': _title.text.trim(),
      'description': description.isEmpty ? null : description,
      'priority': _priority.name,
      'due_date': _dueDate == null ? null : toApiDate(_dueDate!),
      if (_isEditing) 'done': _done,
    };

    try {
      if (_isEditing) {
        await api.updateTask(widget.task!.id, data);
      } else {
        await api.createTask(data);
      }
      // Devolve true para a lista saber que precisa recarregar
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar tarefa' : 'Nova tarefa')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          maxWidth: 600,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _title,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Título', prefixIcon: Icon(Icons.title)),
                  maxLength: 120, // mesmo limite da API
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o título' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Descrição (opcional)', alignLabelWithHint: true),
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 24),

                Text('Prioridade', style: text.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<Priority>(
                    segments: [
                      for (final p in Priority.values)
                        ButtonSegment(
                          value: p,
                          label: Text(p.label),
                          icon: Icon(Icons.flag, color: p.color),
                        ),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (s) => setState(() => _priority = s.first),
                  ),
                ),
                const SizedBox(height: 24),

                Text('Data limite', style: text.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(_dueDate == null ? 'Sem data limite' : formatDate(_dueDate!)),
                    subtitle: _dueDate == null ? const Text('Toque para escolher') : Text(dueDateLabel(_dueDate!)),
                    onTap: _pickDate,
                    trailing: _dueDate == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Remover data',
                            onPressed: () => setState(() => _dueDate = null),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                // Atalhos para as datas mais comuns
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(label: const Text('Hoje'), onPressed: () => setState(() => _dueDate = today())),
                    ActionChip(
                      label: const Text('Amanhã'),
                      onPressed: () => setState(() => _dueDate = today().add(const Duration(days: 1))),
                    ),
                    ActionChip(
                      label: const Text('Em 1 semana'),
                      onPressed: () => setState(() => _dueDate = today().add(const Duration(days: 7))),
                    ),
                  ],
                ),

                if (_isEditing) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      title: const Text('Concluída'),
                      secondary: const Icon(Icons.check_circle_outline),
                      value: _done,
                      onChanged: (v) => setState(() => _done = v),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(_isEditing ? 'Salvar alterações' : 'Criar tarefa'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
