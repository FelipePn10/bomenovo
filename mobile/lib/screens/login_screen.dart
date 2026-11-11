import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/responsive_center.dart';
import '../widgets/server_dialog.dart';
import 'register_screen.dart';
import 'tasks_screen.dart';

/// Tela de login: envia e-mail e senha para POST /auth/login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  Future<void> _submit() async {
    // validate() roda os "validator" de cada campo e mostra os erros
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await api.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      // pushReplacement: o botão voltar não retorna para o login
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TasksScreen()));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openServerDialog() async {
    await showServerDialog(context);
    setState(() {}); // atualiza o endereço mostrado no rodapé
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: 420,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  const AppLogo(title: 'Minhas Tarefas', subtitle: 'Entre para organizar o seu dia'),
                  const SizedBox(height: 40),
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
                      suffixIcon: IconButton(
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Entrar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('Não tem conta? Cadastre-se'),
                  ),
                  const SizedBox(height: 24),
                  // Permite apontar o app para outra API (IP do computador ou servidor online)
                  TextButton.icon(
                    onPressed: _openServerDialog,
                    icon: const Icon(Icons.dns_outlined, size: 18),
                    label: Text('Servidor: ${api.baseUrl}', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sai da conta e volta para o login, limpando a pilha de telas.
/// Usada no botão "Sair" e quando a API responde 401 (token expirado).
Future<void> logoutAndGoToLogin(BuildContext context, {String? message}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await api.logout();
  if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
}
