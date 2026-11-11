import '../models/task.dart';
import 'dates.dart';

/// Criação rápida: transforma uma frase em uma tarefa.
///
/// Atalhos reconhecidos (podem estar em qualquer posição):
///   !alta  !media  !baixa        -> prioridade
///   #faculdade  #casa  #saude... -> categoria
///   hoje  amanhã                 -> data limite
///   25/12                        -> data limite (dia/mês)
/// O que sobra vira o título. Ex.: "Prova de BD amanhã !alta #faculdade"
Map<String, dynamic> parseQuickAdd(String input) {
  Priority? priority;
  Category? category;
  DateTime? due;
  final titleWords = <String>[];

  for (final word in input.trim().split(RegExp(r'\s+'))) {
    final key = _normalize(word);
    final date = RegExp(r'^(\d{1,2})/(\d{1,2})$').firstMatch(word);

    if (key.startsWith('!') && _find(Priority.values, key.substring(1)) != null) {
      priority = _find(Priority.values, key.substring(1));
    } else if (key.startsWith('#') && _find(Category.values, key.substring(1)) != null) {
      category = _find(Category.values, key.substring(1));
    } else if (key == 'hoje') {
      due = today();
    } else if (key == 'amanha') {
      due = today().add(const Duration(days: 1));
    } else if (date != null) {
      due = _nextOccurrence(int.parse(date.group(1)!), int.parse(date.group(2)!));
    } else {
      titleWords.add(word);
    }
  }

  return {
    'title': titleWords.join(' '),
    'priority': (priority ?? Priority.media).name,
    'category': (category ?? Category.outros).name,
    'due_date': due == null ? null : toApiDate(due),
  };
}

/// Procura no enum pelo nome ("alta" -> Priority.alta).
T? _find<T extends Enum>(List<T> values, String name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Minúsculas e sem acento, para "Amanhã", "#Saúde" e "!MÉDIA" funcionarem.
String _normalize(String text) {
  const accents = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'ê': 'e',
    'í': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ç': 'c',
  };
  return text.toLowerCase().split('').map((c) => accents[c] ?? c).join();
}

/// "25/12" vira a próxima vez que esse dia acontece (este ano ou o próximo).
DateTime _nextOccurrence(int day, int month) {
  final thisYear = DateTime(today().year, month, day);
  return thisYear.isBefore(today()) ? DateTime(today().year + 1, month, day) : thisYear;
}
