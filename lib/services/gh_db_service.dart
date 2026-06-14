import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/gh_config.dart';
import 'crypto_service.dart';

class GhDbService {
  static final GhDbService _instance = GhDbService._internal();
  factory GhDbService() => _instance;
  GhDbService._internal();

  static String get _base =>
      '${GhConfig.apiRoot}/repos/${GhConfig.owner}/${GhConfig.dataRepo}/contents/db';

  final Map<String, Map<String, dynamic>> _cache = {};
  final _crypto = CryptoService();

  /// Ultimo errore di salvataggio (null = tutto ok). Un listener globale in
  /// app.dart mostra una SnackBar quando diventa non-null.
  static final ValueNotifier<String?> saveError = ValueNotifier<String?>(null);

  // ── Hashing password (PBKDF2-HMAC-SHA256, salt per-utente) ──────────────────
  // Formato corrente: `pbkdf2$<iter>$<saltB64>$<hashB64>`.
  // Formato legacy: SHA-256 esadecimale di (password + salt globale).
  // `verifyPassword` accetta entrambi; i vecchi hash vengono migrati al primo
  // login andato a buon fine (vedi AuthService).
  static const int _pbkdf2Iterations = 10000;

  static String hashPassword(String password) {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final dk = _pbkdf2(utf8.encode(password), salt, _pbkdf2Iterations, 32);
    return 'pbkdf2\$$_pbkdf2Iterations\$${base64.encode(salt)}\$${base64.encode(dk)}';
  }

  static bool isLegacyHash(String stored) => !stored.startsWith('pbkdf2\$');

  static bool verifyPassword(String password, String stored) {
    if (stored.startsWith('pbkdf2\$')) {
      final parts = stored.split('\$');
      if (parts.length != 4) return false;
      final iter = int.tryParse(parts[1]) ?? 0;
      if (iter <= 0) return false;
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      final dk = _pbkdf2(utf8.encode(password), salt, iter, expected.length);
      return _constTimeEquals(dk, expected);
    }
    // Legacy: SHA-256(password + salt globale)
    final legacy = sha256.convert(utf8.encode(password + GhConfig.passwordSalt)).toString();
    return _constTimeEquals(utf8.encode(legacy), utf8.encode(stored));
  }

  static List<int> _pbkdf2(List<int> password, List<int> salt, int iterations, int dkLen) {
    final hmac = Hmac(sha256, password);
    final out = <int>[];
    var block = 1;
    while (out.length < dkLen) {
      final blockSalt = <int>[
        ...salt,
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];
      var u = hmac.convert(blockSalt).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.addAll(t);
      block++;
    }
    return out.sublist(0, dkLen);
  }

  static bool _constTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Map<String, dynamic> _encryptUser(Map<String, dynamic> u) => {
    ...u,
    'nome': _crypto.encryptNullable(u['nome'] as String?),
    'cognome': _crypto.encryptNullable(u['cognome'] as String?),
    'email': _crypto.encryptNullable(u['email'] as String?),
    'username': _crypto.encryptNullable(u['username'] as String?),
  };

  Map<String, dynamic> _decryptUser(Map<String, dynamic> u) => {
    ...u,
    'nome': _crypto.decryptNullable(u['nome'] as String?),
    'cognome': _crypto.decryptNullable(u['cognome'] as String?),
    'email': _crypto.decryptNullable(u['email'] as String?),
    'username': _crypto.decryptNullable(u['username'] as String?),
  };

  dynamic _normalizeLoaded(String fileName, dynamic data) {
    if (fileName == 'users.json') {
      final items = List<Map<String, dynamic>>.from(data as List? ?? []);
      return items.map(_decryptUser).toList();
    }
    return data;
  }

  Future<void> init() async {
    _cache.clear();
    await Future.wait([
      _loadFile('reference.json'),
      _loadFile('users.json'),
      _loadFile('flights.json'),
      _loadFile('capabilities.json'),
      _loadFile('notifications.json'),
    ]);
  }

  Future<void> _loadFile(String fileName) async {
    final res = await http.get(
      Uri.parse('$_base/$fileName'),
      headers: {
        ...GhConfig.authHeaders(),
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final content = utf8.decode(
        base64.decode((j['content'] as String).replaceAll('\n', '')),
      );
      _cache[fileName] = {
        'data': _normalizeLoaded(fileName, jsonDecode(content)),
        'sha': j['sha'] as String,
      };
      return;
    }
    if (res.statusCode == 404) {
      _cache[fileName] = {
        'data': fileName == 'reference.json' ? <String, dynamic>{} : <dynamic>[],
        'sha': '',
      };
      return;
    }
    throw Exception('GitHub API ${res.statusCode} loading $fileName');
  }

  dynamic _getData(String f) => _cache[f]?['data'];
  String _getSha(String f) => _cache[f]?['sha'] as String? ?? '';

  Future<void> _writeFile(String fileName, dynamic data, String msg) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final body = <String, dynamic>{
        'message': msg,
        'content': base64.encode(utf8.encode(jsonEncode(data))),
      };
      final sha = _getSha(fileName);
      if (sha.isNotEmpty) body['sha'] = sha;
      final res = await http.put(
        Uri.parse('$_base/$fileName'),
        headers: {
          ...GhConfig.authHeaders(),
          'Accept': 'application/vnd.github+json',
          'Content-Type': 'application/json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        body: jsonEncode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final newSha =
            ((jsonDecode(res.body) as Map)['content'] as Map)['sha'] as String;
        _cache[fileName] = {'data': data, 'sha': newSha};
        saveError.value = null;
        return;
      }
      if (res.statusCode == 409) {
        await _loadFile(fileName);
        if (attempt < maxAttempts) {
          await Future<void>.delayed(const Duration(seconds: 1));
          continue;
        }
        saveError.value = 'Salvataggio $fileName non riuscito: conflitto.';
        throw ConflictException('Conflitto scrittura dopo $maxAttempts tentativi.');
      }
      saveError.value = 'Salvataggio $fileName non riuscito (${res.statusCode}).';
      throw Exception('GitHub API ${res.statusCode}: ${res.body}');
    }
  }

  int nextId(Iterable<Map<String, dynamic>> existing) {
    final ids = existing.map((e) => e['id']).whereType<int>().toSet();
    var candidate = DateTime.now().microsecondsSinceEpoch;
    while (ids.contains(candidate)) candidate++;
    return candidate;
  }

  Map<String, dynamic> get referenceData =>
      (_getData('reference.json') as Map<String, dynamic>?) ?? {};

  List<Map<String, dynamic>> get users =>
      List<Map<String, dynamic>>.from(_getData('users.json') as List? ?? []);

  Future<void> saveUsers(List<Map<String, dynamic>> data) async {
    final encrypted = data.map(_encryptUser).toList();
    await _writeFile('users.json', encrypted, 'aggiornamento utenti');
    _cache['users.json'] = {'data': data, 'sha': _getSha('users.json')};
  }

  Future<void> updateUserPassword(String userId, String newHash) async {
    final all = users;
    final idx = all.indexWhere((u) => u['id'] == userId);
    if (idx == -1) throw Exception('Utente non trovato');
    all[idx] = {
      ...all[idx],
      'password_hash': newHash,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await saveUsers(all);
  }

  List<Map<String, dynamic>> get flights =>
      List<Map<String, dynamic>>.from(_getData('flights.json') as List? ?? []);

  Future<void> saveFlights(List<Map<String, dynamic>> data) =>
      _writeFile('flights.json', data, 'aggiornamento voli');

  List<Map<String, dynamic>> get capabilities =>
      List<Map<String, dynamic>>.from(
        _getData('capabilities.json') as List? ?? [],
      );

  Future<void> saveCapabilities(List<Map<String, dynamic>> data) =>
      _writeFile('capabilities.json', data, 'aggiornamento capacità');

  List<Map<String, dynamic>> get notifications =>
      List<Map<String, dynamic>>.from(
        _getData('notifications.json') as List? ?? [],
      );

  Future<void> reloadAll() => init();
}

class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);
  @override
  String toString() => message;
}
