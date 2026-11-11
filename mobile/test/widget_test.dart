import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarefas_app/main.dart';
import 'package:tarefas_app/models/task.dart';
import 'package:tarefas_app/screens/stats_screen.dart';
import 'package:tarefas_app/utils/dates.dart';

void main() {
  // Simula o armazenamento do aparelho durante os testes
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Sem token, o app abre na tela de login', (tester) async {
    await tester.pumpWidget(const TarefasApp(loggedIn: false));
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Não tem conta? Cadastre-se'), findsOneWidget);
  });

  testWidgets('Login valida os campos antes de chamar a API', (tester) async {
    await tester.pumpWidget(const TarefasApp(loggedIn: false));
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);
  });

  testWidgets('Cadastro confere se as senhas são iguais', (tester) async {
    await tester.pumpWidget(const TarefasApp(loggedIn: false));
    await tester.tap(find.text('Não tem conta? Cadastre-se'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'senha123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar senha'), 'outra123');
    await tester.ensureVisible(find.text('Cadastrar'));
    await tester.tap(find.text('Cadastrar'));
    await tester.pump();
    expect(find.text('As senhas não conferem'), findsOneWidget);
  });

  test('Task.fromJson lê prioridade e data limite', () {
    final task = Task.fromJson({
      'id': 1,
      'title': 'Prova',
      'description': null,
      'done': false,
      'priority': 'alta',
      'due_date': '2000-01-10',
      'created_at': '2026-01-01T10:00:00Z',
    });
    expect(task.priority, Priority.alta);
    expect(task.isOverdue, isTrue); // data no passado e não concluída
  });

  test('Datas: formato da API, formato brasileiro e rótulos', () {
    expect(toApiDate(DateTime(2026, 3, 5)), '2026-03-05');
    expect(formatDate(DateTime(2026, 3, 5)), '05/03/2026');
    expect(dueDateLabel(today()), 'Hoje');
    expect(dueDateLabel(today().add(const Duration(days: 1))), 'Amanhã');
    expect(dueDateLabel(today().subtract(const Duration(days: 3))), 'Atrasada há 3 dias');
  });

  test('Task.toJson gera o corpo aceito pela API (usado no desfazer/duplicar)', () {
    final task = Task.fromJson({
      'id': 7,
      'title': 'TCC',
      'description': 'Capítulo 2',
      'done': false,
      'priority': 'media',
      'category': 'faculdade',
      'due_date': '2026-12-01',
      'created_at': '2026-11-01T10:00:00',
    });
    expect(task.category, Category.faculdade);
    expect(task.toJson(), {
      'title': 'TCC',
      'description': 'Capítulo 2',
      'done': false,
      'priority': 'media',
      'category': 'faculdade',
      'due_date': '2026-12-01',
    });
  });

  test('Data sem fuso vinda do SQLite é tratada como UTC', () {
    expect(parseApiDateTime('2026-11-11T12:00:00'), DateTime.utc(2026, 11, 11, 12).toLocal());
    expect(parseApiDateTime('2026-11-11T12:00:00+00:00'), DateTime.utc(2026, 11, 11, 12).toLocal());
  });

  testWidgets('Estatísticas mostram a taxa de conclusão', (tester) async {
    Task task(int id, bool done) => Task.fromJson({
      'id': id,
      'title': 'T$id',
      'done': done,
      'priority': 'alta',
      'category': 'casa',
      'completed_at': done ? DateTime.now().toUtc().toIso8601String() : null,
      'created_at': '2026-11-01T10:00:00Z',
    });
    await tester.pumpWidget(MaterialApp(home: StatsScreen(tasks: [task(1, true), task(2, false)])));
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Concluídas nos últimos 7 dias'), findsOneWidget);
  });
}
