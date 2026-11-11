import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/progress_card.dart';
import '../widgets/task_card.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'task_form_screen.dart';

/// Filtros mostrados como "chips" acima da lista.
enum TaskFilter {
  todas('Todas'),
  pendentes('Pendentes'),
  atrasadas('Atrasadas'),
  concluidas('Concluídas');

  const TaskFilter(this.label);
  final String label;

  bool matches(Task t) => switch (this) {
    TaskFilter.todas => true,
    TaskFilter.pendentes => !t.done,
    TaskFilter.atrasadas => t.isOverdue,
    TaskFilter.concluidas => t.done,
  };
}

/// Opções de ordenação (menu no topo da tela).
enum TaskSort {
  recentes('Mais recentes'),
  prazo('Data limite'),
  prioridade('Prioridade');

  const TaskSort(this.label);
  final String label;
}

/// Tela principal: lista as tarefas (GET /tasks) com busca, filtros e ordenação.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Task> _tasks = [];
  User? _user;
  bool _loading = true;
  String? _error;

  TaskFilter _filter = TaskFilter.todas;
  TaskSort _sort = TaskSort.recentes;
  final _searchController = TextEditingController();
  String get _search => _searchController.text;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Busca usuário e tarefas ao mesmo tempo (Future.wait).
  /// O spinner de tela cheia só aparece na primeira carga.
  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([api.currentUser(), api.listTasks()]);
      setState(() {
        _user = results[0] as User;
        _tasks = results[1] as List<Task>;
      });
    } on ApiException catch (e) {
      // Token expirado/inválido: volta para o login
      if (e.statusCode == 401) return _sessionExpired(e.message);
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Executa uma ação na API e mostra o erro (se houver) em um SnackBar.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (e.statusCode == 401) return _sessionExpired(e.message);
      _showMessage(e.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _sessionExpired(String message) => logoutAndGoToLogin(context, message: message);

  /// Troca a tarefa antiga pela versão que a API devolveu (evita recarregar tudo).
  void _replace(Task updated) {
    setState(() => _tasks = [for (final t in _tasks) t.id == updated.id ? updated : t]);
  }

  Future<void> _toggleDone(Task task) => _run(() async {
    final updated = await api.updateTask(task.id, {'done': !task.done});
    _replace(updated);
    _showMessage(updated.done ? 'Tarefa concluída!' : 'Tarefa reaberta');
  });

  Future<void> _delete(Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Excluir tarefa'),
        content: Text('Deseja excluir "${task.title}"? Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await api.deleteTask(task.id);
      setState(() => _tasks.removeWhere((t) => t.id == task.id));
      _showMessage('Tarefa excluída');
    });
  }

  /// Abre o formulário. Se voltar "true" (salvou), recarrega a lista.
  Future<void> _openForm([Task? task]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)));
    if (saved == true) _load();
  }

  void _openProfile() {
    if (_user == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(user: _user!, tasks: _tasks),
      ),
    );
  }

  /// Aplica filtro, busca e ordenação sobre a lista que veio da API.
  List<Task> get _visibleTasks {
    final query = _search.toLowerCase();
    final list = _tasks.where((t) {
      final inText = t.title.toLowerCase().contains(query) || (t.description ?? '').toLowerCase().contains(query);
      return _filter.matches(t) && inText;
    }).toList();

    list.sort((a, b) {
      // Pendentes sempre antes das concluídas
      if (a.done != b.done) return a.done ? 1 : -1;
      switch (_sort) {
        case TaskSort.recentes:
          return b.createdAt.compareTo(a.createdAt);
        case TaskSort.prioridade:
          return b.priority.index.compareTo(a.priority.index); // alta > media > baixa
        case TaskSort.prazo:
          // Tarefas sem data vão para o final
          if (a.dueDate == null) return b.dueDate == null ? 0 : 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_user == null ? 'Minhas tarefas' : 'Olá, ${_user!.firstName}'),
        actions: [
          PopupMenuButton<TaskSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              for (final s in TaskSort.values)
                CheckedPopupMenuItem(value: s, checked: s == _sort, child: Text(s.label)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InkWell(
              onTap: _openProfile,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colors.primaryContainer,
                child: Text(_user?.initials ?? '', style: TextStyle(color: colors.onPrimaryContainer, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova tarefa'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _tasks.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.cloud_off,
          title: 'Algo deu errado',
          message: _error!,
          action: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ),
      );
    }

    final visible = _visibleTasks;

    // LayoutBuilder informa a largura disponível -> usado para deixar a tela responsiva
    return LayoutBuilder(
      builder: (context, constraints) {
        const maxContent = 1000.0;
        final sidePadding = constraints.maxWidth > maxContent + 32 ? (constraints.maxWidth - maxContent) / 2 : 16.0;
        final contentWidth = constraints.maxWidth - sidePadding * 2;
        // Telas largas (tablet, celular deitado, web) mostram as tarefas em 2 colunas
        final columns = contentWidth >= 700 ? 2 : 1;
        const spacing = 12.0;
        final cardWidth = (contentWidth - spacing * (columns - 1)) / columns;

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            // Garante que dá para "puxar para atualizar" mesmo com poucos itens
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 100),
            children: [
              ProgressCard(tasks: _tasks),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar tarefas',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_searchController.clear)),
                ),
                controller: _searchController,
                onChanged: (_) => setState(() {}), // redesenha a lista filtrada
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in TaskFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${f.label} (${_tasks.where(f.matches).length})'),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                _tasks.isEmpty
                    ? const EmptyState(
                        icon: Icons.checklist,
                        title: 'Nenhuma tarefa ainda',
                        message: 'Toque em "Nova tarefa" para criar a primeira.',
                      )
                    : const EmptyState(
                        icon: Icons.search_off,
                        title: 'Nada encontrado',
                        message: 'Tente outro filtro ou outra busca.',
                      )
              else
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final task in visible)
                      SizedBox(
                        width: cardWidth,
                        child: TaskCard(
                          task: task,
                          onToggle: () => _toggleDone(task),
                          onEdit: () => _openForm(task),
                          onDelete: () => _delete(task),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
