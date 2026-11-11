import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/responsive_center.dart';
import 'tasks_screen.dart';

/// Tela de cadastro: cria a conta (POST /auth/register) e já faz o login.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final email = _email.text.trim();
      await api.register(_name.text.trim(), email, _password.text);
      await api.login(email, _password.text); // evita o usuário digitar tudo de novo
      messenger.showSnackBar(const SnackBar(content: Text('Conta criada! Bem-vindo(a).')));
      if (!mounted) return;
      // Remove login e cadastro da pilha de telas
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const TasksScreen()), (_) => false);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eye = IconButton(
      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
      onPressed: () => setState(() => _showPassword = !_showPassword),
    );

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          maxWidth: 420,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const AppLogo(title: 'Criar conta', subtitle: 'Leva menos de um minuto'),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline)),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Mínimo de 2 caracteres' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: eye,
                  ),
                  textInputAction: TextInputAction.next,
                  // Mesmas regras da API (mínimo 6, máximo 72 por causa do bcrypt)
                  validator: (v) => (v == null || v.length < 6 || v.length > 72) ? 'Entre 6 e 72 caracteres' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: !_showPassword,
                  decoration: const InputDecoration(labelText: 'Confirmar senha', prefixIcon: Icon(Icons.lock_reset)),
                  validator: (v) => v != _password.text ? 'As senhas não conferem' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Cadastrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
