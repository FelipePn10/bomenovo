/// Usuário logado (resposta de GET /auth/me).
class User {
  final String name;
  final String email;
  final DateTime createdAt;

  User({required this.name, required this.email, required this.createdAt});

  factory User.fromJson(Map<String, dynamic> json) =>
      User(name: json['name'], email: json['email'], createdAt: DateTime.parse(json['created_at']).toLocal());

  String get firstName => name.trim().split(' ').first;

  /// "Maria Silva" -> "MS" (usado no avatar)
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.isEmpty ? '?' : parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}
