import 'dart:convert';
import 'dart:io';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_client.dart';

// ---------------------------------------------------------------------------
// Recording logger for MED-09 tests.
// ---------------------------------------------------------------------------

class _RecordingLogger extends LoggerProtocol {
  final entries = <LogEntry>[];

  @override
  void log(LogEntry entry) => entries.add(entry);
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
    return FakeHttpClientRequest(FakeHttpClientResponse(statusCode, bytes));
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

  group('NetworkRemoteConfigProvider logger (MED-09)', () {
    const configUrl = 'https://config.example.com/remote.json';

    test('fetch failure logs a warning', () async {
      final logger = _RecordingLogger();
      final http = _CountingFakeHttpClient(
        responseBody: {},
        statusCode: 503,
      );
      final provider = NetworkRemoteConfigProvider(
        client: HttpNetworkClient(client: http, maxRetries: 1),
        configUrl: configUrl,
        logger: logger,
      );

      await provider.fetch();

      expect(
        logger.entries.any((e) =>
            e.level == LogLevel.warning &&
            e.message.contains('RemoteConfigProvider: fetch failed')),
        isTrue,
        reason: 'Expected a warning log entry on fetch failure',
      );
    });
  });
}
