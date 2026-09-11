import 'package:test/test.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';

void main() {
  group('NetworkClient', () {
    test('HttpNetworkClient initialises without error', () {
      final client = HttpNetworkClient();
      expect(client, isNotNull);
    });
  });
}
