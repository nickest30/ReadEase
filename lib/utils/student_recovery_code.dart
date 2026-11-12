import 'dart:math';

class StudentRecoveryCode {
  StudentRecoveryCode._();

  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String generate() {
    final random = Random.secure();
    final chars = List.generate(
      8,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    );
    return '${chars.sublist(0, 4).join()}-${chars.sublist(4, 8).join()}';
  }

  static String normalize(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static String format(String input) {
    final clean = normalize(input);
    if (clean.length != 8) return input;
    return '${clean.substring(0, 4)}-${clean.substring(4)}';
  }

  static bool isWellFormed(String input) {
    return normalize(input).length == 8;
  }
}