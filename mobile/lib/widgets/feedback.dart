import 'package:flutter/material.dart';

import '../theme.dart';

/// Tipos de aviso. Cada um tem cor e ícone próprios, assim o usuário entende
/// o resultado da ação mesmo sem ler a mensagem inteira.
enum FeedbackType {
  success(Icons.check_circle_rounded, Color(0xFF15803D)),
  info(Icons.info_rounded, Color(0xFF4338CA)),
  warning(Icons.warning_amber_rounded, Color(0xFFB45309)),
  error(Icons.error_rounded, Color(0xFFB91C1C));

  const FeedbackType(this.icon, this.color);
  final IconData icon;
  final Color color;
}

/// Monta o SnackBar estilizado. Separado do [showFeedback] para poder ser usado
/// com um ScaffoldMessenger guardado antes de trocar de tela (ex.: no logout).
SnackBar buildFeedback(String message, {FeedbackType type = FeedbackType.info, SnackBarAction? action}) {
  return SnackBar(
    backgroundColor: type.color,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    duration: Duration(seconds: action == null ? 3 : 5), // com "Desfazer", dá mais tempo para tocar
    content: Row(
      children: [
        Icon(type.icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
    action: action,
  );
}

/// Mostra um aviso no rodapé, substituindo o anterior (evita fila de avisos).
void showFeedback(
  BuildContext context,
  String message, {
  FeedbackType type = FeedbackType.info,
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(buildFeedback(message, type: type, action: action));
}

/// Janela de confirmação padrão do app. Retorna true se o usuário confirmar.
/// [destructive] deixa o botão vermelho (ações que apagam dados).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final colors = Theme.of(context).colorScheme;
  final accent = destructive ? colors.error : colors.primary;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone dentro de um círculo com a cor da ação
              CircleAvatar(
                radius: 32,
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(icon, size: 32, color: accent),
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: accent, minimumSize: const Size(0, 48)),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false; // fechar tocando fora conta como "Cancelar"
}

/// Comemoração mostrada quando o usuário conclui a última tarefa pendente.
Future<void> showAllDoneDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: const BoxDecoration(gradient: appGradient),
              child: const Icon(Icons.celebration_rounded, size: 64, color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text('Tudo em dia!', style: Theme.of(ctx).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Você concluiu todas as suas tarefas. Aproveite o descanso!', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Valeu!')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
