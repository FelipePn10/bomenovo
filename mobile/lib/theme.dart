import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cor principal do app. O Material 3 gera o resto da paleta a partir dela.
const _seedColor = Color(0xFF4F46E5);

/// Degradê usado no logo e no card de progresso (igual no tema claro e no escuro).
const appGradient = LinearGradient(
  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Monta o tema claro ou escuro com o mesmo estilo (cantos arredondados, campos preenchidos etc.).
ThemeData buildTheme(Brightness brightness) {
  // "fidelity" mantém a cor principal fiel ao seed (sem ela o roxo fica apagado)
  final scheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final radius = BorderRadius.circular(14);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLow,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLow,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

// ---------- Modo claro / escuro ----------

const _themeKey = 'theme_mode';

/// Guarda o tema escolhido. O MaterialApp "escuta" essa variável e se redesenha quando ela muda.
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_themeKey);
  themeMode.value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
}

Future<void> changeThemeMode(ThemeMode mode) async {
  themeMode.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_themeKey, mode.name);
}
