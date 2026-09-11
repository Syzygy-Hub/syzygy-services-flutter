import 'package:test/test.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';

void main() {
  group('WebSocketProvider', () {
    test('DartWebSocketProvider initialises without error', () {
      final provider = DartWebSocketProvider();
      expect(provider, isNotNull);
    });
  });
}
