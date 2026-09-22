/// Field-level rules shared by both registration forms.
///
/// These mirror the server's zod schemas so a person is told about a problem
/// while typing rather than after a round trip — the server stays the authority.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[\w.+-]+@([\w-]+\.)+[A-Za-z]{2,}$');
  static final RegExp _hasLetter = RegExp(r'[A-Za-zऀ-ॿ]');
  static final RegExp _repeatedOnly = RegExp(r'^(.)\1+$');

  /// Rejects blanks, one-letter entries and meaningless values like "aaaa".
  static String? name(String? value, {String field = 'full name'}) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Please enter your $field.';
    if (trimmed.length < 2) return 'Please enter your $field.';
    if (trimmed.length > 80) return 'That $field is too long.';
    if (!_hasLetter.hasMatch(trimmed)) return 'Please enter a valid $field.';
    if (_repeatedOnly.hasMatch(trimmed.replaceAll(' ', ''))) {
      return 'Please enter a valid $field.';
    }
    return null;
  }

  static String? companyName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Please enter your company name.';
    if (trimmed.length < 2) return 'Please enter your company name.';
    if (trimmed.length > 120) return 'That company name is too long.';
    return null;
  }

  static String? email(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Please enter your email address.';
    if (!_email.hasMatch(trimmed)) return 'Please enter a valid email address.';
    return null;
  }

  /// Optional at registration — the flow also supports OTP-only sign-in.
  static String? password(String? value, {bool required = false}) {
    final text = value ?? '';
    if (text.isEmpty) return required ? 'Please choose a password.' : null;
    if (text.length < 8) return 'Use at least 8 characters.';
    if (text.length > 128) return 'That password is too long.';
    return null;
  }

  static String? otp(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Enter the 6-digit code.';
    if (trimmed.length != 6 || int.tryParse(trimmed) == null) {
      return 'Enter the 6-digit code.';
    }
    return null;
  }

  static String? pincode(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^[0-9]{4,10}$').hasMatch(trimmed)) {
      return 'Please enter a valid PIN code.';
    }
    return null;
  }

  /// Normalises whitespace so " Aditi   Sharma " is stored as "Aditi Sharma".
  static String tidy(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
