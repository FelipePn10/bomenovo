import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/api_service.dart';
import '../utils/dates.dart';
import '../widgets/feedback.dart';
import '../widgets/responsive_center.dart';

/// Formulário usado tanto para criar (POST /tasks) quanto para editar (PUT /tasks/{id}).
class TaskFormScreen extends StatefulWidget {
  final Task? task; // null = nova tarefa
  final DateTime? initialDueDate; // data já preenchida ao criar pelo calendário
  const TaskFormScreen({super.key, this.task, this.initialDueDate});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  // "late" permite usar widget.task na inicialização (preenche os campos ao editar)
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(text: widget.task?.description);
  late Priority _priority = widget.task?.priority ?? Priority.media;
  late Category _category = widget.task?.category ?? Category.outros;
  late DateTime? _dueDate = widget.task == null ? widget.initialDueDate : widget.task!.dueDate;
  late Recurrence _recurrence = widget.task?.recurrence ?? Recurrence.nunca;
  // Cópia editável do checklist (a lista original da tarefa não é alterada até salvar)
  late final List<ChecklistItem> _checklist = [...?widget.task?.checklist];
  final _newItem = TextEditingController();
  late bool _done = widget.task?.done ?? false;
  bool _saving = false;

  bool get _isEditing => widget.task != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _newItem.dispose();
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

  void _addItem() {
    final text = _newItem.text.trim();
    if (text.isEmpty) return;
    setState(() => _checklist.add(ChecklistItem(text)));
    _newItem.clear();
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
      'category': _category.name,
      'recurrence': _recurrence.name,
      'checklist': [for (final item in _checklist) item.toJson()],
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
      if (mounted) showFeedback(context, e.message, type: FeedbackType.error);
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

                Text('Categoria', style: text.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in Category.values)
                      ChoiceChip(
                        avatar: Icon(c.icon, size: 18),
                        label: Text(c.label),
                        showCheckmark: false,
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
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
                const SizedBox(height: 24),

                Text('Repetir', style: text.titleSmall),
                const SizedBox(height: 8),
                // Ao concluir uma tarefa que se repete, a API cria a próxima automaticamente
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in Recurrence.values)
                      ChoiceChip(
                        avatar: r == Recurrence.nunca ? null : const Icon(Icons.repeat, size: 18),
                        label: Text(r.label),
                        selected: _recurrence == r,
                        onSelected: (_) => setState(() => _recurrence = r),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('Checklist', style: text.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < _checklist.length; i++)
                        CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _checklist[i].done,
                          // Itens são imutáveis: para marcar, troca o item por um novo
                          onChanged: (v) => setState(() => _checklist[i] = ChecklistItem(_checklist[i].text, done: v!)),
                          title: Text(
                            _checklist[i].text,
                            style: TextStyle(decoration: _checklist[i].done ? TextDecoration.lineThrough : null),
                          ),
                          secondary: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Remover item',
                            onPressed: () => setState(() => _checklist.removeAt(i)),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                        child: TextField(
                          controller: _newItem,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Adicionar item',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            filled: false,
                            suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _addItem),
                          ),
                          onSubmitted: (_) => _addItem(),
                        ),
                      ),
                    ],
                  ),
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
