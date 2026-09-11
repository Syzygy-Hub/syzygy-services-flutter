import 'package:test/test.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';

void main() {
  group('StorageProvider', () {
    test('InMemoryStorageProvider round-trips a value', () async {
      final provider = InMemoryStorageProvider();
      await provider.set('key', 'hello');
      expect(await provider.get('key'), 'hello');
      await provider.remove('key');
      expect(await provider.get('key'), isNull);
    });
  });
}
