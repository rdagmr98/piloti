import '../models/user_models.dart';
import 'gh_db_service.dart';

class AuthService {
  final _db = GhDbService();

  Future<UserProfile?> login(String username, String password) async {
    final hash = GhDbService.hashPassword(password);
    for (final raw in _db.users) {
      if ((raw['username'] as String?)?.toLowerCase() ==
              username.toLowerCase() &&
          raw['password_hash'] == hash &&
          raw['is_active'] != false) {
        return UserProfile.fromJson(raw);
      }
    }
    return null;
  }
}
