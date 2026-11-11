import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/dates.dart';
import '../utils/quick_add.dart';
import '../widgets/empty_state.dart';
import '../widgets/feedback.dart';
import '../widgets/greeting_header.dart';
import '../widgets/progress_card.dart';
import '../widgets/task_card.dart';
import 'achievements_screen.dart';
import 'calendar_screen.dart';
import 'focus_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'stats_screen.dart';
import 'task_form_screen.dart';

/// Filtros de status mostrados como "chips" acima da lista.
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
  Category? _category; // null = todas as categorias
  TaskSort _sort = TaskSort.recentes;
  final _searchController = TextEditingController();
  final _quickAddController = TextEditingController();
  String get _search => _searchController.text;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quickAddController.dispose();
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
      _showMessage(e.message, type: FeedbackType.error);
    }
  }

  /// Mostra um aviso no rodapé. [action] adiciona um botão (ex.: "Desfazer").
  void _showMessage(String message, {FeedbackType type = FeedbackType.info, SnackBarAction? action}) {
    if (mounted) showFeedback(context, message, type: type, action: action);
  }

  void _sessionExpired(String message) => logoutAndGoToLogin(context, message: message);

  /// Troca a tarefa antiga pela versão que a API devolveu (evita recarregar tudo).
  void _replace(Task updated) {
    setState(() => _tasks = [for (final t in _tasks) t.id == updated.id ? updated : t]);
  }

  Future<void> _toggleDone(Task task) => _run(() async {
    final updated = await api.updateTask(task.id, {'done': !task.done});
    _replace(updated);
    if (!updated.done) return _showMessage('Tarefa reaberta');
    // Tarefa recorrente: a API criou a próxima ocorrência, então recarrega a lista para ela aparecer
    if (task.recurrence != Recurrence.nunca) {
      await _load();
      return _showMessage('Concluída! A próxima repetição já foi criada.', type: FeedbackType.success);
    }
    // Era a última pendente? Mostra a comemoração em vez do aviso simples
    if (_tasks.every((t) => t.done)) {
      if (mounted) showAllDoneDialog(context);
    } else {
      _showMessage('Tarefa concluída!', type: FeedbackType.success);
    }
  });

  /// Exclui sem pedir confirmação, mas oferece "Desfazer".
  /// Desfazer = criar a tarefa de novo com os mesmos dados (ela ganha um novo id).
  Future<void> _delete(Task task) => _run(() async {
    await api.deleteTask(task.id);
    setState(() => _tasks.removeWhere((t) => t.id == task.id));
    _showMessage(
      'Tarefa excluída',
      action: SnackBarAction(
        label: 'Desfazer',
        textColor: Colors.white,
        onPressed: () => _run(() async {
          final restored = await api.createTask(task.toJson());
          setState(() => _tasks.add(restored));
        }),
      ),
    );
  });

  /// Cria uma cópia da tarefa (sempre como pendente).
  Future<void> _duplicate(Task task) => _run(() async {
    final copy = await api.createTask({...task.toJson(), 'title': '${task.title} (cópia)', 'done': false});
    setState(() => _tasks.add(copy));
    _showMessage('Tarefa duplicada', type: FeedbackType.success);
  });

  /// Criação rápida: "Prova amanhã !alta #faculdade" vira uma tarefa completa (veja utils/quick_add.dart).
  Future<void> _quickAdd() async {
    final data = parseQuickAdd(_quickAddController.text);
    if ((data['title'] as String).isEmpty) {
      return _showMessage('Escreva o nome da tarefa', type: FeedbackType.warning);
    }
    await _run(() async {
      final task = await api.createTask(data);
      _quickAddController.clear();
      setState(() => _tasks.add(task));
      final when = task.dueDate == null ? '' : ' para ${dueDateLabel(task.dueDate!).toLowerCase()}';
      _showMessage('Tarefa criada$when', type: FeedbackType.success);
    });
  }

  /// Abre o Modo Foco e recarrega ao voltar (os minutos de foco mudam).
  Future<void> _openFocus(Task task) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FocusScreen(task: task)));
    if (mounted) _load();
  }

  Future<void> _openCalendar() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    if (mounted) _load(); // tarefas podem ter sido criadas/editadas no calendário
  }

  void _openAchievements() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AchievementsScreen(tasks: _tasks)));
  }

  /// Apaga todas as concluídas (DELETE /tasks/concluidas). Aqui não há "desfazer", então pede confirmação.
  Future<void> _clearCompleted() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Limpar concluídas?',
      message: 'Todas as tarefas concluídas serão excluídas. Essa ação não pode ser desfeita.',
      icon: Icons.cleaning_services_outlined,
      confirmLabel: 'Limpar',
      destructive: true,
    );
    if (!ok) return;
    await _run(() async {
      final count = await api.deleteCompleted();
      setState(() => _tasks.removeWhere((t) => t.done));
      _showMessage(count == 1 ? '1 tarefa excluída' : '$count tarefas excluídas', type: FeedbackType.success);
    });
  }

  /// Abre o formulário. Se voltar "true" (salvou), recarrega a lista.
  Future<void> _openForm([Task? task]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)));
    if (saved == true) _load();
  }

  Future<void> _openProfile() async {
    if (_user == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(user: _user!, tasks: _tasks),
      ),
    );
    if (mounted) _load(); // o nome pode ter sido alterado no perfil
  }

  void _openStats() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StatsScreen(tasks: _tasks)));
  }

  /// Aplica filtros, busca e ordenação sobre a lista que veio da API.
  List<Task> get _visibleTasks {
    final query = _search.toLowerCase();
    final list = _tasks.where((t) {
      final inText = t.title.toLowerCase().contains(query) || (t.description ?? '').toLowerCase().contains(query);
      final inCategory = _category == null || t.category == _category;
      return _filter.matches(t) && inCategory && inText;
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
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), tooltip: 'Calendário', onPressed: _openCalendar),
          IconButton(icon: const Icon(Icons.insights), tooltip: 'Estatísticas', onPressed: _openStats),
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

  /// Grade de cards: 1 coluna no celular, 2 em telas largas ([cardWidth] vem do LayoutBuilder).
  Widget _cardsGrid(List<Task> tasks, double cardWidth, double spacing) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final task in tasks)
          SizedBox(
            width: cardWidth,
            child: TaskCard(
              task: task,
              onToggle: () => _toggleDone(task),
              onEdit: () => _openForm(task),
              onDelete: () => _delete(task),
              onDuplicate: () => _duplicate(task),
              onFocus: () => _openFocus(task),
            ),
          ),
      ],
    );
  }

  /// Separa as tarefas (já ordenadas por data) em seções.
  /// O Map mantém a ordem de inserção, então as seções aparecem na ordem da lista.
  Map<String, List<Task>> _groupByDate(List<Task> tasks) {
    final groups = <String, List<Task>>{};
    for (final t in tasks) {
      groups.putIfAbsent(_sectionOf(t), () => []).add(t);
    }
    return groups;
  }

  String _sectionOf(Task t) {
    if (t.done) return 'Concluídas';
    if (t.dueDate == null) return 'Sem data';
    final days = dateOnly(t.dueDate!).difference(today()).inDays;
    if (days < 0) return 'Atrasadas';
    if (days == 0) return 'Hoje';
    if (days == 1) return 'Amanhã';
    if (days <= 7) return 'Próximos 7 dias';
    return 'Mais tarde';
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
    final hasCompleted = _tasks.any((t) => t.done);

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
              if (_user != null) ...[
                GreetingHeader(name: _user!.firstName, tasks: _tasks, onAchievements: _openAchievements),
                const SizedBox(height: 20),
              ],
              ProgressCard(tasks: _tasks),
              const SizedBox(height: 16),
              // Criação rápida com atalhos
              TextField(
                controller: _quickAddController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Adicionar rápido...',
                  helperText: 'Atalhos: hoje, amanhã, 25/12, !alta, #faculdade',
                  helperMaxLines: 2, // quebra a linha em telas estreitas em vez de cortar
                  prefixIcon: const Icon(Icons.bolt),
                  suffixIcon: IconButton(icon: const Icon(Icons.send), tooltip: 'Criar', onPressed: _quickAdd),
                ),
                onSubmitted: (_) => _quickAdd(),
              ),
              const SizedBox(height: 12),
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
              // Filtro por status
              _ChipsRow(
                children: [
                  for (final f in TaskFilter.values)
                    ChoiceChip(
                      label: Text('${f.label} (${_tasks.where(f.matches).length})'),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Filtro por categoria (tocar de novo na mesma categoria remove o filtro)
              _ChipsRow(
                children: [
                  for (final c in Category.values)
                    FilterChip(
                      avatar: Icon(c.icon, size: 18),
                      label: Text(c.label),
                      showCheckmark: false,
                      selected: _category == c,
                      onSelected: (selected) => setState(() => _category = selected ? c : null),
                    ),
                ],
              ),
              if (_filter == TaskFilter.concluidas && hasCompleted)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearCompleted,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Limpar concluídas'),
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
              // Ordenando por data limite, a lista é dividida em seções (Atrasadas, Hoje, Amanhã...)
              else if (_sort == TaskSort.prazo)
                for (final MapEntry(key: title, value: tasks) in _groupByDate(visible).entries) ...[
                  _SectionTitle(title: title, count: tasks.length),
                  _cardsGrid(tasks, cardWidth, spacing),
                  const SizedBox(height: 8),
                ]
              else
                _cardsGrid(visible, cardWidth, spacing),
            ],
          ),
        );
      },
    );
  }
}

/// Título de uma seção da lista, com a quantidade de tarefas ao lado.
class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(color: colors.onPrimaryContainer, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Linha de chips com rolagem horizontal (não quebra em telas estreitas).
class _ChipsRow extends StatelessWidget {
  final List<Widget> children;
  const _ChipsRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [for (final c in children) Padding(padding: const EdgeInsets.only(right: 8), child: c)],
      ),
    );
  }
}
