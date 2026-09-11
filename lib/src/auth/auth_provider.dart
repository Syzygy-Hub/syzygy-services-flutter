/// Errors thrown by [JWTAuthProvider].
class AuthError implements Exception {
  /// The error message.
  final String message;

  /// Creates an [AuthError] with the given [message].
  const AuthError(this.message);

  @override
  String toString() => 'AuthError: $message';
}

/// Defines the contract for authentication and token management.
abstract class AuthProvider {
  /// The current access token, or null if unauthenticated.
  String? get accessToken;

  /// Stores the given [token] as the current access token.
  void storeToken(String token);

  /// Clears the current access token.
  void clearToken();

  /// Refreshes the access token. Returns the new token or throws on failure.
  Future<String> refreshToken();
}

/// An [AuthProvider] that stores a JWT token in memory with a stub refresh.
class JWTAuthProvider implements AuthProvider {
  String? _accessToken;

  /// Initialises the provider with an optional pre-existing [token].
  JWTAuthProvider({String? token}) : _accessToken = token;

  @override
  String? get accessToken => _accessToken;

  @override
  void storeToken(String token) => _accessToken = token;

  @override
  void clearToken() => _accessToken = null;

  @override
  Future<String> refreshToken() async {
    throw const AuthError('Token refresh not implemented');
  }
}
