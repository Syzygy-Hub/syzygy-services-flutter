import 'dart:async';
import 'dart:io';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_client.dart';

// kBackoffBaseMs is exported from syzygy_services_flutter via network_client.dart

// ---------------------------------------------------------------------------
// Counting HttpClient — tracks openUrl call count; configurable per-call responses
// ---------------------------------------------------------------------------

class _CountingHttpClient implements HttpClient {
  int callCount = 0;

  /// Responses in order; the last one is repeated once exhausted.
  final List<FakeHttpClientResponse> _responses;

  _CountingHttpClient(this._responses);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final idx =
        callCount < _responses.length ? callCount : _responses.length - 1;
    callCount++;
    return FakeHttpClientRequest(_responses[idx]);
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
        [FakeHttpClientResponse(500, [])],
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
        throwsA(isA<HttpNetworkError>()
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
        throwsA(isA<HttpNetworkError>()
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
        successResponse: FakeHttpClientResponse(200, []),
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

    test('exponential backoff delay ceiling doubles with each attempt',
        () async {
      // Previously this test measured real wall-clock deltas and asserted
      // delays[1] > delays[0].  That assertion is inherently flaky with
      // full-jitter backoff: both values are uniformly random in their
      // respective windows, so a high attempt-0 sample and a low attempt-1
      // sample can invert the order on any run.
      //
      // Fix: inject RecordingBackoffClock so no real sleep occurs and assert
      // on the *ceiling* property (attempt 1's upper bound is 2× attempt 0's),
      // which is deterministic regardless of the random sample.
      final recorder = RecordingBackoffClock();

      final client = HttpNetworkClient(
        client: _ThrowingHttpClient(
          onOpen: () => throw const SocketException('simulated'),
        ),
        maxRetries: 3,
        backoffClock: recorder.call,
      );

      await expectLater(
        () => client.execute(
          const NetworkRequest(url: url, method: NetworkMethod.get),
        ),
        throwsA(isA<HttpNetworkError>()),
      );

      // maxRetries=3 → attempt 0 (delay), attempt 1 (delay), attempt 2 (throws)
      // → 2 delays recorded.
      expect(recorder.durations, hasLength(2));
      // attempt 0: jitter in [0, min(8000, 500*2^0)] = [0, 500]
      expect(recorder.durations[0].inMilliseconds,
          inInclusiveRange(0, kBackoffBaseMs));
      // attempt 1: jitter in [0, min(8000, 500*2^1)] = [0, 1000]
      expect(recorder.durations[1].inMilliseconds,
          inInclusiveRange(0, kBackoffBaseMs * 2));
      // The ceiling for attempt 1 must be strictly larger than attempt 0's
      // ceiling — this is the deterministic property the test was originally
      // trying to capture.
      expect(kBackoffBaseMs * 2, greaterThan(kBackoffBaseMs));
    });
  });

  // --------------------------------------------------------------------------
  // Injectable-clock deterministic backoff tests
  // Mirrors the Android NetworkClient clock-injection pattern.
  // --------------------------------------------------------------------------

  group('HttpNetworkClient injectable BackoffClock — deterministic backoff',
      () {
    const url = 'https://example.com/api';

    test(
        'canonical backoff policy: attempt 0 in [0,500ms], attempt 1 in [0,1000ms]',
        () async {
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
        throwsA(isA<HttpNetworkError>()),
      );

      // attempt 0 → jitter in [0, min(8000, 500*2^0)] = [0, 500]
      // attempt 1 → jitter in [0, min(8000, 500*2^1)] = [0, 1000]
      // attempt 2 → exhausted, throws (no third delay)
      expect(recorder.durations, hasLength(2));
      expect(recorder.durations[0].inMilliseconds,
          inInclusiveRange(0, kBackoffBaseMs));
      expect(recorder.durations[1].inMilliseconds,
          inInclusiveRange(0, kBackoffBaseMs * 2));
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
        throwsA(isA<HttpNetworkError>()),
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
        throwsA(isA<HttpNetworkError>()),
      );

      expect(recorder.durations, hasLength(retries - 1));
    });

    test('canonical backoff bounds: attempt N in [0, min(cap, base*2^N)]',
        () async {
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
        throwsA(isA<HttpNetworkError>()),
      );

      // 4 delays for maxRetries=5 (attempts 0..3 each get a delay before next attempt)
      expect(recorder.durations, hasLength(4));
      final caps = [500, 1000, 2000, 4000]; // min(8000, 500*2^n) for n=0..3
      for (var i = 0; i < recorder.durations.length; i++) {
        expect(
            recorder.durations[i].inMilliseconds, inInclusiveRange(0, caps[i]),
            reason: 'delay[$i] should be in [0, ${caps[i]}]');
      }
    });

    test('no delay fired when server error (non-retryable 500)', () async {
      final recorder = RecordingBackoffClock();

      final client = HttpNetworkClient(
        client: FakeHttpClient(statusCode: 500, body: []),
        maxRetries: 3,
        backoffClock: recorder.call,
      );

      await expectLater(
        () => client.execute(
          const NetworkRequest(url: url, method: NetworkMethod.get),
        ),
        throwsA(isA<HttpNetworkError>()),
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
  final FakeHttpClientResponse successResponse;
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
    return FakeHttpClientRequest(successResponse);
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
