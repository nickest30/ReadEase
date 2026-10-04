// Centralized form validation rules for ReadEase.
// Each method returns null when valid, or an error string when invalid.

class Validators {
  Validators._();

  // ── Username ─────────────────────────────────────────────────────
  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter a username';
    if (v.length < 3) return 'At least 3 characters';
    if (v.length > 20) return 'Maximum 20 characters';
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(v)) {
      return 'Start with a letter; letters, numbers, _ only';
    }
    return null;
  }

  // ── Email ────────────────────────────────────────────────────────
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[\w\.\-]+@[\w\-]+(\.\w{2,})+$').hasMatch(v)) {
      return 'Enter a valid email (e.g. name@example.com)';
    }
    return null;
  }

  // ── Password ─────────────────────────────────────────────────────
  // Change `minLength` if your team decides on a different threshold.
  static String? password(String? value, {int minLength = 6}) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a password';
    if (v.length < minLength) return 'At least $minLength characters';
    if (v.length > 64) return 'Maximum 64 characters';
    return null;
  }

  // ── Confirm password ─────────────────────────────────────────────
  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  // ── Display name ─────────────────────────────────────────────────
  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter a name';
    if (v.length < 2) return 'At least 2 characters';
    if (v.length > 30) return 'Maximum 30 characters';
    if (!RegExp(r"^[a-zA-ZÀ-ÿ .'\-]+$").hasMatch(v)) {
      return 'Letters, spaces, apostrophes only';
    }
    return null;
  }

  // ── School name ──────────────────────────────────────────────────
  static String? schoolName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your school name';
    if (v.length < 2) return 'At least 2 characters';
    if (v.length > 60) return 'Maximum 60 characters';
    return null;
  }

  // ── Class name ───────────────────────────────────────────────────
  static String? className(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter a class name';
    if (v.length < 2) return 'At least 2 characters';
    if (v.length > 40) return 'Maximum 40 characters';
    return null;
  }

  // ── Join code ────────────────────────────────────────────────────
  static String? joinCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter the class code';
    if (v.length != 6) return 'Code must be 6 characters';
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(v.toUpperCase())) {
      return 'Letters and numbers only';
    }
    return null;
  }

  // ── Username or email (parent login) ─────────────────────────────
  static String? usernameOrEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your username or email';
    if (v.contains('@')) return email(v);
    return username(v);
  }
}

