import 'package:test/test.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';

void main() {
  group('AnalyticsProvider', () {
    test('ConsoleAnalyticsProvider tracks event without throwing', () {
      final provider = ConsoleAnalyticsProvider();
      expect(() => provider.track('test_event', properties: {'key': 'value'}), returnsNormally);
    });
  });
}
