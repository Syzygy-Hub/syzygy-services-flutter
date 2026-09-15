import 'dart:async';
import 'dart:io';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Minimal recording logger
// ---------------------------------------------------------------------------

class _RecordingLogger extends LoggerProtocol {
  final List<LogEntry> entries = [];

  @override
  void log(LogEntry entry) => entries.add(entry);
}

// ---------------------------------------------------------------------------
// Fake HttpClient stack (mirrors network_client_test.dart helpers)
// ---------------------------------------------------------------------------

class _FakeHeaders implements HttpHeaders {
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

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  final int _status;
  final List<int> _body;
  final _FakeHeaders _hdrs = _FakeHeaders();
  _FakeResponse(this._status, this._body);
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
      Stream.fromIterable([_body]).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeRequest implements HttpClientRequest {
  final _FakeResponse _response;
  final _FakeHeaders _hdrs = _FakeHeaders();
  _FakeRequest(this._response);
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
  final int statusCode;
  final List<int> body;
  _FakeHttpClient({this.statusCode = 200, this.body = const []});
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeRequest(_FakeResponse(statusCode, body));
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
  group('HttpNetworkClient logging', () {
    test('null logger produces no overhead — no entries logged on success',
        () async {
      final client = HttpNetworkClient(
        client: _FakeHttpClient(statusCode: 200, body: [65]),
        maxRetries: 1,
        // logger is null by default
      );
      await client.execute(
          const NetworkRequest(url: 'https://x.com', method: NetworkMethod.get));
      // Test simply verifies there is no exception and we can construct without logger.
    });

    test('logger receives info entries for request and response on success',
        () async {
      final logger = _RecordingLogger();
      final client = HttpNetworkClient(
        client: _FakeHttpClient(statusCode: 200, body: [1, 2, 3]),
        maxRetries: 1,
        logger: logger,
      );
      await client.execute(const NetworkRequest(
          url: 'https://example.com/api', method: NetworkMethod.get));

      final messages = logger.entries.map((e) => e.message).toList();
      // Expect a request log and a response log.
      expect(messages.any((m) => m.contains('GET') && m.contains('https://example.com/api')),
          isTrue, reason: 'request should be logged');
      expect(messages.any((m) => m.contains('200') && m.contains('https://example.com/api')),
          isTrue, reason: 'response should be logged');
    });

    test('Authorization header is excluded from request log', () async {
      final logger = _RecordingLogger();
      final client = HttpNetworkClient(
        client: _FakeHttpClient(statusCode: 200, body: []),
        maxRetries: 1,
        logger: logger,
      );
      await client.execute(NetworkRequest(
        url: 'https://example.com/secure',
        method: NetworkMethod.get,
        headers: {'Authorization': 'Bearer secret-token', 'X-Custom': 'value'},
      ));

      final requestLogs = logger.entries
          .where((e) => e.message.contains('GET'))
          .toList();
      expect(requestLogs, isNotEmpty);
      for (final entry in requestLogs) {
        // Neither the message nor metadata should expose the Authorization value.
        final allText = '${entry.message} ${entry.metadata}';
        expect(allText, isNot(contains('secret-token')));
        expect(allText, isNot(contains('Authorization: Bearer')));
      }
    });

    test('logger receives error entry on server error (5xx)', () async {
      final logger = _RecordingLogger();
      final client = HttpNetworkClient(
        client: _FakeHttpClient(statusCode: 500, body: []),
        maxRetries: 1,
        logger: logger,
      );

      await expectLater(
        () => client.execute(const NetworkRequest(
            url: 'https://example.com/fail', method: NetworkMethod.post)),
        throwsA(isA<NetworkError>()),
      );

      expect(logger.entries.any((e) => e.level == LogLevel.error), isTrue,
          reason: 'an error-level log entry should be emitted on 5xx');
    });

    test('body_size metadata is present in response log', () async {
      final logger = _RecordingLogger();
      final client = HttpNetworkClient(
        client: _FakeHttpClient(statusCode: 200, body: [10, 20, 30]),
        maxRetries: 1,
        logger: logger,
      );
      await client.execute(const NetworkRequest(
          url: 'https://example.com', method: NetworkMethod.get));

      final responseLogs = logger.entries
          .where((e) => e.message.contains('200'))
          .toList();
      expect(responseLogs, isNotEmpty);
      expect(responseLogs.first.metadata['body_size'], '3');
    });
  });
}
