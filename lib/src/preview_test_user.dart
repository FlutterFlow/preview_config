/// Represents a test user for preview authentication.
///
/// A [PreviewTestUser] contains credentials for a test account that can be
/// used during previews. The password is provided directly but could be
/// loaded from an environment variable for security.
class PreviewTestUser {
  /// Creates a test user with the given credentials.
  ///
  /// - [email]: The email address for the test user.
  /// - [password]: The password for the test user.
  PreviewTestUser({required this.email, required this.password})
    : assert(password.isNotEmpty, 'Password cannot be empty');

  /// The email address for this test user.
  final String email;

  /// The password for this test user.
  final String password;

  @override
  String toString() =>
      'PreviewTestUser('
      'email: $email, '
      'password: ${password.split('').map((c) => '*').join()}'
      ')';
}
