import 'dart:convert';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_client.dart';

// ---------------------------------------------------------------------------
// JWTs for testing
// ---------------------------------------------------------------------------

// Valid (exp 2030): {"sub":"1","exp":1893456000}
const _validJwt = 'eyJhbGciOiJIUzI1NiJ9'
    '.eyJzdWIiOiIxIiwiZXhwIjoxODkzNDU2MDAwfQ'
    '.signature';

// Expired (exp 2000): {"sub":"1","exp":946684800}
const _expiredJwt = 'eyJhbGciOiJIUzI1NiJ9'
    '.eyJzdWIiOiIxIiwiZXhwIjo5NDY2ODQ4MDB9'
    '.signature';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

HttpNetworkClient _clientReturning(int status, Map<String, dynamic> body) {
  final bytes = utf8.encode(jsonEncode(body));
  final fakeHttp = FakeHttpClient(
    statusCode: status,
    body: bytes,
  );
  return HttpNetworkClient(client: fakeHttp);
}

TokenAuthProvider _authWithNetwork({
  required int status,
  required Map<String, dynamic> responseBody,
  String endpoint = 'https://auth.example.com/refresh',
}) {
  final storage = InMemoryStorageProvider();
  final network = _clientReturning(status, responseBody);
  return TokenAuthProvider(
    storage,
    networkClient: network,
    refreshEndpoint: endpoint,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TokenAuthProvider — real refresh flow', () {
    test('refresh POSTs to endpoint and updates stored token', () async {
      const newAccess = 'new.access.token';
      const newRefresh = 'new-refresh-token';

      final auth = _authWithNetwork(
        status: 200,
        responseBody: {
          'accessToken': newAccess,
          'refreshToken': newRefresh,
        },
      );
      auth.authenticate(const AuthToken(
          accessToken: _validJwt, refreshToken: 'old-refresh-token'));

      final refreshed = await auth.refresh();

      expect(refreshed.accessToken, newAccess);
      expect(refreshed.refreshToken, newRefresh);
      expect(auth.state, isA<Authenticated>());
      auth.dispose();
    });

    test('refresh emits Refreshing then Authenticated on success', () async {
      final auth = _authWithNetwork(
        status: 200,
        responseBody: {
          'accessToken': 'token.a.b',
          'refreshToken': 'rt',
        },
      );
      auth.authenticate(
          const AuthToken(accessToken: _validJwt, refreshToken: 'old-rt'));

      final states = <AuthState>[];
      final sub = auth.stateStream.listen(states.add);

      await auth.refresh();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states.any((s) => s is Refreshing), isTrue);
      expect(states.last, isA<Authenticated>());
      auth.dispose();
    });

    test('refresh failure clears tokens and emits Unauthenticated', () async {
      final auth = _authWithNetwork(
        status: 401,
        responseBody: {'error': 'unauthorized'},
      );
      auth.authenticate(
          const AuthToken(accessToken: _validJwt, refreshToken: 'rt'));

      await expectLater(
          auth.refresh(), throwsA(isA<TokenRefreshFailedError>()));
      expect(auth.state, isA<Unauthenticated>());
      auth.dispose();
    });

    test('refresh without session throws NetworkUnavailableAuthError',
        () async {
      final auth = _authWithNetwork(
        status: 200,
        responseBody: {'accessToken': 'x'},
      );

      await expectLater(
          auth.refresh(), throwsA(isA<NetworkUnavailableAuthError>()));
      auth.dispose();
    });

    test('executeWithAutoRefresh refreshes expired JWT automatically',
        () async {
      const newToken = 'new.valid.token';
      final auth = _authWithNetwork(
        status: 200,
        responseBody: {'accessToken': newToken, 'refreshToken': 'rt2'},
      );
      // Authenticate with an expired token.
      auth.authenticate(
          const AuthToken(accessToken: _expiredJwt, refreshToken: 'rt'));

      final result = await auth.executeWithAutoRefresh();
      expect(result.accessToken, newToken);
      auth.dispose();
    });

    test('executeWithAutoRefresh returns current token when not expired',
        () async {
      final storage = InMemoryStorageProvider();
      final auth = TokenAuthProvider(storage); // no network — stub path
      auth.authenticate(const AuthToken(accessToken: _validJwt));

      final result = await auth.executeWithAutoRefresh();
      expect(result.accessToken, _validJwt);
      auth.dispose();
    });

    test('stub refresh (no network client) returns same token', () async {
      final storage = InMemoryStorageProvider();
      final auth = TokenAuthProvider(storage);
      auth.authenticate(const AuthToken(accessToken: _validJwt));

      final result = await auth.refresh();
      expect(result.accessToken, _validJwt);
      auth.dispose();
    });
  });
}
