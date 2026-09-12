import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryWebSocketProvider', () {
    late InMemoryWebSocketProvider provider;

    setUp(() => provider = InMemoryWebSocketProvider());

    test('initial state is disconnected', () {
      expect(provider.connectionState, WebSocketConnectionState.disconnected);
    });

    test('connect sets state to connected', () async {
      await provider.connect('ws://localhost');
      expect(provider.connectionState, WebSocketConnectionState.connected);
    });

    test('sendText echoes message on messages stream', () async {
      await provider.connect('ws://localhost');
      final received = <dynamic>[];
      final sub = provider.messages.listen(received.add);

      await provider.sendText('hello');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, contains('hello'));
    });

    test('sendBytes echoes binary data on messages stream', () async {
      await provider.connect('ws://localhost');
      final received = <dynamic>[];
      final sub = provider.messages.listen(received.add);

      await provider.sendBytes([1, 2, 3]);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received.any((e) => e is List && e.length == 3 &&
          e[0] == 1 && e[1] == 2 && e[2] == 3), isTrue);
    });

    test('sendText throws StateError when not connected', () async {
      expect(() => provider.sendText('oops'), throwsA(isA<StateError>()));
    });

    test('disconnect sets state to disconnected', () async {
      await provider.connect('ws://localhost');
      await provider.disconnect();
      expect(provider.connectionState, WebSocketConnectionState.disconnected);
    });
  });
}
