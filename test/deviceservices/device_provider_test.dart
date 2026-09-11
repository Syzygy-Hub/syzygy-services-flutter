import 'package:test/test.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';

void main() {
  group('DeviceProvider', () {
    test('PlatformDeviceProvider returns non-empty values', () {
      final provider = PlatformDeviceProvider();
      expect(provider.operatingSystem, isNotEmpty);
      expect(provider.operatingSystemVersion, isNotEmpty);
    });
  });
}
