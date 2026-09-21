import 'dart:typed_data';

import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryWebSocketProvider — binary send', () {
    late InMemoryWebSocketProvider provider;

    setUp(() async {
      provider = InMemoryWebSocketProvider();
      await provider.connect('ws://localhost');
    });

    tearDown(() async {
      if (provider.connectionState == WebSocketConnectionState.connected) {
        await provider.disconnect();
      }
    });

    // ------------------------------------------------------------------
    // binaryMessages stream — mirrors Android's binaryMessages: Flow<ByteArray>
    // ------------------------------------------------------------------

    group('binaryMessages stream', () {
      test('sendBytes emits Uint8List on binaryMessages', () async {
        final payload = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
        final received = <Uint8List>[];
        final sub = provider.binaryMessages.listen(received.add);

        await provider.sendBytes(payload);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(received, hasLength(1));
        expect(received.first, equals(payload));
      });

      test('binaryMessages does NOT emit text frames', () async {
        final received = <Uint8List>[];
        final sub = provider.binaryMessages.listen(received.add);

        await provider.sendText('hello text');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(received, isEmpty);
      });

      test('multiple binary sends all arrive on binaryMessages in order',
          () async {
        final payloads = [
          Uint8List.fromList([1]),
          Uint8List.fromList([2]),
          Uint8List.fromList([3]),
        ];
        final received = <Uint8List>[];
        final sub = provider.binaryMessages.listen(received.add);

        for (final p in payloads) {
          await provider.sendBytes(p);
        }
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(received, hasLength(3));
        for (var i = 0; i < 3; i++) {
          expect(received[i], equals(payloads[i]));
        }
      });

      test('empty binary frame is emitted on binaryMessages', () async {
        final received = <Uint8List>[];
        final sub = provider.binaryMessages.listen(received.add);

        await provider.sendBytes(Uint8List(0));
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(received, hasLength(1));
        expect(received.first, isEmpty);
      });

      test('mixed text+binary: only binary frames appear on binaryMessages',
          () async {
        final binaryReceived = <Uint8List>[];
        final sub = provider.binaryMessages.listen(binaryReceived.add);

        await provider.sendText('text1');
        await provider.sendBytes(Uint8List.fromList([0xAA]));
        await provider.sendText('text2');
        await provider.sendBytes(Uint8List.fromList([0xBB]));
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(binaryReceived, hasLength(2));
        expect(binaryReceived[0], equals(Uint8List.fromList([0xAA])));
        expect(binaryReceived[1], equals(Uint8List.fromList([0xBB])));
      });

      test('binary frames also appear on the generic messages stream',
          () async {
        final payload = Uint8List.fromList([0x01, 0x02]);
        final allMessages = <dynamic>[];
        final sub = provider.messages.listen(allMessages.add);

        await provider.sendBytes(payload);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(allMessages, hasLength(1));
        expect(allMessages.first, isA<Uint8List>());
        expect(allMessages.first as Uint8List, equals(payload));
      });
    });

    test('send Uint8List binary and receive it via messages stream', () async {
      final payload = Uint8List.fromList([0x00, 0x01, 0xFF, 0xFE]);
      final received = <dynamic>[];
      final sub = provider.messages.listen(received.add);

      await provider.sendBytes(payload);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, hasLength(1));
      final msg = received.first;
      expect(msg, isA<List<dynamic>>());
      expect(List<int>.from(msg as List<dynamic>),
          equals([0x00, 0x01, 0xFF, 0xFE]));
    });

    test('receive binary data via stream matches sent bytes exactly', () async {
      final data =
          Uint8List.fromList(List<int>.generate(256, (i) => i)); // 0x00..0xFF
      final received = <dynamic>[];
      final sub = provider.messages.listen(received.add);

      await provider.sendBytes(data);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, hasLength(1));
      expect(List<int>.from(received.first as List),
          equals(List<int>.generate(256, (i) => i)));
    });

    test('mixed text and binary messages arrive in order', () async {
      final received = <dynamic>[];
      final sub = provider.messages.listen(received.add);

      await provider.sendText('hello');
      await provider.sendBytes(Uint8List.fromList([1, 2, 3]));
      await provider.sendText('world');
      await provider.sendBytes(Uint8List.fromList([4, 5, 6]));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, hasLength(4));
      expect(received[0], isA<String>());
      expect(received[0], 'hello');

      expect(received[1], isA<List<dynamic>>());
      expect(List<int>.from(received[1] as List<dynamic>), [1, 2, 3]);

      expect(received[2], isA<String>());
      expect(received[2], 'world');

      expect(received[3], isA<List<dynamic>>());
      expect(List<int>.from(received[3] as List<dynamic>), [4, 5, 6]);
    });

    test('sendBytes with empty list sends empty binary frame', () async {
      final received = <dynamic>[];
      final sub = provider.messages.listen(received.add);

      await provider.sendBytes(Uint8List(0));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, hasLength(1));
      expect((received.first as List).isEmpty, isTrue);
    });

    test('sendBytes throws StateError when not connected', () async {
      final disconnected = InMemoryWebSocketProvider();
      // Do not connect — should be disconnected by default.
      expect(
        () => disconnected.sendBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<StateError>()),
      );
    });

    test('multiple binary sends are each received individually', () async {
      final received = <dynamic>[];
      final sub = provider.messages.listen(received.add);

      await provider.sendBytes(Uint8List.fromList([10]));
      await provider.sendBytes(Uint8List.fromList([20]));
      await provider.sendBytes(Uint8List.fromList([30]));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, hasLength(3));
      expect((received[0] as List).first, 10);
      expect((received[1] as List).first, 20);
      expect((received[2] as List).first, 30);
    });
  });
}
