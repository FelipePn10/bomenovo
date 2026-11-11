import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarefas_app/models/task.dart';
import 'package:tarefas_app/models/user.dart';
import 'package:tarefas_app/screens/achievements_screen.dart';
import 'package:tarefas_app/screens/calendar_screen.dart';
import 'package:tarefas_app/screens/focus_screen.dart';
import 'package:tarefas_app/screens/login_screen.dart';
import 'package:tarefas_app/screens/profile_screen.dart';
import 'package:tarefas_app/screens/register_screen.dart';
import 'package:tarefas_app/screens/stats_screen.dart';
import 'package:tarefas_app/screens/task_form_screen.dart';
import 'package:tarefas_app/screens/tasks_screen.dart';
import 'package:tarefas_app/theme.dart';
import 'package:tarefas_app/utils/dates.dart';

/// Garante que nenhuma tela "estoura" (faixa amarela e preta de overflow) em telas pequenas,
/// celular deitado, tablet e com a fonte do sistema aumentada.

final _today = toApiDate(today());

Map<String, dynamic> _taskJson(int id, {bool done = false, String? title}) => {
  'id': id,
  'title': title ?? 'Tarefa $id com um título comprido para testar a quebra de linha na tela',
  'description': 'Descrição da tarefa $id',
  'done': done,
  'priority': ['baixa', 'media', 'alta'][id % 3],
  'category': ['faculdade', 'trabalho', 'pessoal', 'casa', 'saude', 'outros'][id % 6],
  'due_date': id.isEven ? _today : null,
  'recurrence': id % 4 == 0 ? 'semanal' : 'nunca',
  'checklist': [
    {'text': 'Item A', 'done': true},
    {'text': 'Item B', 'done': false},
  ],
  'focus_minutes': id * 10,
  'completed_at': done ? DateTime.now().toUtc().toIso8601String() : null,
  'created_at': '2026-11-01T10:00:00Z',
};

final _tasksJson = [for (var i = 1; i <= 8; i++) _taskJson(i, done: i % 3 == 0)];
final _userJson = {
  'id': 1,
  'name': 'Maria Aparecida dos Santos Oliveira',
  'email': 'maria.aparecida.oliveira@exemplo.com.br',
  'created_at': '2026-11-01T10:00:00Z',
};

/// API falsa: responde as rotas usadas pelas telas.
final _mockApi = MockClient((req) async {
  final path = req.url.path;
  Object body = {'detail': 'não encontrado'};
  var status = 200;
  if (path == '/auth/me') {
    body = _userJson;
  } else if (path == '/tasks') {
    body = _tasksJson;
  } else {
    status = 404;
  }
  return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});
});

class _Size {
  final String name;
  final Size size;
  const _Size(this.name, this.size);
}

const _sizes = [
  _Size('celular pequeno', Size(320, 568)),
  _Size('celular comum', Size(360, 760)),
  _Size('celular deitado', Size(760, 360)),
  _Size('tablet', Size(1024, 1366)),
];

void main() {
  final tasks = _tasksJson.map(Task.fromJson).toList();
  final user = User.fromJson(_userJson);

  final screens = <String, Widget Function()>{
    'login': () => const LoginScreen(),
    'cadastro': () => const RegisterScreen(),
    'tarefas': () => const TasksScreen(),
    'nova tarefa': () => const TaskFormScreen(),
    'editar tarefa': () => TaskFormScreen(task: tasks[3]),
    'calendário': () => const CalendarScreen(),
    'estatísticas': () => StatsScreen(tasks: tasks),
    'conquistas': () => AchievementsScreen(tasks: tasks),
    'perfil': () => ProfileScreen(user: user, tasks: tasks),
    'foco': () => FocusScreen(task: tasks[1]),
  };

  setUp(() => SharedPreferences.setMockInitialValues({'access_token': 'token-de-teste'}));

  for (final entry in screens.entries) {
    for (final s in _sizes) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${entry.key} — ${s.name} — fonte ${scale}x', (tester) async {
          tester.view.physicalSize = s.size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await http.runWithClient(() async {
            await tester.pumpWidget(
              MaterialApp(
                theme: buildTheme(Brightness.light),
                locale: const Locale('pt', 'BR'),
                supportedLocales: const [Locale('pt', 'BR')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: entry.value(),
              ),
            );
            // Deixa as requisições (falsas) terminarem e a tela se redesenhar
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
            await tester.pump(const Duration(milliseconds: 500));
          }, () => _mockApi);

          expect(tester.takeException(), isNull);
          // Desmonta antes do fim do teste (a tela de foco tem um cronômetro)
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
