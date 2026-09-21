import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Minimal fake HttpClient stack using noSuchMethod for unimplemented members.
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
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HttpNetworkClient', () {
    test('execute returns successful NetworkResponse on 200', () async {
      final fakeHttp = _FakeHttpClient(
        statusCode: 200,
        body: utf8.encode('{"ok":true}'),
      );
      final client = HttpNetworkClient(client: fakeHttp);
      final response = await client.execute(
        const NetworkRequest(
            url: 'https://example.com', method: NetworkMethod.get),
      );
      expect(response.statusCode, 200);
      expect(response.isSuccess, isTrue);
      expect(utf8.decode(response.data), '{"ok":true}');
    });

    test('execute throws NetworkError with serverError code on 500', () async {
      final fakeHttp = _FakeHttpClient(statusCode: 500, body: []);
      // maxRetries=1 so it does not loop forever in test.
      final client = HttpNetworkClient(client: fakeHttp, maxRetries: 1);

      await expectLater(
        () => client.execute(const NetworkRequest(
            url: 'https://example.com', method: NetworkMethod.post)),
        throwsA(isA<NetworkError>()
            .having((e) => e.code, 'code', SyzygyErrorCode.serverError)),
      );
    });

    test('client error (4xx) is returned without throwing', () async {
      final fakeHttp = _FakeHttpClient(statusCode: 404, body: []);
      final client = HttpNetworkClient(client: fakeHttp);
      final response = await client.execute(
        const NetworkRequest(
            url: 'https://example.com', method: NetworkMethod.get),
      );
      expect(response.isClientError, isTrue);
      expect(response.statusCode, 404);
    });

    test('interceptor is called before request is dispatched', () async {
      var intercepted = false;
      final interceptor = _TestInterceptor(() => intercepted = true);
      final fakeHttp = _FakeHttpClient(statusCode: 200, body: []);
      final client = HttpNetworkClient(
        client: fakeHttp,
        interceptors: [interceptor],
      );
      await client.execute(
        const NetworkRequest(
            url: 'https://example.com', method: NetworkMethod.get),
      );
      expect(intercepted, isTrue);
    });

    test('convenience GET returns successful response', () async {
      final fakeHttp = _FakeHttpClient(statusCode: 200, body: []);
      final client = HttpNetworkClient(client: fakeHttp);
      final res = await client.get('https://example.com');
      expect(res.isSuccess, isTrue);
    });

    test('convenience POST sets body and returns success', () async {
      final fakeHttp =
          _FakeHttpClient(statusCode: 200, body: utf8.encode('{}'));
      final client = HttpNetworkClient(client: fakeHttp);
      final res = await client.post('https://example.com', body: {'x': 1});
      expect(res.isSuccess, isTrue);
    });
  });
}

class _TestInterceptor implements RequestInterceptor {
  final void Function() _callback;
  _TestInterceptor(this._callback);

  @override
  Future<NetworkRequest> intercept(NetworkRequest request) async {
    _callback();
    return request;
  }
}
