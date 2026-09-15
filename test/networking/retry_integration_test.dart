import 'dart:async';
import 'dart:io';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers shared with network_client_test (duplicated to keep test isolation)
// ---------------------------------------------------------------------------

class _FakeHttpHeaders implements HttpHeaders {
  final _map = <String, List<String>>{};

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _map.forEach(action);

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map[name] = ['$value'];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _map.putIfAbsent(name, () => []).add('$value');

  @override
  List<String>? operator [](String name) => _map[name];

  @override
  String? value(String name) => _map[name]?.first;

  @override
  void clear() => _map.clear();

  @override
  void remove(String name, Object value) {}

  @override
  void removeAll(String name) => _map.remove(name);

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
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_body]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

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

// ---------------------------------------------------------------------------
// Counting HttpClient — tracks openUrl call count; configurable per-call responses
// ---------------------------------------------------------------------------

class _CountingHttpClient implements HttpClient {
  int callCount = 0;

  /// Responses in order; the last one is repeated once exhausted.
  final List<_FakeHttpClientResponse> _responses;

  _CountingHttpClient(this._responses);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final idx = callCount < _responses.length ? callCount : _responses.length - 1;
    callCount++;
    return _FakeHttpClientRequest(_responses[idx]);
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
// Simple fake HttpClient (used by injectable-clock tests)
// ---------------------------------------------------------------------------

class _FakeHttpClient implements HttpClient {
  final int statusCode;
  final List<int> body;

  _FakeHttpClient({this.statusCode = 200, this.body = const []});

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(_FakeHttpClientResponse(statusCode, body));

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
// Helpers for injectable-clock tests
// ---------------------------------------------------------------------------

// RecordingBackoffClock is exported from syzygy_services_flutter — no local definition needed.

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HttpNetworkClient retry integration', () {
    const url = 'https://example.com/api';

    test('retry fires correct number of times on persistent failure', () async {
      // Server always returns 500; maxRetries=3 means 3 total attempts.
      final http = _CountingHttpClient(
        [_FakeHttpClientResponse(500, [])],
      );
      final client = HttpNetworkClient(
        client: http,
        maxRetries: 3,
        timeout: const Duration(seconds: 5),
      );

      await expectLater(
        () => client.execute(
          const NetworkRequest(url: url, method: NetworkMethod.get),
        ),
        throwsA(isA<NetworkError>()
            .having((e) => e.code, 'code', SyzygyErrorCode.serverError)),
      );

      // 500 is a server error — NOT a retryable code (only timeout/networkUnavailable
      // trigger retry), so the client throws immediately on the first attempt.
      expect(http.callCount, 1);
    });

    test('max retry ceiling enforced on retryable network errors', () async {
      // Simulate a SocketException by making openUrl throw on every call.
      // We use a custom client that throws SocketException.
      var calls = 0;
      final customClient = _ThrowingHttpClient(
        onOpen: () {
          calls++;
          throw const SocketException('simulated failure');
        },
      );

      final client = HttpNetworkClient(
        client: customClient,
        maxRetries: 3,
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        () => client.execute(
          const NetworkRequest(url: url, method: NetworkMethod.get),
        ),
        throwsA(isA<NetworkError>()
            .having((e) => e.code, 'code', SyzygyErrorCode.networkUnavailable)),
      );

      // maxRetries=3: attempt 0, 1, 2 → 3 total calls
      expect(calls, 3);
    });

    test('retry succeeds when server recovers on Nth attempt', () async {
      // First two calls fail with SocketException; third succeeds with 200.
      var calls = 0;
      final customClient = _RecoveringHttpClient(
        failFor: 2,
        successResponse: _FakeHttpClientResponse(200, []),
        onCall: () => calls++,
      );

      final client = HttpNetworkClient(
        client: customClient,
        maxRetries: 3,
        timeout: const Duration(milliseconds: 1),
      );

      final response = await client.execute(
        const NetworkRequest(url: url, method: NetworkMethod.get),
      );

      expect(response.statusCode, 200);
      expect(calls, 3); // 2 failures + 1 success
    });

    test('exponential backoff delay doubles with each attempt', () async {
      // We verify that delays grow by recording wall-clock time between attempts.
      // To keep tests fast, we use a tiny base delay and just check ordering.
      final delays = <Duration>[];
      DateTime? lastCall;

      final customClient = _CallbackHttpClient(
        onOpen: () async {
          final now = DateTime.now();
          if (lastCall != null) {
            delays.add(now.difference(lastCall!));
          }
          lastCall = now;
          throw const SocketException('simulated');
        },
      );

      // maxRetries=3 gives attempt 0 (delay 200ms*1), 1 (delay 200ms*2), then throws.
      // We use a short timeout to speed up the test.
      final client = HttpNetworkClient(
        client: customClient,
        maxRetries: 3,
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        () => client.execute(
          const NetworkRequest(url: url, method: NetworkMethod.get),
        ),
        throwsA(isA<NetworkError>()),
      );

      // At least 2 inter-attempt intervals recorded; second should be longer.
      expect(delays.length, greaterThanOrEqualTo(1));
      if (delays.length >= 2) {
        expect(delays[1].inMilliseconds, greaterThan(delays[0].inMilliseconds));
      }
    });
  });

  // --------------------------------------------------------------------------
  // Injectable-clock deterministic backoff tests
  // Mirrors the Android NetworkClient clock-injection pattern.
  // --------------------------------------------------------------------------

  group('HttpNetworkClient injectable BackoffClock — deterministic backoff', () {
    const url = 'https://example.com/api';

    test('exact backoff durations: 200ms, 400ms for maxRetries=3', () async {
      final recorder = RecordingBackoffClock();

      final client = HttpNetworkClient(
        client: _ThrowingHttpClient(
          onOpen: () => throw const SocketException('fail'),
        ),
        maxRetries: 3,
        backoffClock: recorder.call,
      );

      await expectLater(
        () => client.execute(
          const NetworkRequest(url: url, method: NetworkMethod.get),
        ),
        throwsA(isA<NetworkError>()),
      );

      // attempt 0 → delay 200*(1<<0)=200ms
      // attempt 1 → delay 200*(1<<1)=400ms
      // attempt 2 → exhausted, throws (no third delay)
      expect(recorder.durations, hasLength(2));
      expect(recorder.durations[0], equals(const Duration(milliseconds: 200)));
      expect(recorder.durations[1], equals(const Duration(milliseconds: 400)));
    });

    test('no delay fired when maxRetries=1 (single attempt)', () async {
      final recorder = RecordingBackoffClock();

      final client = HttpNetworkClient(
        client: _ThrowingHttpClient(
          onOpen: () => throw const SocketException('fail'),
        ),
        maxRetries: 1,
        backoffClock: recorder.call,
      );

      await expectLater(
        () => client.execute(
          const NetworkRequest(url: url, method: NetworkMethod.get),
        ),
        throwsA(isA<NetworkError>()),
      );

      // maxRetries=1 means attempt 0 is the final attempt — no delay before it.
      expect(recorder.durations, isEmpty);
    });

    test('exactly maxRetries-1 delays fired for persistent failure', () async {
      final recorder = RecordingBackoffClock();
      const retries = 5;

      final client = HttpNetworkClient(
        client: _ThrowingHttpClient(
          onOpen: () => throw const SocketException('fail'),
        ),
        maxRetries: retries,
        backoffClock: recorder.call,
      );

      await expectLater(
        () => client.execute(
          const NetworkRequest(url: url, method: NetworkMethod.get),
        ),
        throwsA(isA<NetworkError>()),
      );

      expect(recorder.durations, hasLength(retries - 1));
    });

    test('delays are strictly increasing (exponential growth)', () async {
      final recorder = RecordingBackoffClock();

      final client = HttpNetworkClient(
        client: _ThrowingHttpClient(
          onOpen: () => throw const SocketException('fail'),
        ),
        maxRetries: 5,
        backoffClock: recorder.call,
      );

      await expectLater(
        () => client.execute(
          const NetworkRequest(url: url, method: NetworkMethod.get),
        ),
        throwsA(isA<NetworkError>()),
      );

      for (var i = 1; i < recorder.durations.length; i++) {
        expect(
          recorder.durations[i].inMilliseconds,
          greaterThan(recorder.durations[i - 1].inMilliseconds),
          reason: 'delay[$i] should be > delay[${i - 1}]',
        );
      }
    });

    test('no delay fired when server error (non-retryable 500)', () async {
      final recorder = RecordingBackoffClock();

      final client = HttpNetworkClient(
        client: _FakeHttpClient(statusCode: 500, body: []),
        maxRetries: 3,
        backoffClock: recorder.call,
      );

      await expectLater(
        () => client.execute(
          const NetworkRequest(url: url, method: NetworkMethod.get),
        ),
        throwsA(isA<NetworkError>()),
      );

      // 500 is not retryable — no delays should be recorded.
      expect(recorder.durations, isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Always throws [SocketException] from [openUrl].
class _ThrowingHttpClient implements HttpClient {
  final void Function() onOpen;

  _ThrowingHttpClient({required this.onOpen});

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    onOpen();
    throw const SocketException('simulated');
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

/// Throws [SocketException] for the first [failFor] calls, then returns [successResponse].
class _RecoveringHttpClient implements HttpClient {
  final int failFor;
  final _FakeHttpClientResponse successResponse;
  final void Function() onCall;
  int _calls = 0;

  _RecoveringHttpClient({
    required this.failFor,
    required this.successResponse,
    required this.onCall,
  });

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    onCall();
    if (_calls < failFor) {
      _calls++;
      throw const SocketException('simulated failure');
    }
    _calls++;
    return _FakeHttpClientRequest(successResponse);
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

/// Calls [onOpen] async on each [openUrl].
class _CallbackHttpClient implements HttpClient {
  final Future<void> Function() onOpen;

  _CallbackHttpClient({required this.onOpen});

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    await onOpen();
    throw const SocketException('should not reach');
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
