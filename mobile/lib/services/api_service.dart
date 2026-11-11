import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/task.dart';
import '../models/user.dart';

/// Erro vindo da API, com a mensagem amigável enviada pelo backend.
class ApiException implements Exception {
  final int statusCode; // 0 = não chegou a falar com o servidor
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Centraliza todas as chamadas HTTP para o backend FastAPI.
class ApiService {
  static const _tokenKey = 'access_token';
  static const _urlKey = 'api_url';

  // A API gratuita (Render) "dorme" quando fica parada e leva um tempo para acordar
  static const _timeout = Duration(seconds: 60);

  String? _token;
  String baseUrl = defaultApiUrl;

  /// Lê do aparelho o token e o endereço do servidor salvos.
  /// Retorna true se já existe um login (abre o app direto nas tarefas).
  Future<bool> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    baseUrl = prefs.getString(_urlKey) ?? defaultApiUrl;
    return _token != null;
  }

  /// Troca o endereço da API. Passar null volta para o endereço padrão.
  Future<void> setBaseUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      baseUrl = defaultApiUrl;
      await prefs.remove(_urlKey);
    } else {
      // Remove a barra final para não gerar URLs como "...8000//tasks"
      baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
      await prefs.setString(_urlKey, baseUrl);
    }
  }

  /// Testa se existe uma API respondendo no endereço (rota GET /).
  Future<bool> ping(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    // Rotas protegidas exigem o header Authorization: Bearer <token>
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// Executa a requisição e converte qualquer falha em ApiException,
  /// assim as telas só precisam tratar um tipo de erro.
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        0,
        'O servidor demorou para responder. Se a API estiver no plano gratuito, '
        'ela pode estar iniciando: tente de novo em alguns segundos.',
      );
    } catch (_) {
      throw ApiException(0, 'Não foi possível conectar à API em $baseUrl');
    }

    // utf8.decode garante que acentos (ç, ã, é) cheguem corretos
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    var message = 'Erro ${res.statusCode}';
    if (body is Map && body['detail'] is String) {
      message = body['detail'];
      // Erros de validação (422) trazem a lista de campos inválidos
      if (body['errors'] is List && (body['errors'] as List).isNotEmpty) {
        final e = body['errors'][0];
        message += '\n${e['campo']}: ${e['erro']}';
      }
    }
    throw ApiException(res.statusCode, message);
  }

  // ---------- Autenticação ----------

  Future<void> register(String name, String email, String password) => _send(
    () => http.post(
      _uri('/auth/register'),
      headers: _headers,
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    ),
  );

  Future<void> login(String email, String password) async {
    final data = await _send(
      () => http.post(_uri('/auth/login'), headers: _headers, body: jsonEncode({'email': email, 'password': password})),
    );
    // Salva o token no aparelho para não precisar logar toda vez
    _token = data['access_token'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
  }

  Future<User> currentUser() async {
    final data = await _send(() => http.get(_uri('/auth/me'), headers: _headers));
    return User.fromJson(data);
  }

  /// Altera o nome do usuário logado.
  Future<User> updateName(String name) async {
    final data = await _send(() => http.put(_uri('/auth/me'), headers: _headers, body: jsonEncode({'name': name})));
    return User.fromJson(data);
  }

  Future<void> changePassword(String current, String newPassword) => _send(
    () => http.put(
      _uri('/auth/password'),
      headers: _headers,
      body: jsonEncode({'current_password': current, 'new_password': newPassword}),
    ),
  );

  // ---------- CRUD de tarefas ----------

  Future<List<Task>> listTasks() async {
    final data = await _send(() => http.get(_uri('/tasks'), headers: _headers)) as List;
    return data.map((e) => Task.fromJson(e)).toList();
  }

  /// [data] segue o formato da API: title, description, priority, due_date...
  Future<Task> createTask(Map<String, dynamic> data) async {
    final json = await _send(() => http.post(_uri('/tasks'), headers: _headers, body: jsonEncode(data)));
    return Task.fromJson(json);
  }

  /// Atualização parcial: só os campos presentes em [changes] são alterados.
  /// Ex.: updateTask(1, {'done': true})
  Future<Task> updateTask(int id, Map<String, dynamic> changes) async {
    final json = await _send(() => http.put(_uri('/tasks/$id'), headers: _headers, body: jsonEncode(changes)));
    return Task.fromJson(json);
  }

  /// Soma minutos de foco (Pomodoro) na tarefa.
  Future<Task> addFocus(int id, int minutes) async {
    final json = await _send(
      () => http.post(_uri('/tasks/$id/foco'), headers: _headers, body: jsonEncode({'minutes': minutes})),
    );
    return Task.fromJson(json);
  }

  /// Apaga todas as tarefas concluídas de uma vez. Retorna quantas foram apagadas.
  Future<int> deleteCompleted() async {
    final data = await _send(() => http.delete(_uri('/tasks/concluidas'), headers: _headers));
    return data['deleted'];
  }

  Future<void> deleteTask(int id) => _send(() => http.delete(_uri('/tasks/$id'), headers: _headers));
}

/// Instância única usada por todas as telas.
final api = ApiService();
