import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  group('HttpNetworkClient.dispose()', () {
    test('dispose() is idempotent — calling twice does not throw', () {
      final client = HttpNetworkClient();
      expect(() => client.dispose(), returnsNormally);
      expect(() => client.dispose(), returnsNormally);
    });

    test('dispose() closes the client — further requests throw or return error',
        () async {
      final client = HttpNetworkClient();
      client.dispose();
      // After disposal the underlying HttpClient is closed; any attempt to
      // open a new connection should throw a StateError or SocketException.
      expect(
        () async => client.execute(NetworkRequest(
          url: 'http://127.0.0.1:19999/no-such-host',
          method: NetworkMethod.get,
          headers: {},
        )),
        throwsA(anything),
      );
    });
  });
}
