import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';

/// Error raised when an HTTP operation fails.
class NetworkError implements SyzygyError {
  @override
  final SyzygyErrorCode code;

  @override
  final String message;

  @override
  final SyzygyErrorSeverity severity;

  @override
  final Object? underlyingError;

  /// Creates a [NetworkError] with the given fields.
  const NetworkError({
    required this.code,
    required this.message,
    this.severity = SyzygyErrorSeverity.error,
    this.underlyingError,
  });

  @override
  String toString() => 'NetworkError(${code.rawValue}): $message';
}

/// Abstract interceptor for modifying requests before they are sent.
abstract class RequestInterceptor {
  /// Called before [request] is dispatched. Return the (possibly modified)
  /// request to continue or throw to abort.
  Future<NetworkRequest> intercept(NetworkRequest request);
}

/// Signature for the injectable delay used between retry attempts.
///
/// Defaults to [Future.delayed] in production.  Inject a custom
/// implementation in tests to record requested [Duration]s without incurring
/// real wall-clock time — matching the clock-injection pattern used in the
/// Android `OkHttpNetworkClient`.
///
/// ```dart
/// // Record delays without waiting:
/// final recorded = <Duration>[];
/// final client = HttpNetworkClient(
///   backoffClock: (d) async => recorded.add(d),
/// );
/// ```
typedef BackoffClock = Future<void> Function(Duration duration);

/// Concrete [BackoffClock] implementation that records requested [Duration]s
/// without incurring real wall-clock time.
///
/// Inject into [HttpNetworkClient] in tests for deterministic backoff-timing
/// assertions — no real sleep, no flaky timing, mirrors the Android clock-injection pattern.
///
/// ```dart
/// final clock = RecordingBackoffClock();
/// final client = HttpNetworkClient(backoffClock: clock.call);
/// // ... exercise client ...
/// expect(clock.durations[0], equals(const Duration(milliseconds: 200)));
/// ```
class RecordingBackoffClock {
  /// All durations passed to this clock, in order.
  final durations = <Duration>[];

  /// Records [d] without waiting.
  Future<void> call(Duration d) async {
    durations.add(d);
  }
}

/// Concrete HTTP client implementing [NetworkClientProtocol].
///
/// Supports GET, POST, PUT, DELETE, PATCH, HEAD with:
/// - Configurable [timeout]
/// - Pluggable [interceptors]
/// - Exponential-backoff retry (max [maxRetries] attempts)
/// - Injectable [backoffClock] for deterministic testing
/// - Optional [logger] for request/response/error logging (null = zero overhead)
class HttpNetworkClient implements NetworkClientProtocol {
  final HttpClient _client;
  final Duration timeout;
  final int maxRetries;
  final List<RequestInterceptor> interceptors;

  /// Delay function inserted between retry attempts.
  ///
  /// Defaults to [Future.delayed] so production behaviour is unchanged.
  /// Override in tests to avoid real waiting and to assert the exact
  /// [Duration]s the backoff algorithm computes.
  final BackoffClock backoffClock;

  /// Optional logger. When non-null, each request and response is logged.
  /// Authorization headers are never logged. When null, no overhead is incurred.
  final LoggerProtocol? logger;

  /// Creates an [HttpNetworkClient].
  ///
  /// [client] is optional; a new [HttpClient] is used when omitted.
  /// [backoffClock] is optional; defaults to [Future.delayed].
  /// [logger] is optional; defaults to null (no logging).
  HttpNetworkClient({
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    List<RequestInterceptor>? interceptors,
    BackoffClock? backoffClock,
    this.logger,
  })  : _client = client ?? HttpClient(),
        interceptors = interceptors ?? [],
        backoffClock = backoffClock ?? Future<void>.delayed {
    _client.connectionTimeout = timeout;
  }

  @override
  Future<NetworkResponse> execute(NetworkRequest request) async {
    var req = request;
    for (final i in interceptors) {
      req = await i.intercept(req);
    }
    return _executeWithRetry(req, 0);
  }

  Future<NetworkResponse> _executeWithRetry(
      NetworkRequest request, int attempt) async {
    try {
      return await _doExecute(request);
    } on NetworkError catch (e) {
      if (attempt >= maxRetries - 1) rethrow;
      if (e.code == SyzygyErrorCode.timeout ||
          e.code == SyzygyErrorCode.networkUnavailable) {
        final delay = Duration(milliseconds: 200 * (1 << attempt));
        await backoffClock(delay);
        return _executeWithRetry(request, attempt + 1);
      }
      rethrow;
    }
  }

  Future<NetworkResponse> _doExecute(NetworkRequest request) async {
    final uri = Uri.parse(request.url);
    final method = request.method.value;

    // Log the outgoing request, omitting the Authorization header.
    if (logger != null) {
      final safeHeaders = Map<String, String>.from(request.headers)
        ..remove('Authorization')
        ..remove('authorization');
      logger!.info('NetworkClient → $method ${request.url}', metadata: {
        'headers': safeHeaders.toString(),
        'body_size': '${request.body?.length ?? 0}',
      });
    }

    final stopwatch = Stopwatch()..start();
    late HttpClientRequest httpReq;

    try {
      httpReq = await _client
          .openUrl(method, uri)
          .timeout(timeout, onTimeout: () => throw NetworkError(
                code: SyzygyErrorCode.timeout,
                message: 'Request timed out: ${request.url}',
              ));
    } on SocketException catch (e) {
      final err = NetworkError(
        code: SyzygyErrorCode.networkUnavailable,
        message: 'Network unavailable: $e',
        underlyingError: e,
      );
      logger?.error('NetworkClient ← SOCKET ERROR ${request.url}', error: err);
      throw err;
    }

    request.headers.forEach(httpReq.headers.set);

    if (request.body != null && request.body!.isNotEmpty) {
      httpReq.add(request.body!);
    }

    late HttpClientResponse httpRes;
    try {
      httpRes = await httpReq.close().timeout(timeout, onTimeout: () {
        throw NetworkError(
          code: SyzygyErrorCode.timeout,
          message: 'Response timed out: ${request.url}',
        );
      });
    } on SocketException catch (e) {
      throw NetworkError(
        code: SyzygyErrorCode.networkUnavailable,
        message: 'Network unavailable: $e',
        underlyingError: e,
      );
    }

    final bytes = await _collectBytes(httpRes);

    final headers = <String, String>{};
    httpRes.headers.forEach((name, values) {
      headers[name] = values.join(', ');
    });

    final response = NetworkResponse(
      statusCode: httpRes.statusCode,
      data: Uint8List.fromList(bytes),
      headers: headers,
    );

    if (response.isServerError) {
      final error = NetworkError(
        code: SyzygyErrorCode.serverError,
        message: 'Server error ${httpRes.statusCode}',
      );
      logger?.error('NetworkClient ← ERROR ${request.url}', error: error,
          metadata: {
            'status': '${httpRes.statusCode}',
            'elapsed_ms': '${stopwatch.elapsedMilliseconds}',
          });
      throw error;
    }

    logger?.info(
        'NetworkClient ← ${httpRes.statusCode} ${request.url}',
        metadata: {
          'status': '${httpRes.statusCode}',
          'elapsed_ms': '${stopwatch.elapsedMilliseconds}',
          'body_size': '${response.data.length}',
        });

    return response;
  }

  Future<List<int>> _collectBytes(HttpClientResponse res) {
    final completer = Completer<List<int>>();
    final bytes = <int>[];
    res.listen(
      bytes.addAll,
      onDone: () => completer.complete(bytes),
      onError: completer.completeError,
      cancelOnError: true,
    );
    return completer.future;
  }

  /// Convenience: perform a GET request.
  Future<NetworkResponse> get(String url, {Map<String, String>? headers}) =>
      execute(NetworkRequest(
        url: url,
        method: NetworkMethod.get,
        headers: headers ?? {},
      ));

  /// Convenience: perform a POST request with an optional JSON [body].
  Future<NetworkResponse> post(String url, {
    Object? body,
    Map<String, String>? headers,
  }) {
    final encoded = body != null ? utf8.encode(jsonEncode(body)) : null;
    return execute(NetworkRequest(
      url: url,
      method: NetworkMethod.post,
      headers: {
        if (encoded != null) 'Content-Type': 'application/json',
        ...?headers,
      },
      body: encoded != null ? Uint8List.fromList(encoded) : null,
    ));
  }

  /// Convenience: perform a PUT request.
  Future<NetworkResponse> put(String url, {
    Object? body,
    Map<String, String>? headers,
  }) {
    final encoded = body != null ? utf8.encode(jsonEncode(body)) : null;
    return execute(NetworkRequest(
      url: url,
      method: NetworkMethod.put,
      headers: {
        if (encoded != null) 'Content-Type': 'application/json',
        ...?headers,
      },
      body: encoded != null ? Uint8List.fromList(encoded) : null,
    ));
  }

  /// Convenience: perform a DELETE request.
  Future<NetworkResponse> delete(String url,
          {Map<String, String>? headers}) =>
      execute(NetworkRequest(
        url: url,
        method: NetworkMethod.delete,
        headers: headers ?? {},
      ));

  /// Convenience: perform a PATCH request.
  Future<NetworkResponse> patch(String url, {
    Object? body,
    Map<String, String>? headers,
  }) {
    final encoded = body != null ? utf8.encode(jsonEncode(body)) : null;
    return execute(NetworkRequest(
      url: url,
      method: NetworkMethod.patch,
      headers: {
        if (encoded != null) 'Content-Type': 'application/json',
        ...?headers,
      },
      body: encoded != null ? Uint8List.fromList(encoded) : null,
    ));
  }

  /// Closes the underlying [HttpClient].
  void close({bool force = false}) => _client.close(force: force);

  bool _disposed = false;

  /// Releases resources held by this client.
  ///
  /// Sets an internal disposed flag and closes the underlying [HttpClient]
  /// forcefully. Safe to call multiple times — subsequent calls are no-ops.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close(force: true);
  }
}
