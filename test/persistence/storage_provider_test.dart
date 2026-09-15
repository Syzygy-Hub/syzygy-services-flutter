import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  const stringKey = StorageKey<String>('test.string');
  const intKey = StorageKey<int>('test.int', defaultValue: 42);
  const boolKey = StorageKey<bool>('test.bool');

  late InMemoryStorageProvider storage;

  setUp(() => storage = InMemoryStorageProvider());

  group('InMemoryStorageProvider', () {
    test('get returns null for absent key', () {
      expect(storage.get<String>(stringKey), isNull);
    });

    test('set and get roundtrip for String', () {
      storage.set<String>('hello', stringKey);
      expect(storage.get<String>(stringKey), 'hello');
    });

    test('defaultValue returned when key is absent', () {
      expect(storage.get<int>(intKey), 42);
    });

    test('remove deletes the stored value', () {
      storage.set<bool>(true, boolKey);
      storage.remove<bool>(boolKey);
      expect(storage.get<bool>(boolKey), isNull);
    });

    test('clear removes all entries', () {
      storage.set<String>('a', stringKey);
      storage.set<int>(1, intKey);
      storage.clear();
      expect(storage.get<String>(stringKey), isNull);
      expect(storage.get<int>(intKey), 42); // falls back to default
    });

    test('secure namespace is separate from regular namespace', () {
      storage.set<String>('regular', stringKey);
      storage.setSecure<String>('secure', stringKey);
      expect(storage.get<String>(stringKey), 'regular');
      expect(storage.getSecure<String>(stringKey), 'secure');
    });

    test('get throws StateError on type mismatch with descriptive message', () {
      // Store a String but request an int — should throw.
      storage.set<String>('not-an-int', stringKey);
      expect(
        () => storage.get<int>(StorageKey<int>(stringKey.identifier)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains(stringKey.identifier),
              contains('String'),
              contains('int'),
            ),
          ),
        ),
      );
    });

    test('get returns value when type matches', () {
      storage.set<String>('hello', stringKey);
      expect(storage.get<String>(stringKey), 'hello');
    });
  });
}
