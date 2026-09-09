class PasswordRules {
  PasswordRules._();

  static const String helperText =
      '8+ chars, with upper, lower, number and special character';

  static String? validate(String? value, {String emptyMessage = 'Password is required'}) {
    if (value == null || value.isEmpty) return emptyMessage;
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Must contain at least 1 uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Must contain at least 1 lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Must contain at least 1 number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Must contain at least 1 special character';
    }
    return null;
  }
}
