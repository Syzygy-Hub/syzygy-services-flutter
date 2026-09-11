import 'package:test/test.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';

void main() {
  group('RemoteConfigProvider', () {
    test('InMemoryRemoteConfigProvider round-trips string and bool', () {
      final provider = InMemoryRemoteConfigProvider();
      provider.setValue('greeting', 'world');
      provider.setValue('flag', true);
      expect(provider.getString('greeting'), 'world');
      expect(provider.getBoolean('flag'), isTrue);
      expect(provider.getString('missing'), isNull);
    });
  });
}
