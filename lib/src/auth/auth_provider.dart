import 'dart:async';
import 'dart:convert';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';

import '../networking/network_client.dart';

// Storage keys used to persist tokens across restarts.
const _accessTokenKey = StorageKey<String>('auth.accessToken');
const _refreshTokenKey = StorageKey<String>('auth.refreshToken');

/// Decodes a Base64url-encoded string (no padding required).
Map<String, dynamic> _decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length < 2) return {};
  var payload = parts[1];
  // Add padding
  switch (payload.length % 4) {
    case 2:
      payload += '==';
    case 3:
      payload += '=';
  }
  try {
    final decoded = utf8.decode(base64Url.decode(payload));
    final json = jsonDecode(decoded);
    if (json is Map<String, dynamic>) return json;
  } catch (_) {}
  return {};
}

/// Returns whether the JWT [token] is expired according to its `exp` claim.
bool jwtIsExpired(String token) {
  final payload = _decodeJwtPayload(token);
  final exp = payload['exp'];
  if (exp == null) return false;
  final expMs = (exp is num ? exp.toInt() : int.tryParse('$exp') ?? 0) * 1000;
  return DateTime.now().millisecondsSinceEpoch >= expMs;
}

/// Concrete implementation of Foundation's [AuthProvider] contract backed by
/// a [StorageProvider].
///
/// Tokens are persisted via the storage layer so they survive provider
/// reconstruction within a process.
///
/// Pass [refreshEndpoint] and [networkClient] to enable real token refresh via
/// an HTTP POST to the endpoint. When omitted the provider falls back to
/// returning the existing token unchanged (stub behaviour).
///
/// Auto-refresh behaviour: callers should check [TokenAuthProvider.isExpiredAndShouldRefresh]
/// before issuing requests, or use [executeWithAutoRefresh] to have the provider
/// detect an expired JWT and refresh transparently.
class TokenAuthProvider implements AuthProvider {
  final StorageProvider _storage;
  final _controller = StreamController<AuthState>.broadcast();
  AuthState _state = const Unauthenticated();

  /// Optional HTTP client used for the token-refresh network call.
  final HttpNetworkClient? networkClient;

  /// URL that accepts a POST with `{"refreshToken": "<rt>"}` and returns
  /// `{"accessToken": "<at>", "refreshToken": "<rt>"}`.
  final String? refreshEndpoint;

  /// Creates a [TokenAuthProvider].
  ///
  /// [storage] MUST be backed by a secure storage implementation
  /// (e.g. flutter_secure_storage). Tokens stored in a non-secure
  /// provider are accessible to other apps on rooted devices.
  /// TODO(Foundation-v1.2.0): enforce SecureStorageProvider type.
  ///
  /// Supply [networkClient] and [refreshEndpoint] to enable real token refresh.
  TokenAuthProvider(
    this._storage, {
    this.networkClient,
    this.refreshEndpoint,
  }) {
    // Restore state from storage.
    final saved = _storage.get<String>(_accessTokenKey);
    if (saved != null) {
      final token = AuthToken(
          accessToken: saved,
          refreshToken: _storage.get<String>(_refreshTokenKey));
      _state = token.isExpired ? AuthExpired(token) : Authenticated(token);
    }
  }

  @override
  Stream<AuthState> get stateStream => _controller.stream;

  @override
  AuthState get state => _state;

  @override
  void authenticate(AuthToken token) {
    _storage.set<String>(token.accessToken, _accessTokenKey);
    if (token.refreshToken != null) {
      _storage.set<String>(token.refreshToken!, _refreshTokenKey);
    }
    _setState(Authenticated(token));
  }

  /// Refreshes the access token.
  ///
  /// When [networkClient] and [refreshEndpoint] are configured, performs a
  /// real HTTP POST to [refreshEndpoint] with the current refresh token,
  /// parses the response, persists the new tokens, and emits [Authenticated].
  ///
  /// On network failure or an error response the tokens are cleared and
  /// [AuthState.unauthenticated] is emitted before re-throwing.
  ///
  /// Falls back to returning the existing token unchanged when no network
  /// client is configured (useful in tests and stub scenarios).
  @override
  Future<AuthToken> refresh() async {
    final current = _state;
    if (current is! Authenticated && current is! AuthExpired) {
      throw const NetworkUnavailableAuthError();
    }
    _setState(const Refreshing());

    final client = networkClient;
    final endpoint = refreshEndpoint;

    if (client != null && endpoint != null) {
      try {
        final rt = current.token?.refreshToken;
        final response = await client.post(
          endpoint,
          body: {'refreshToken': rt ?? ''},
        );

        if (!response.isSuccess) {
          _clearAndSignOut();
          throw TokenRefreshFailedError(
              'Refresh endpoint returned ${response.statusCode}');
        }

        final body = jsonDecode(utf8.decode(response.data));
        if (body is! Map<String, dynamic>) {
          _clearAndSignOut();
          throw const TokenRefreshFailedError('Invalid refresh response body');
        }

        final newAccess = body['accessToken'] as String?;
        final newRefresh = body['refreshToken'] as String?;

        if (newAccess == null || newAccess.isEmpty) {
          _clearAndSignOut();
          throw const TokenRefreshFailedError(
              'Missing accessToken in response');
        }

        final newToken =
            AuthToken(accessToken: newAccess, refreshToken: newRefresh);
        _storage.set<String>(newAccess, _accessTokenKey);
        if (newRefresh != null) {
          _storage.set<String>(newRefresh, _refreshTokenKey);
        }
        _setState(Authenticated(newToken));
        return newToken;
      } catch (e) {
        if (e is TokenRefreshFailedError) rethrow;
        _clearAndSignOut();
        throw TokenRefreshFailedError('Token refresh failed: $e');
      }
    }

    // Stub path: no network client configured — return existing token.
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final token = current.token!;
    _setState(Authenticated(token));
    return token;
  }

  /// Checks whether the current access token is expired and, if so, calls
  /// [refresh] automatically before returning.
  ///
  /// Returns the current (possibly refreshed) [AuthToken], or throws
  /// [NetworkUnavailableAuthError] when not authenticated.
  Future<AuthToken> executeWithAutoRefresh() async {
    final current = _state;
    if (current is Unauthenticated) throw const NetworkUnavailableAuthError();

    final token = current.token;
    if (token != null && jwtIsExpired(token.accessToken)) {
      return refresh();
    }

    if (token == null) throw const NetworkUnavailableAuthError();
    return token;
  }

  void _clearAndSignOut() {
    _storage.remove<String>(_accessTokenKey);
    _storage.remove<String>(_refreshTokenKey);
    _setState(const Unauthenticated());
  }

  @override
  void signOut() {
    _clearAndSignOut();
  }

  void _setState(AuthState next) {
    _state = next;
    _controller.add(next);
  }

  /// Returns whether biometric authentication is available on this device.
  /// Always returns `false` in the stub. Wire to `local_auth` package's
  /// `LocalAuthentication.canCheckBiometrics` for real Face ID / Touch ID / fingerprint support.
  Future<bool> canUseBiometric() async => false;

  /// Authenticates the user with biometrics.
  /// [reason] is the localized reason shown to the user in the system prompt.
  /// Returns [Unauthenticated] on the stub. Wire to `local_auth` for real usage.
  Future<AuthState> authenticateWithBiometric(String reason) async =>
      const Unauthenticated();

  /// Disposes the stream controller.
  void dispose() => _controller.close();
}

/// Thrown when a token refresh is attempted without an active session.
class NetworkUnavailableAuthError implements Exception {
  /// Creates a [NetworkUnavailableAuthError].
  const NetworkUnavailableAuthError();

  @override
  String toString() =>
      'NetworkUnavailableAuthError: no active session to refresh';
}

/// Thrown when the refresh endpoint returns an error or an unexpected response.
class TokenRefreshFailedError implements Exception {
  /// Human-readable reason for the failure.
  final String reason;

  /// Creates a [TokenRefreshFailedError].
  const TokenRefreshFailedError(this.reason);

  @override
  String toString() => 'TokenRefreshFailedError: $reason';
}
