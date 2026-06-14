import 'package:encrypt/encrypt.dart';

/// Cifratura PII (nome/cognome/email/username).
///
/// Formati ciphertext:
/// - `ENC1:<ivBase64>:<ctBase64>` — formato corrente, IV casuale per record
///   (non deterministico: due testi uguali producono ciphertext diversi).
/// - `ENC:<ctBase64>` — formato legacy con IV tutto-zero. Letto in sola
///   decifratura per retrocompatibilità con i dati già presenti in piloti-data.
///
/// NOTA: la chiave resta nel bundle. L'IV casuale elimina il leak di
/// uguaglianza ma la riservatezza piena richiede spostare la chiave su un
/// backend/proxy (vedi PROXY_URL in GhConfig).
class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  static const String _rawKey = 'a3f8c21b94e05d7f62b1834ca90e5d2f';
  late final Key _key = Key.fromUtf8(_rawKey);
  final IV _legacyIv = IV.allZerosOfLength(16);
  late final Encrypter _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

  String encrypt(String plaintext) {
    if (plaintext.isEmpty) return plaintext;
    final iv = IV.fromSecureRandom(16);
    final ct = _encrypter.encrypt(plaintext, iv: iv).base64;
    return 'ENC1:${iv.base64}:$ct';
  }

  String decrypt(String ciphertext) {
    if (ciphertext.startsWith('ENC1:')) {
      try {
        final rest = ciphertext.substring(5);
        final sep = rest.indexOf(':');
        if (sep < 0) return ciphertext;
        final iv = IV.fromBase64(rest.substring(0, sep));
        return _encrypter.decrypt64(rest.substring(sep + 1), iv: iv);
      } catch (_) {
        return ciphertext;
      }
    }
    if (ciphertext.startsWith('ENC:')) {
      try {
        return _encrypter.decrypt64(ciphertext.substring(4), iv: _legacyIv);
      } catch (_) {
        return ciphertext;
      }
    }
    return ciphertext;
  }

  String? encryptNullable(String? v) => v == null ? null : encrypt(v);
  String? decryptNullable(String? v) => v == null ? null : decrypt(v);
}
