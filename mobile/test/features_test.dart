import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarefas_app/models/task.dart';
import 'package:tarefas_app/screens/focus_screen.dart';
import 'package:tarefas_app/utils/achievements.dart';
import 'package:tarefas_app/utils/dates.dart';
import 'package:tarefas_app/utils/quick_add.dart';

/// Cria uma tarefa de teste; [completedDaysAgo] = há quantos dias foi concluída (null = pendente).
Task fakeTask(int id, {int? completedDaysAgo, int focus = 0, String category = 'outros'}) => Task.fromJson({
  'id': id,
  'title': 'T$id',
  'done': completedDaysAgo != null,
  'priority': 'media',
  'category': category,
  'focus_minutes': focus,
  'completed_at': completedDaysAgo == null
      ? null
      : DateTime.now().subtract(Duration(days: completedDaysAgo)).toUtc().toIso8601String(),
  'created_at': '2026-01-01T10:00:00Z',
});

void main() {
  group('Criação rápida', () {
    test('entende prioridade, categoria e "amanhã"', () {
      final data = parseQuickAdd('Prova de BD amanhã !alta #faculdade');
      expect(data['title'], 'Prova de BD');
      expect(data['priority'], 'alta');
      expect(data['category'], 'faculdade');
      expect(data['due_date'], toApiDate(today().add(const Duration(days: 1))));
    });

    test('aceita acentos e maiúsculas, e data no formato dd/mm', () {
      final data = parseQuickAdd('Consulta #Saúde !MÉDIA 25/12');
      expect(data['title'], 'Consulta');
      expect(data['category'], 'saude');
      expect(data['priority'], 'media');
      expect((data['due_date'] as String).endsWith('-12-25'), isTrue);
    });

    test('sem atalhos usa os padrões e não inventa data', () {
      final data = parseQuickAdd('Ler um livro');
      expect(data, {'title': 'Ler um livro', 'priority': 'media', 'category': 'outros', 'due_date': null});
    });
  });

  group('Conquistas', () {
    test('sequência conta dias seguidos até hoje', () {
      final tasks = [
        fakeTask(1, completedDaysAgo: 0),
        fakeTask(2, completedDaysAgo: 1),
        fakeTask(3, completedDaysAgo: 2),
      ];
      expect(currentStreak(tasks), 3);
      // Um buraco de um dia quebra a sequência
      expect(currentStreak([fakeTask(1, completedDaysAgo: 0), fakeTask(2, completedDaysAgo: 2)]), 1);
      expect(currentStreak([fakeTask(1)]), 0);
    });

    test('medalhas desbloqueiam ao atingir a meta', () {
      final tasks = [
        fakeTask(1, completedDaysAgo: 0, focus: 60, category: 'casa'),
        fakeTask(2, category: 'faculdade'),
        fakeTask(3, category: 'saude'),
      ];
      final byTitle = {for (final a in buildAchievements(tasks)) a.title: a};
      expect(byTitle['Primeiro passo']!.unlocked, isTrue);
      expect(byTitle['Focado']!.unlocked, isTrue);
      expect(byTitle['Organizado']!.unlocked, isTrue);
      expect(byTitle['Produtivo']!.unlocked, isFalse);
      expect(byTitle['Produtivo']!.progress, closeTo(0.1, 0.001));
    });
  });

  testWidgets('Modo foco: relógio começa em 25:00 e anda ao dar play', (tester) async {
    await tester.pumpWidget(MaterialApp(home: FocusScreen(task: fakeTask(1))));
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('15 min'));
    await tester.pump();
    expect(find.text('15:00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('14:57'), findsOneWidget);

    // Pausa e sai da tela (o timer precisa ser cancelado no dispose)
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpWidget(const SizedBox());
  });
}
