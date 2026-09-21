import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Minimal HTTP fake stack (mirrors network_client_test helpers)
// ---------------------------------------------------------------------------

class _FakeHttpHeaders implements HttpHeaders {
  final _map = <String, List<String>>{};

  @override
  void forEach(void Function(String n, List<String> v) a) => _map.forEach(a);
  @override
  void set(String n, Object v, {bool preserveHeaderCase = false}) =>
      _map[n] = ['$v'];
  @override
  void add(String n, Object v, {bool preserveHeaderCase = false}) =>
      _map.putIfAbsent(n, () => []).add('$v');
  @override
  List<String>? operator [](String n) => _map[n];
  @override
  String? value(String n) => _map[n]?.first;
  @override
  void clear() => _map.clear();
  @override
  void remove(String n, Object v) {}
  @override
  void removeAll(String n) => _map.remove(n);
  @override
  bool get chunkedTransferEncoding => false;
  @override
  set chunkedTransferEncoding(bool v) {}
  @override
  int get contentLength => -1;
  @override
  set contentLength(int v) {}
  @override
  ContentType? get contentType => null;
  @override
  set contentType(ContentType? v) {}
  @override
  DateTime? get date => null;
  @override
  set date(DateTime? v) {}
  @override
  DateTime? get expires => null;
  @override
  set expires(DateTime? v) {}
  @override
  String? get host => null;
  @override
  set host(String? v) {}
  @override
  DateTime? get ifModifiedSince => null;
  @override
  set ifModifiedSince(DateTime? v) {}
  @override
  bool get persistentConnection => true;
  @override
  set persistentConnection(bool v) {}
  @override
  int? get port => null;
  @override
  set port(int? v) {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final int _status;
  final List<int> _body;
  final _FakeHttpHeaders _hdrs = _FakeHttpHeaders();

  _FakeHttpClientResponse(this._status, this._body);

  @override
  int get statusCode => _status;

  @override
  HttpHeaders get headers => _hdrs;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.fromIterable([_body]).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  final _FakeHttpClientResponse _response;
  final _FakeHttpHeaders _hdrs = _FakeHttpHeaders();

  _FakeHttpClientRequest(this._response);

  @override
  HttpHeaders get headers => _hdrs;
  @override
  void add(List<int> data) {}
  @override
  void write(Object? obj) {}
  @override
  Future<HttpClientResponse> close() async => _response;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeHttpClient implements HttpClient {
  final _FakeHttpClientResponse _response;
  _FakeHttpClient(this._response);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(_response);
  @override
  set connectionTimeout(Duration? v) {}
  @override
  Duration? get connectionTimeout => null;
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

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
  final fakeHttp = _FakeHttpClient(
    _FakeHttpClientResponse(status, bytes),
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
