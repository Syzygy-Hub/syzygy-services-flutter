import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Minimal HTTP fake (same pattern as other test files)
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

/// Counting fake HttpClient — tracks how many times the endpoint is hit.
class _CountingFakeHttpClient implements HttpClient {
  int callCount = 0;
  final Map<String, dynamic> responseBody;
  final int statusCode;

  _CountingFakeHttpClient({required this.responseBody, this.statusCode = 200});

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    callCount++;
    final bytes = utf8.encode(jsonEncode(responseBody));
    return _FakeHttpClientRequest(_FakeHttpClientResponse(statusCode, bytes));
  }

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
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('NetworkRemoteConfigProvider — cache TTL', () {
    const url = 'https://config.example.com/remote.json';

    test('fetch hits network on first call (empty cache)', () async {
      final http = _CountingFakeHttpClient(
        responseBody: {'featureFlag': true, 'maxItems': 50},
      );
      final provider = NetworkRemoteConfigProvider(
        client: HttpNetworkClient(client: http),
        configUrl: url,
        cacheTtlSeconds: 3600,
      );

      await provider.fetch();

      expect(http.callCount, 1);
      expect(provider.getBool('featureFlag'), isTrue);
      expect(provider.getInt('maxItems'), 50);
      expect(provider.lastFetchTime, isNotNull);
    });

    test('fetch returns cached result within TTL (no network hit)', () async {
      final http = _CountingFakeHttpClient(
        responseBody: {'key': 'value'},
      );
      final provider = NetworkRemoteConfigProvider(
        client: HttpNetworkClient(client: http),
        configUrl: url,
        cacheTtlSeconds: 3600,
      );

      await provider.fetch(); // populates cache
      await provider.fetch(); // should use cache

      expect(http.callCount, 1,
          reason: 'Second fetch should use cached data within TTL');
    });

    test('fetch hits network again when TTL is 0 (always stale)', () async {
      final http = _CountingFakeHttpClient(
        responseBody: {'key': 'value'},
      );
      final provider = NetworkRemoteConfigProvider(
        client: HttpNetworkClient(client: http),
        configUrl: url,
        cacheTtlSeconds: 0,
      );

      await provider.fetch();
      await provider.fetch();

      expect(http.callCount, 2,
          reason: 'TTL=0 means every fetch hits the network');
    });

    test('defaults are used before first fetch', () async {
      final http = _CountingFakeHttpClient(responseBody: {});
      final provider = NetworkRemoteConfigProvider(
        client: HttpNetworkClient(client: http),
        configUrl: url,
        defaults: {'theme': 'dark', 'timeout': 30},
      );

      expect(provider.getString('theme'), 'dark');
      expect(provider.getInt('timeout'), 30);
      expect(http.callCount, 0);
    });

    test('remote values override defaults after successful fetch', () async {
      final http = _CountingFakeHttpClient(
        responseBody: {'theme': 'light'},
      );
      final provider = NetworkRemoteConfigProvider(
        client: HttpNetworkClient(client: http),
        configUrl: url,
        defaults: {'theme': 'dark'},
      );

      await provider.fetch();

      expect(provider.getString('theme'), 'light');
    });

    test('lastFetchTime is updated after successful fetch', () async {
      final http = _CountingFakeHttpClient(responseBody: {'k': 'v'});
      final provider = NetworkRemoteConfigProvider(
        client: HttpNetworkClient(client: http),
        configUrl: url,
      );

      expect(provider.lastFetchTime, isNull);
      await provider.fetch();
      expect(provider.lastFetchTime, isNotNull);
    });

    test('default cacheTtlSeconds is 3600', () {
      final http = _CountingFakeHttpClient(responseBody: {});
      final provider = NetworkRemoteConfigProvider(
        client: HttpNetworkClient(client: http),
        configUrl: url,
      );
      expect(provider.cacheTtlSeconds, 3600);
    });

    test('non-success response does not update cache', () async {
      final http = _CountingFakeHttpClient(
        responseBody: {'key': 'value'},
        statusCode: 500,
      );
      // maxRetries=1 so it does not loop on server errors.
      final provider = NetworkRemoteConfigProvider(
        client: HttpNetworkClient(client: http, maxRetries: 1),
        configUrl: url,
        cacheTtlSeconds: 3600,
      );

      // Server error: fetch should not throw but should not update lastFetchTime.
      try {
        await provider.fetch();
      } catch (_) {
        // Network errors may surface; we only care about lastFetchTime.
      }

      expect(provider.lastFetchTime, isNull);
    });
  });

  group('InMemoryRemoteConfigProvider', () {
    test('lastFetchTime is null before fetch', () {
      final p = InMemoryRemoteConfigProvider();
      expect(p.lastFetchTime, isNull);
    });

    test('lastFetchTime is set after fetch', () async {
      final p = InMemoryRemoteConfigProvider(remoteValues: {'x': 1});
      await p.fetch();
      expect(p.lastFetchTime, isNotNull);
    });
  });
}
