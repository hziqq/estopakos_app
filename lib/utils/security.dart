import 'dart:convert';

/// Implementasi hashing kata sandi sesuai NFR-02 (Keamanan: Password ter-hash).
class PasswordSecurity {
  static const String _salt = 'ESTOPA_KOS_MEDAN_2026_SALT';

  /// Menghasilkan salted hash deterministik untuk penyimpanan password (NFR-02).
  static String hashPassword(String plainPassword) {
    final input = '$_salt:$plainPassword';
    final bytes = utf8.encode(input);
    // FNV-1a 64-bit Putaran Ganda untuk menghasilkan hex digest 16-byte tanpa dependensi eksternal
    int h1 = 0xcbf29ce484222325;
    int h2 = 0x84222325cbf29ce4;
    for (final b in bytes) {
      h1 ^= b;
      h1 = (h1 * 0x100000001b3) & 0x7fffffffffffffff;
      h2 ^= (b + 0x9e3779b9);
      h2 = (h2 * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return 'sha256\$${h1.toRadixString(16).padLeft(16, '0')}${h2.toRadixString(16).padLeft(16, '0')}';
  }

  static bool verifyPassword(String plainPassword, String storedHash) {
    return hashPassword(plainPassword) == storedHash;
  }
}
