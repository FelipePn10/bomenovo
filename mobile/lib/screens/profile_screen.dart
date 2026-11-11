import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/account_dialogs.dart';
import '../widgets/feedback.dart';
import '../widgets/responsive_center.dart';
import '../widgets/server_dialog.dart';
import 'achievements_screen.dart';
import 'login_screen.dart';

/// Perfil do usuário: dados da conta, estatísticas e configurações do app.
/// Recebe o usuário e as tarefas da tela anterior, então não precisa chamar a API de novo.
class ProfileScreen extends StatefulWidget {
  final User user;
  final List<Task> tasks;
  const ProfileScreen({super.key, required this.user, required this.tasks});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Cópia local: muda quando o usuário edita o nome, sem precisar recarregar a tela
  late User _user = widget.user;

  Future<void> _editName() async {
    final updated = await showEditNameDialog(context, _user.name);
    if (updated == null || !mounted) return;
    setState(() => _user = updated);
    showFeedback(context, 'Nome atualizado', type: FeedbackType.success);
  }

  Future<void> _changePassword() async {
    final changed = await showChangePasswordDialog(context);
    if (changed == true && mounted) {
      showFeedback(context, 'Senha alterada com sucesso', type: FeedbackType.success);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sair da conta?',
      message: 'Você precisará entrar novamente com e-mail e senha.',
      icon: Icons.logout,
      confirmLabel: 'Sair',
      destructive: true,
    );
    if (ok && mounted) logoutAndGoToLogin(context);
  }

  Future<void> _changeServer() async {
    await showServerDialog(context);
    setState(() {}); // mostra o novo endereço
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final user = _user;
    final done = widget.tasks.where((t) => t.done).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          maxWidth: 600,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: colors.primaryContainer,
                child: Text(user.initials, style: text.headlineMedium?.copyWith(color: colors.onPrimaryContainer)),
              ),
              const SizedBox(height: 12),
              Text(user.name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(user.email, style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('Conta criada em ${formatDate(user.createdAt)}', style: text.bodySmall),
              const SizedBox(height: 24),

              Row(
                children: [
                  _StatCard(label: 'Total', value: widget.tasks.length, color: colors.primary),
                  const SizedBox(width: 12),
                  _StatCard(label: 'Concluídas', value: done, color: Colors.green),
                  const SizedBox(width: 12),
                  _StatCard(label: 'Pendentes', value: widget.tasks.length - done, color: Colors.orange),
                ],
              ),
              const SizedBox(height: 24),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.emoji_events_outlined),
                      title: const Text('Conquistas'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => AchievementsScreen(tasks: widget.tasks))),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Editar nome'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _editName,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.password),
                      title: const Text('Alterar senha'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePassword,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    // Seletor de tema ocupa a largura toda do card (não quebra linha em telas pequenas)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.palette_outlined), SizedBox(width: 16), Text('Tema')]),
                          const SizedBox(height: 12),
                          // Escuta o tema atual para marcar a opção certa
                          ValueListenableBuilder(
                            valueListenable: themeMode,
                            builder: (context, mode, _) => SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<ThemeMode>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    icon: Icon(Icons.light_mode),
                                    label: Text('Claro'),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    icon: Icon(Icons.dark_mode),
                                    label: Text('Escuro'),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    icon: Icon(Icons.phone_android),
                                    label: Text('Auto'),
                                  ),
                                ],
                                selected: {mode},
                                onSelectionChanged: (s) => changeThemeMode(s.first),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.dns_outlined),
                      title: const Text('Servidor da API'),
                      subtitle: Text(api.baseUrl),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changeServer,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Sobre o app'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'Minhas Tarefas',
                        applicationVersion: '1.3.0',
                        applicationIcon: const Icon(Icons.task_alt_rounded, size: 40),
                        children: const [Text('Gerenciador de tarefas feito em Flutter, consumindo uma API FastAPI.')],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error),
                    minimumSize: const Size(64, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair da conta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
