import '../models/reference_models.dart';
import '../models/user_models.dart';
import 'gh_db_service.dart';

class UserService {
  final _db = GhDbService();

  List<Map<String, dynamic>> _refList(String key) =>
      List<Map<String, dynamic>>.from(
        (_db.referenceData[key] as List<dynamic>? ?? const []),
      );

  Map<String, dynamic>? _findRef(String key, int? id) {
    if (id == null) return null;
    for (final item in _refList(key)) {
      if ('${item['id']}' == '$id') return Map<String, dynamic>.from(item);
    }
    return null;
  }

  List<UserProfile> getAllUsers() {
    final users = _db.users
        .map(UserProfile.fromJson)
        .where((u) => u.isActive)
        .toList();
    users.sort((a, b) => a.fullName.compareTo(b.fullName));
    return users;
  }

  UserProfile? findByUsername(String username) {
    for (final raw in _db.users) {
      if ((raw['username'] as String?)?.toLowerCase() ==
          username.toLowerCase()) {
        return UserProfile.fromJson(raw);
      }
    }
    return null;
  }

  UserProfile? findById(String id) {
    for (final raw in _db.users) {
      if (raw['id'] == id) return UserProfile.fromJson(raw);
    }
    return null;
  }

  List<AircraftType> getAircraftTypes() {
    final items = _refList('aircraftTypes')
        .where((e) => e['active'] != false)
        .map(AircraftType.fromJson)
        .toList();
    items.sort((a, b) => a.code.compareTo(b.code));
    return items;
  }

  List<CapabilityType> getCapabilityTypes() {
    return _refList('capabilityTypes').map(CapabilityType.fromJson).toList();
  }

  Future<void> updateFitnessExpiry(String userId, DateTime? expiry) async {
    final users = _db.users.toList();
    final idx = users.indexWhere((u) => u['id'] == userId);
    if (idx < 0) return;
    users[idx] = {
      ...users[idx],
      'fitness_expiry': expiry?.toIso8601String().split('T').first,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveUsers(users);
  }

  Future<UserProfile> createUser({
    required String nome,
    required String cognome,
    required String username,
    required String password,
    String? email,
  }) async {
    final users = _db.users.toList();
    final now = DateTime.now().toIso8601String();
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final hash = GhDbService.hashPassword(password);
    final newUser = {
      'id': id,
      'nome': nome,
      'cognome': cognome,
      'email': email,
      'username': username,
      'password_hash': hash,
      'role': 'user',
      'fitness_expiry': null,
      'is_active': true,
      'created_at': now,
      'updated_at': now,
    };
    users.add(newUser);
    await _db.saveUsers(users);
    return UserProfile.fromJson(newUser);
  }

  Future<void> updateUser(UserProfile updated) async {
    final users = _db.users.toList();
    final idx = users.indexWhere((u) => u['id'] == updated.id);
    if (idx < 0) return;
    users[idx] = {
      ...users[idx],
      ...updated.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveUsers(users);
  }
}
