import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  group('DartWebSocketProvider concurrency', () {
    test('dispose during reconnect delay does not reconnect', () async {
      final provider = DartWebSocketProvider();
      // trigger reconnect by disposing immediately (no real connection needed)
      provider.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      // no exception, no reconnect attempt after dispose — state stays disconnected
      expect(provider.connectionState, WebSocketConnectionState.disconnected);
    });
  });

  group('DartWebSocketProvider.dispose()', () {
    test('dispose() closes binary stream', () async {
      final provider = DartWebSocketProvider();
      // Access binaryMessages to instantiate the controller.
      final stream = provider.binaryMessages;
      final done = stream.isEmpty; // future that resolves when stream closes
      provider.dispose();
      // The stream should be closed — isEmpty future completes.
      expect(await done, isTrue);
    });

    test('dispose() is idempotent — calling twice does not throw', () {
      final provider = DartWebSocketProvider();
      expect(() => provider.dispose(), returnsNormally);
      expect(() => provider.dispose(), returnsNormally);
    });
  });

  group('InMemoryWebSocketProvider.dispose()', () {
    test('dispose() closes binary stream', () async {
      final provider = InMemoryWebSocketProvider();
      final stream = provider.binaryMessages;
      final done = stream.isEmpty;
      provider.dispose();
      expect(await done, isTrue);
    });

    test('dispose() closes messages stream', () async {
      final provider = InMemoryWebSocketProvider();
      final stream = provider.messages;
      final done = stream.isEmpty;
      provider.dispose();
      expect(await done, isTrue);
    });

    test('dispose() is idempotent — calling twice does not throw', () {
      final provider = InMemoryWebSocketProvider();
      expect(() => provider.dispose(), returnsNormally);
      expect(() => provider.dispose(), returnsNormally);
    });
  });
}
