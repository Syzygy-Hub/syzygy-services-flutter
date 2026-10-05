import 'dart:convert';
import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_client.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HttpNetworkClient', () {
    test('execute returns successful NetworkResponse on 200', () async {
      final fakeHttp = FakeHttpClient(
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
      final fakeHttp = FakeHttpClient(statusCode: 500, body: []);
      // maxRetries=1 so it does not loop forever in test.
      final client = HttpNetworkClient(client: fakeHttp, maxRetries: 1);

      await expectLater(
        () => client.execute(const NetworkRequest(
            url: 'https://example.com', method: NetworkMethod.post)),
        throwsA(isA<HttpNetworkError>()
            .having((e) => e.code, 'code', SyzygyErrorCode.serverError)),
      );
    });

    test('client error (4xx) is returned without throwing', () async {
      final fakeHttp = FakeHttpClient(statusCode: 404, body: []);
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
      final fakeHttp = FakeHttpClient(statusCode: 200, body: []);
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
      final fakeHttp = FakeHttpClient(statusCode: 200, body: []);
      final client = HttpNetworkClient(client: fakeHttp);
      final res = await client.get('https://example.com');
      expect(res.isSuccess, isTrue);
    });

    test('convenience POST sets body and returns success', () async {
      final fakeHttp =
          FakeHttpClient(statusCode: 200, body: utf8.encode('{}'));
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
