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

/// Concrete HTTP client implementing [NetworkClientProtocol].
///
/// Supports GET, POST, PUT, DELETE, PATCH, HEAD with:
/// - Configurable [timeout]
/// - Pluggable [interceptors]
/// - Exponential-backoff retry (max [maxRetries] attempts)
class HttpNetworkClient implements NetworkClientProtocol {
  final HttpClient _client;
  final Duration timeout;
  final int maxRetries;
  final List<RequestInterceptor> interceptors;

  /// Creates an [HttpNetworkClient].
  ///
  /// [client] is optional; a new [HttpClient] is used when omitted.
  HttpNetworkClient({
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    List<RequestInterceptor>? interceptors,
  })  : _client = client ?? HttpClient(),
        interceptors = interceptors ?? [] {
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
        await Future<void>.delayed(delay);
        return _executeWithRetry(request, attempt + 1);
      }
      rethrow;
    }
  }

  Future<NetworkResponse> _doExecute(NetworkRequest request) async {
    final uri = Uri.parse(request.url);
    final method = request.method.value;
    late HttpClientRequest httpReq;

    try {
      httpReq = await _client
          .openUrl(method, uri)
          .timeout(timeout, onTimeout: () => throw NetworkError(
                code: SyzygyErrorCode.timeout,
                message: 'Request timed out: ${request.url}',
              ));
    } on SocketException catch (e) {
      throw NetworkError(
        code: SyzygyErrorCode.networkUnavailable,
        message: 'Network unavailable: $e',
        underlyingError: e,
      );
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
      throw NetworkError(
        code: SyzygyErrorCode.serverError,
        message: 'Server error ${httpRes.statusCode}',
      );
    }

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
}
