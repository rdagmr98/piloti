import '../models/reference_models.dart';
import '../models/user_models.dart';
import 'gh_db_service.dart';

class UserService {
  final _db = GhDbService();

  List<Map<String, dynamic>> _refList(String key) =>
      List<Map<String, dynamic>>.from(
        (_db.referenceData[key] as List<dynamic>? ?? const []),
      );

  List<UserProfile> getAllUsers() {
    final users = _db.users.map(UserProfile.fromJson).toList();
    users.sort((a, b) => a.fullName.compareTo(b.fullName));
    return users;
  }

  List<UserProfile> getApprovedPilots() =>
      getAllUsers().where((u) => !u.isAdmin && u.isApproved && u.isActive).toList();

  List<UserProfile> getPendingPilots() =>
      getAllUsers().where((u) => !u.isAdmin && !u.isApproved && u.isActive).toList();

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

  bool usernameExists(String username) =>
      findByUsername(username) != null;

  List<AircraftType> getAircraftTypes() {
    final items = _refList('aircraftTypes')
        .where((e) => e['active'] != false)
        .map(AircraftType.fromJson)
        .toList();
    items.sort((a, b) => a.code.compareTo(b.code));
    return items;
  }

  List<CapabilityType> getCapabilityTypes() {
    final items = _refList('capabilityTypes').map(CapabilityType.fromJson).toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  List<OrgUnit> getOrgUnits() {
    final items = _refList('orgUnits').map(OrgUnit.fromJson).toList();
    items.sort((a, b) => a.id.compareTo(b.id));
    return items;
  }

  List<FlightType> getFlightTypes() {
    final items = _refList('flightTypes').map(FlightType.fromJson).toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
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

  Future<UserProfile> registerUser({
    required String nome,
    required String cognome,
    required String callsign,
    required String username,
    required String password,
    String? email,
    int? orgUnitId,
    String orgUnitName = '',
    List<int> aircraftQualificationIds = const [],
  }) async {
    final users = _db.users.toList();
    final now = DateTime.now().toIso8601String();
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final hash = GhDbService.hashPassword(password);
    final newUser = {
      'id': id,
      'nome': nome,
      'cognome': cognome,
      'callsign': callsign,
      'email': email,
      'username': username,
      'password_hash': hash,
      'role': 'user',
      'org_unit_id': orgUnitId,
      'org_unit_name': orgUnitName,
      'aircraft_qualification_ids': aircraftQualificationIds,
      'fitness_expiry': null,
      'is_active': true,
      'is_approved': false,
      'created_at': now,
      'updated_at': now,
    };
    users.add(newUser);
    await _db.saveUsers(users);
    return UserProfile.fromJson(newUser);
  }

  Future<void> createUser({
    required String nome,
    required String cognome,
    required String username,
    required String password,
    String? callsign,
    String? email,
    int? orgUnitId,
    String orgUnitName = '',
    List<int> aircraftQualificationIds = const [],
  }) async {
    final users = _db.users.toList();
    final now = DateTime.now().toIso8601String();
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final hash = GhDbService.hashPassword(password);
    users.add({
      'id': id,
      'nome': nome,
      'cognome': cognome,
      'callsign': callsign,
      'email': email,
      'username': username,
      'password_hash': hash,
      'role': 'user',
      'org_unit_id': orgUnitId,
      'org_unit_name': orgUnitName,
      'aircraft_qualification_ids': aircraftQualificationIds,
      'fitness_expiry': null,
      'is_active': true,
      'is_approved': true,
      'created_at': now,
      'updated_at': now,
    });
    await _db.saveUsers(users);
  }

  Future<void> approveUser(String userId) async {
    final users = _db.users.toList();
    final idx = users.indexWhere((u) => u['id'] == userId);
    if (idx < 0) return;
    users[idx] = {
      ...users[idx],
      'is_approved': true,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveUsers(users);
  }

  Future<void> rejectUser(String userId) async {
    final users = _db.users.toList();
    final idx = users.indexWhere((u) => u['id'] == userId);
    if (idx < 0) return;
    users[idx] = {
      ...users[idx],
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveUsers(users);
  }

  Future<void> updatePilotCapabilities(String userId, List<int> capabilityTypeIds) async {
    final caps = _db.capabilities.where((c) => c['user_id'] != userId).toList();
    final now = DateTime.now().toIso8601String();
    for (final id in capabilityTypeIds) {
      caps.add({
        'id': _db.nextId(caps),
        'user_id': userId,
        'capability_type_id': id,
        'expiry_date': null,
        'active': true,
        'created_at': now,
        'updated_at': now,
      });
    }
    await _db.saveCapabilities(caps);
  }

  List<int> getPilotCapabilityIds(String userId) {
    return _db.capabilities
        .where((c) => c['user_id'] == userId && c['active'] != false)
        .map((c) => c['capability_type_id'] as int)
        .toList();
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

  Future<void> updatePassword(String userId, String newPassword) async {
    final users = _db.users.toList();
    final idx = users.indexWhere((u) => u['id'] == userId);
    if (idx < 0) return;
    users[idx] = {
      ...users[idx],
      'password_hash': GhDbService.hashPassword(newPassword),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveUsers(users);
  }

  Future<void> deleteUser(String userId) async {
    final users = _db.users.where((u) => u['id'] != userId).toList();
    await _db.saveUsers(users);
    final caps = _db.capabilities.where((c) => c['user_id'] != userId).toList();
    await _db.saveCapabilities(caps);
  }
}
