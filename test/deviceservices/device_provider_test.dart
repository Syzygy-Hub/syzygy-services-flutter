import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryStorageProvider storage;
  late IoDeviceProvider device;

  setUp(() {
    storage = InMemoryStorageProvider();
    device = IoDeviceProvider(storage);
  });

  group('IoDeviceProvider', () {
    test('platform is "flutter"', () {
      expect(device.platform, 'flutter');
    });

    test('osVersion is non-empty', () {
      expect(device.osVersion, isNotEmpty);
    });

    test('appVersion is non-empty', () {
      expect(device.appVersion, isNotEmpty);
    });

    test('deviceId is a non-empty UUID-like string', () {
      final id = device.deviceId;
      expect(id, isNotEmpty);
      // UUID format: 8-4-4-4-12
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(id), isTrue);
    });

    test('deviceId is stable across multiple calls', () {
      final id1 = device.deviceId;
      final id2 = device.deviceId;
      expect(id1, id2);
    });

    test('deviceId persists in storage between provider instances', () {
      final id1 = device.deviceId;
      // Create a new provider backed by the same storage.
      final device2 = IoDeviceProvider(storage);
      expect(device2.deviceId, id1);
    });
  });
}
