import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryPushProvider provider;

  setUp(() => provider = InMemoryPushProvider());
  tearDown(() => provider.dispose());

  group('InMemoryPushProvider', () {
    test('requestPermission returns true', () async {
      expect(await provider.requestPermission(), isTrue);
    });

    test('deviceToken is null before registration', () {
      expect(provider.deviceToken, isNull);
    });

    test('registerToken stores the token', () {
      provider.registerToken('abc123');
      expect(provider.deviceToken, 'abc123');
    });

    test('unregisterToken clears the token', () {
      provider.registerToken('abc123');
      provider.unregisterToken();
      expect(provider.deviceToken, isNull);
    });

    test('handleNotification emits on onNotification stream', () async {
      final payloads = <NotificationPayload>[];
      final sub = provider.onNotification.listen(payloads.add);

      final payload = NotificationPayload(
        title: 'Hello',
        body: 'World',
        data: {'key': 'value'},
      );
      provider.handleNotification(payload);

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(payloads.length, 1);
      expect(payloads.first.title, 'Hello');
      expect(payloads.first.data['key'], 'value');
    });

    test('multiple registrations overwrite previous token', () {
      provider.registerToken('first');
      provider.registerToken('second');
      expect(provider.deviceToken, 'second');
    });
  });
}
