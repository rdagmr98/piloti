import 'package:encrypt/encrypt.dart';

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  static const String _rawKey = 'a3f8c21b94e05d7f62b1834ca90e5d2f';
  late final Key _key = Key.fromUtf8(_rawKey);
  final IV _iv = IV.allZerosOfLength(16);
  late final Encrypter _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

  String encrypt(String plaintext) {
    if (plaintext.isEmpty) return plaintext;
    return 'ENC:${_encrypter.encrypt(plaintext, iv: _iv).base64}';
  }

  String decrypt(String ciphertext) {
    if (!ciphertext.startsWith('ENC:')) return ciphertext;
    try {
      return _encrypter.decrypt64(ciphertext.substring(4), iv: _iv);
    } catch (_) {
      return ciphertext;
    }
  }

  String? encryptNullable(String? v) => v == null ? null : encrypt(v);
  String? decryptNullable(String? v) => v == null ? null : decrypt(v);
}
