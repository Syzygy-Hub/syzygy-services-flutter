import 'dart:async';
import 'dart:convert';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';

import '../persistence/storage_provider.dart';

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
/// [InMemoryStorageProvider].
///
/// Tokens are persisted via the storage layer so they survive provider
/// reconstruction within a process. Refresh is stubbed — callers can subclass
/// and override [refresh].
class TokenAuthProvider implements AuthProvider {
  final InMemoryStorageProvider _storage;
  final _controller = StreamController<AuthState>.broadcast();
  AuthState _state = const Unauthenticated();

  /// Creates a [TokenAuthProvider] backed by [storage].
  TokenAuthProvider(this._storage) {
    // Restore state from storage.
    final saved = _storage.getSecure<String>(_accessTokenKey);
    if (saved != null) {
      final token = AuthToken(accessToken: saved,
          refreshToken: _storage.getSecure<String>(_refreshTokenKey));
      _state = token.isExpired ? AuthExpired(token) : Authenticated(token);
    }
  }

  @override
  Stream<AuthState> get stateStream => _controller.stream;

  @override
  AuthState get state => _state;

  @override
  void authenticate(AuthToken token) {
    _storage.setSecure<String>(token.accessToken, _accessTokenKey);
    if (token.refreshToken != null) {
      _storage.setSecure<String>(token.refreshToken!, _refreshTokenKey);
    }
    _setState(Authenticated(token));
  }

  @override
  Future<AuthToken> refresh() async {
    final current = _state;
    if (current is! Authenticated && current is! AuthExpired) {
      throw const NetworkUnavailableAuthError();
    }
    _setState(const Refreshing());
    // Stub: subclasses should override and call a real network endpoint.
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final token = current.token!;
    // Return the same token unchanged (stub behaviour).
    _setState(Authenticated(token));
    return token;
  }

  @override
  void signOut() {
    _storage.removeSecure<String>(_accessTokenKey);
    _storage.removeSecure<String>(_refreshTokenKey);
    _setState(const Unauthenticated());
  }

  void _setState(AuthState next) {
    _state = next;
    _controller.add(next);
  }

  /// Disposes the stream controller.
  void dispose() => _controller.close();
}

/// Thrown when a token refresh is attempted without an active session.
class NetworkUnavailableAuthError implements Exception {
  /// Creates a [NetworkUnavailableAuthError].
  const NetworkUnavailableAuthError();

  @override
  String toString() => 'NetworkUnavailableAuthError: no active session to refresh';
}
