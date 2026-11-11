import 'dart:async';

import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/api_service.dart';
import '../utils/dates.dart';
import '../widgets/feedback.dart';
import '../widgets/responsive_center.dart';

/// Modo Foco (técnica Pomodoro): ciclos de foco seguidos de uma pausa curta.
/// Ao terminar um ciclo de foco, os minutos são somados na tarefa pela API.
class FocusScreen extends StatefulWidget {
  final Task task;
  const FocusScreen({super.key, required this.task});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const _breakMinutes = 5;

  int _focusMinutes = 25; // duração escolhida (15, 25 ou 50)
  bool _onBreak = false; // false = foco, true = pausa
  late int _secondsLeft = _focusMinutes * 60;
  Timer? _timer; // null = parado
  int _sessions = 0; // ciclos de foco concluídos nesta tela
  late int _totalFocus = widget.task.focusMinutes;

  bool get _running => _timer != null;
  int get _phaseSeconds => (_onBreak ? _breakMinutes : _focusMinutes) * 60;

  @override
  void dispose() {
    _timer?.cancel(); // sem isso o timer continuaria rodando depois de sair da tela
    super.dispose();
  }

  void _start() {
    // Timer.periodic chama _tick a cada 1 segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _timer = null);
  }

  void _tick() {
    if (_secondsLeft > 1) {
      setState(() => _secondsLeft--);
    } else {
      _finishPhase();
    }
  }

  /// Fim de uma fase: foco -> salva os minutos e começa a pausa; pausa -> volta ao foco.
  Future<void> _finishPhase() async {
    _pause();
    if (!_onBreak) {
      _sessions++;
      try {
        final updated = await api.addFocus(widget.task.id, _focusMinutes);
        _totalFocus = updated.focusMinutes;
        if (mounted) {
          showFeedback(context, 'Ciclo concluído! +$_focusMinutes min de foco', type: FeedbackType.success);
        }
      } on ApiException catch (e) {
        if (mounted) showFeedback(context, e.message, type: FeedbackType.error);
      }
    } else if (mounted) {
      showFeedback(context, 'Pausa encerrada. Bora para o próximo ciclo!');
    }
    _switchPhase();
  }

  /// Troca entre foco e pausa e reinicia o relógio.
  void _switchPhase() {
    _pause();
    setState(() {
      _onBreak = !_onBreak;
      _secondsLeft = _phaseSeconds;
    });
  }

  void _reset() {
    _pause();
    setState(() => _secondsLeft = _phaseSeconds);
  }

  void _chooseDuration(int minutes) {
    setState(() {
      _focusMinutes = minutes;
      _secondsLeft = minutes * 60;
    });
  }

  /// 1500 segundos -> "25:00"
  String get _clock {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Foco usa a cor principal; pausa usa verde
    final phaseColor = _onBreak ? const Color(0xFF16A34A) : colors.primary;
    final canChooseDuration = !_running && !_onBreak && _secondsLeft == _phaseSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('Modo foco')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          maxWidth: 480,
          child: Column(
            children: [
              Text(widget.task.title, style: text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Chip(
                avatar: Icon(_onBreak ? Icons.coffee : Icons.psychology, color: phaseColor),
                label: Text(_onBreak ? 'Pausa de $_breakMinutes min' : 'Hora de focar'),
              ),
              const SizedBox(height: 24),
              // Relógio circular: o anel vai se completando conforme o tempo passa
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1 - _secondsLeft / _phaseSeconds,
                      strokeWidth: 14,
                      strokeCap: StrokeCap.round,
                      color: phaseColor,
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                    Center(
                      child: Text(
                        _clock,
                        style: text.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: phaseColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // A duração só pode ser trocada antes de começar
              if (canChooseDuration)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final minutes in [15, 25, 50])
                      ChoiceChip(
                        label: Text('$minutes min'),
                        selected: _focusMinutes == minutes,
                        onSelected: (_) => _chooseDuration(minutes),
                      ),
                  ],
                )
              else
                const SizedBox(height: 32),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    iconSize: 28,
                    tooltip: 'Reiniciar',
                    onPressed: _reset,
                    icon: const Icon(Icons.replay),
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton.large(
                    heroTag: null,
                    backgroundColor: phaseColor,
                    foregroundColor: Colors.white,
                    onPressed: _running ? _pause : _start,
                    child: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 48),
                  ),
                  const SizedBox(width: 24),
                  IconButton.filledTonal(
                    iconSize: 28,
                    tooltip: _onBreak ? 'Pular pausa' : 'Pular para a pausa',
                    onPressed: _switchPhase,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  // Expanded: cada informação fica com metade da largura e o texto quebra a linha
                  // em telas estreitas em vez de estourar para fora do card
                  child: Row(
                    children: [
                      Expanded(
                        child: _Info(value: '$_sessions', label: 'Ciclos agora'),
                      ),
                      Expanded(
                        child: _Info(value: formatMinutes(_totalFocus), label: 'Total nesta tarefa'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String value;
  final String label;
  const _Info({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
