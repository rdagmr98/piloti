class UserProfile {
  final String id;
  final String nome;
  final String cognome;
  final String? email;
  final String? username;
  final String role;
  final DateTime? fitnessExpiry;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.nome,
    required this.cognome,
    this.email,
    this.username,
    required this.role,
    this.fitnessExpiry,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == 'admin';
  String get fullName => '$cognome $nome'.trim();

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] as String,
    nome: j['nome'] as String? ?? '',
    cognome: j['cognome'] as String? ?? '',
    email: j['email'] as String?,
    username: j['username'] as String?,
    role: j['role'] as String? ?? 'user',
    fitnessExpiry: j['fitness_expiry'] != null
        ? DateTime.parse(j['fitness_expiry'] as String)
        : null,
    isActive: j['is_active'] as bool? ?? true,
    createdAt: DateTime.parse(
      j['created_at'] as String? ?? DateTime.now().toIso8601String(),
    ),
    updatedAt: DateTime.parse(
      j['updated_at'] as String? ?? DateTime.now().toIso8601String(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'cognome': cognome,
    'email': email,
    'username': username,
    'role': role,
    'fitness_expiry': fitnessExpiry?.toIso8601String().split('T').first,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  static const Object _s = Object();

  UserProfile copyWith({
    String? nome,
    String? cognome,
    String? email,
    String? username,
    String? role,
    Object? fitnessExpiry = _s,
    bool? isActive,
  }) => UserProfile(
    id: id,
    nome: nome ?? this.nome,
    cognome: cognome ?? this.cognome,
    email: email ?? this.email,
    username: username ?? this.username,
    role: role ?? this.role,
    fitnessExpiry: identical(fitnessExpiry, _s)
        ? this.fitnessExpiry
        : fitnessExpiry as DateTime?,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
