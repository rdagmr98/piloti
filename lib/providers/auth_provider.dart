import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reference_models.dart';
import '../models/user_models.dart';
import '../services/auth_service.dart';
import '../services/gh_db_service.dart';
import '../services/user_service.dart';

final authProvider = ChangeNotifierProvider((ref) => AuthProvider());

class AuthProvider extends ChangeNotifier {
  final _auth = AuthService();
  final _db = GhDbService();
  final _userService = UserService();

  UserProfile? _user;
  List<AircraftType> _aircraftTypes = [];
  List<CapabilityType> _capabilityTypes = [];
  bool _loading = false;
  String? _error;

  UserProfile? get currentUser => _user;
  List<AircraftType> get aircraftTypes => _aircraftTypes;
  List<CapabilityType> get capabilityTypes => _capabilityTypes;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _db.init();
      final user = await _auth.login(username, password);
      if (user == null) {
        _error = 'Credenziali non valide.';
        _loading = false;
        notifyListeners();
        return false;
      }
      _user = user;
      _aircraftTypes = _userService.getAircraftTypes();
      _capabilityTypes = _userService.getCapabilityTypes();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Errore di connessione: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  void refreshUser() {
    if (_user == null) return;
    final updated = _userService.findById(_user!.id);
    if (updated != null) {
      _user = updated;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _user = null;
    _aircraftTypes = [];
    _capabilityTypes = [];
    notifyListeners();
  }
}
