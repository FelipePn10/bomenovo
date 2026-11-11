import 'package:flutter/material.dart';

import '../config.dart';
import '../services/api_service.dart';

/// Abre a janela para trocar o endereço da API.
/// Útil no celular físico: lá "localhost" não funciona, então é preciso
/// informar o IP do computador (ex.: http://192.168.0.10:8000) ou a URL da API hospedada.
Future<void> showServerDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _ServerDialog());

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _url = TextEditingController(text: api.baseUrl);
  bool _testing = false;
  bool? _online; // null = ainda não testou

  Future<void> _test() async {
    setState(() => _testing = true);
    final ok = await api.ping(_url.text.trim());
    if (!mounted) return;
    setState(() {
      _testing = false;
      _online = ok;
    });
  }

  Future<void> _save([String? url]) async {
    await api.setBaseUrl(url);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Servidor da API'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Endereço', hintText: 'http://192.168.0.10:8000'),
            onChanged: (_) => setState(() => _online = null),
          ),
          const SizedBox(height: 8),
          Text('Padrão: $defaultApiUrl', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _testing ? null : _test,
                icon: _testing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering),
                label: const Text('Testar'),
              ),
              const SizedBox(width: 12),
              if (_online != null)
                Expanded(
                  child: Text(
                    _online! ? 'API respondendo' : 'Sem resposta',
                    style: TextStyle(color: _online! ? Colors.green : Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => _save(null), child: const Text('Usar padrão')),
        FilledButton(onPressed: () => _save(_url.text), child: const Text('Salvar')),
      ],
    );
  }
}
