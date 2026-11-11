import 'package:flutter/foundation.dart';

/// Endereço padrão da API FastAPI (o usuário pode trocar dentro do app, na tela de login ou no perfil).
///
/// Pode ser definido na hora de compilar:
///   flutter build apk --dart-define=API_URL=https://minha-api.onrender.com
/// Sem isso, usa:
///  - Emulador Android: 10.0.2.2, que aponta para o "localhost" do computador.
///  - Web / Desktop: localhost.
String get defaultApiUrl {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}
