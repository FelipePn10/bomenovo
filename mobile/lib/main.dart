import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login_screen.dart';
import 'screens/tasks_screen.dart';
import 'services/api_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carrega o que ficou salvo no aparelho: token, endereço da API e tema
  final loggedIn = await api.init();
  await loadThemeMode();
  runApp(TarefasApp(loggedIn: loggedIn));
}

class TarefasApp extends StatelessWidget {
  final bool loggedIn;
  const TarefasApp({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    // Redesenha o app inteiro quando o usuário troca entre claro/escuro
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Minhas Tarefas',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        // Português: deixa o calendário (showDatePicker) e os textos padrão em pt-BR
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: loggedIn ? const TasksScreen() : const LoginScreen(),
      ),
    );
  }
}
