class Validators {
  Validators._();

  static const _blockedEmailDomains = <String>{
    'example.com',
    'example.org',
    'example.net',
    'test.com',
    'test.org',
    'fake.com',
    'domain.com',
    'email.com',
    'mail.com',
    'temp.com',
    'tempmail.com',
    'throwaway.com',
    'throwawaymail.com',
  };

  static bool _isEmailFormatValid(String v) {
    return RegExp(r'^[\w\.\-]+@[\w\-]+(\.\w{2,})+$').hasMatch(v);
  }

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

  static String? email(String? value) {
    final v = value?.trim().toLowerCase() ?? '';
    if (v.isEmpty) return 'Please enter your email';
    if (!_isEmailFormatValid(v)) {
      return 'Enter a valid email (e.g. name@example.com)';
    }
    final domain = v.split('@').last;
    if (_blockedEmailDomains.contains(domain)) {
      return 'Please use a real email address';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a password';
    final min = minLength < 8 ? 8 : minLength;
    if (v.length < min) return 'At least $min characters';
    if (v.length > 64) return 'Maximum 64 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(v)) {
      return 'Include at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(v)) {
      return 'Include at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+~=]').hasMatch(v)) {
      return 'Include at least one special character';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

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

  static String? schoolName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your school name';
    if (v.length < 2) return 'At least 2 characters';
    if (v.length > 60) return 'Maximum 60 characters';
    if (!RegExp(r"^[a-zA-Z0-9À-ÿ .,'\-]+$").hasMatch(v)) {
      return 'Letters, numbers, spaces, and basic punctuation only';
    }
    return null;
  }

  static String? className(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter a class name';
    if (v.length < 2) return 'At least 2 characters';
    if (v.length > 40) return 'Maximum 40 characters';
    if (!RegExp(r"^[a-zA-Z0-9À-ÿ .,'\-]+$").hasMatch(v)) {
      return 'Letters, numbers, spaces, and basic punctuation only';
    }
    return null;
  }

  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a valid phone number';
    if (digits.length > 13) return 'Too many digits';
    return null;
  }

  static String? joinCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter the class code';
    if (v.length != 6) return 'Code must be 6 characters';
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(v.toUpperCase())) {
      return 'Letters and numbers only';
    }
    return null;
  }

  static String? usernameOrEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your username or email';
    if (v.contains('@')) {
      if (!_isEmailFormatValid(v)) {
        return 'Enter a valid email (e.g. name@example.com)';
      }
      return null;
    }
    return username(v);
  }
}