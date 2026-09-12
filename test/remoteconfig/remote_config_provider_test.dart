import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryRemoteConfigProvider', () {
    test('default value returned when key is absent', () {
      final rc = InMemoryRemoteConfigProvider(defaults: {'feature': true});
      expect(rc.getBool('feature'), isTrue);
    });

    test('getString returns string value', () {
      final rc = InMemoryRemoteConfigProvider(defaults: {'greeting': 'hello'});
      expect(rc.getString('greeting'), 'hello');
    });

    test('getInt returns int value', () {
      final rc = InMemoryRemoteConfigProvider(defaults: {'limit': 10});
      expect(rc.getInt('limit'), 10);
    });

    test('getDouble returns double value', () {
      final rc = InMemoryRemoteConfigProvider(defaults: {'ratio': 0.5});
      expect(rc.getDouble('ratio'), 0.5);
    });

    test('fetch overwrites defaults with remote values', () async {
      final rc = InMemoryRemoteConfigProvider(
        defaults: {'flag': false},
        remoteValues: {'flag': true},
      );
      expect(rc.getBool('flag'), isFalse); // before fetch
      await rc.fetch();
      expect(rc.getBool('flag'), isTrue); // after fetch
    });

    test('lastFetchTime is null before fetch and non-null after', () async {
      final rc = InMemoryRemoteConfigProvider();
      expect(rc.lastFetchTime, isNull);
      await rc.fetch();
      expect(rc.lastFetchTime, isNotNull);
    });

    test('missing key returns null', () {
      final rc = InMemoryRemoteConfigProvider();
      expect(rc.getString('nope'), isNull);
    });
  });
}
