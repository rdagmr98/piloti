class UserProfile {
  final String id;
  final String nome;
  final String cognome;
  final String? callsign;
  final String? email;
  final String? username;
  final String role;
  final int? orgUnitId;
  final String orgUnitName;
  final List<int> aircraftQualificationIds;
  final DateTime? fitnessExpiry;
  final bool isActive;
  final bool isApproved;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.nome,
    required this.cognome,
    this.callsign,
    this.email,
    this.username,
    required this.role,
    this.orgUnitId,
    this.orgUnitName = '',
    this.aircraftQualificationIds = const [],
    this.fitnessExpiry,
    this.isActive = true,
    this.isApproved = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == 'admin';
  String get fullName => '$cognome $nome'.trim();
  String get displayName =>
      callsign != null && callsign!.isNotEmpty ? callsign! : fullName;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] as String,
    nome: j['nome'] as String? ?? '',
    cognome: j['cognome'] as String? ?? '',
    callsign: j['callsign'] as String?,
    email: j['email'] as String?,
    username: j['username'] as String?,
    role: j['role'] as String? ?? 'user',
    orgUnitId: j['org_unit_id'] as int?,
    orgUnitName: j['org_unit_name'] as String? ?? '',
    aircraftQualificationIds: List<int>.from(
      (j['aircraft_qualification_ids'] as List? ?? []).map((e) => e as int),
    ),
    fitnessExpiry: j['fitness_expiry'] != null
        ? DateTime.parse(j['fitness_expiry'] as String)
        : null,
    isActive: j['is_active'] as bool? ?? true,
    isApproved: j['is_approved'] as bool? ?? false,
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
    'callsign': callsign,
    'email': email,
    'username': username,
    'role': role,
    'org_unit_id': orgUnitId,
    'org_unit_name': orgUnitName,
    'aircraft_qualification_ids': aircraftQualificationIds,
    'fitness_expiry': fitnessExpiry?.toIso8601String().split('T').first,
    'is_active': isActive,
    'is_approved': isApproved,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  static const Object _s = Object();

  UserProfile copyWith({
    String? nome,
    String? cognome,
    Object? callsign = _s,
    Object? email = _s,
    String? username,
    String? role,
    Object? orgUnitId = _s,
    String? orgUnitName,
    List<int>? aircraftQualificationIds,
    Object? fitnessExpiry = _s,
    bool? isActive,
    bool? isApproved,
  }) => UserProfile(
    id: id,
    nome: nome ?? this.nome,
    cognome: cognome ?? this.cognome,
    callsign: identical(callsign, _s) ? this.callsign : callsign as String?,
    email: identical(email, _s) ? this.email : email as String?,
    username: username ?? this.username,
    role: role ?? this.role,
    orgUnitId: identical(orgUnitId, _s) ? this.orgUnitId : orgUnitId as int?,
    orgUnitName: orgUnitName ?? this.orgUnitName,
    aircraftQualificationIds:
        aircraftQualificationIds ?? this.aircraftQualificationIds,
    fitnessExpiry: identical(fitnessExpiry, _s)
        ? this.fitnessExpiry
        : fitnessExpiry as DateTime?,
    isActive: isActive ?? this.isActive,
    isApproved: isApproved ?? this.isApproved,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
