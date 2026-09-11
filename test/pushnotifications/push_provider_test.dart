import 'package:test/test.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';

void main() {
  group('PushProvider', () {
    test('InMemoryPushProvider stores token', () {
      final provider = InMemoryPushProvider();
      expect(provider.deviceToken, isNull);
      provider.registerToken('my-token');
      expect(provider.deviceToken, 'my-token');
    });
  });
}
