/// Funções simples de data usadas no app (sem depender de pacotes externos).
library;

String _twoDigits(int n) => n.toString().padLeft(2, '0');

/// Remove a hora, deixando só o dia. Facilita comparar datas.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

/// 2026-12-01 -> "01/12/2026"
String formatDate(DateTime d) => '${_twoDigits(d.day)}/${_twoDigits(d.month)}/${d.year}';

/// Formato que a API espera: "2026-12-01"
String toApiDate(DateTime d) => '${d.year}-${_twoDigits(d.month)}-${_twoDigits(d.day)}';

/// Texto amigável para a data limite: "Hoje", "Amanhã", "Atrasada há 3 dias"...
String dueDateLabel(DateTime due) {
  final days = dateOnly(due).difference(today()).inDays;
  if (days == 0) return 'Hoje';
  if (days == 1) return 'Amanhã';
  if (days == -1) return 'Venceu ontem';
  if (days < 0) return 'Atrasada há ${-days} dias';
  if (days < 7) return 'Em $days dias';
  return formatDate(due);
}
