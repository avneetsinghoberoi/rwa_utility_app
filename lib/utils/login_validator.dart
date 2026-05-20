/// Pure validation logic extracted from LoginScreen so it can be unit-tested
/// independently of Firebase or Flutter widgets.
class LoginValidator {
  const LoginValidator._();

  /// Returns an error message string, or null if the input is valid.
  static String? validate({
    required String email,
    required String password,
  }) {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      return 'Please enter email and password';
    }

    if (!trimmedEmail.contains('@') || !trimmedEmail.contains('.')) {
      return 'Please enter a valid email';
    }

    if (trimmedPassword.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null; // valid
  }
}
