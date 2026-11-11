import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';

/// Janela para trocar o nome (PUT /auth/me). Retorna o usuário atualizado, ou null se cancelar.
Future<User?> showEditNameDialog(BuildContext context, String currentName) =>
    showDialog<User>(context: context, builder: (_) => _EditNameDialog(currentName));

/// Janela para trocar a senha (PUT /auth/password). Retorna true se a senha foi alterada.
Future<bool?> showChangePasswordDialog(BuildContext context) =>
    showDialog<bool>(context: context, builder: (_) => const _ChangePasswordDialog());

/// Base comum das duas janelas: formulário, botão com "carregando" e erro da API.
/// Cada janela só informa os campos ([fields]) e o que fazer ao salvar ([onSave]).
class _FormDialog extends StatefulWidget {
  final String title;
  final List<Widget> fields;
  final Future<Object?> Function() onSave; // o valor retornado é devolvido para quem abriu a janela
  const _FormDialog({required this.title, required this.fields, required this.onSave});

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.onSave();
      if (mounted) Navigator.pop(context, result);
    } on ApiException catch (e) {
      // O erro aparece dentro da própria janela (ex.: "A senha atual está incorreta.")
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.fields,
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String currentName;
  const _EditNameDialog(this.currentName);

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _name = TextEditingController(text: widget.currentName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: 'Editar nome',
      onSave: () => api.updateName(_name.text.trim()),
      fields: [
        TextFormField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome'),
          validator: (v) => (v == null || v.trim().length < 2) ? 'Mínimo de 2 caracteres' : null,
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: 'Alterar senha',
      onSave: () async {
        await api.changePassword(_current.text, _new.text);
        return true;
      },
      fields: [
        TextFormField(
          controller: _current,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Senha atual'),
          validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha atual' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _new,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nova senha'),
          validator: (v) => (v == null || v.length < 6 || v.length > 72) ? 'Entre 6 e 72 caracteres' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
          validator: (v) => v != _new.text ? 'As senhas não conferem' : null,
        ),
      ],
    );
  }
}
