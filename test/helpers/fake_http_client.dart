import 'dart:async';
import 'dart:io';

// ---------------------------------------------------------------------------
// Shared fake HttpClient stack for use across test files.
// ---------------------------------------------------------------------------

class FakeHttpHeaders implements HttpHeaders {
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

class FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final int _status;
  final List<int> _body;
  final FakeHttpHeaders _hdrs = FakeHttpHeaders();

  FakeHttpClientResponse(this._status, this._body);

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

class FakeHttpClientRequest implements HttpClientRequest {
  final FakeHttpClientResponse _response;
  final FakeHttpHeaders _hdrs = FakeHttpHeaders();

  FakeHttpClientRequest(this._response);

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

class FakeHttpClient implements HttpClient {
  final int statusCode;
  final List<int> body;

  FakeHttpClient({this.statusCode = 200, this.body = const []});

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      FakeHttpClientRequest(FakeHttpClientResponse(statusCode, body));

  @override
  set connectionTimeout(Duration? v) {}

  @override
  Duration? get connectionTimeout => null;

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
