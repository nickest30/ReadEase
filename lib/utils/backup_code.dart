import 'dart:math';

/// Generates single-use backup codes.
/// Used when a user loses access to their phone and can't receive OTP.
class BackupCode {
  BackupCode._();

  /// Generate a 6-digit numeric code.
  /// Numeric (vs alphanumeric) because it's easier for users to type
  /// from a saved note, and matches the OTP format they already know.
  static String generate() {
    final random = Random.secure();
    final digits = List.generate(6, (_) => random.nextInt(10));
    return digits.join();
  }

  /// Format for display: "123 456"
  static String format(String code) {
    if (code.length != 6) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }
}