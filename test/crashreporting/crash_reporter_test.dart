import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  late ConsoleCrashReporter reporter;

  setUp(() => reporter = ConsoleCrashReporter());

  group('ConsoleCrashReporter', () {
    test('setCustomKey stores metadata', () {
      reporter.setCustomKey('env', 'prod');
      expect(reporter.metadata['env'], 'prod');
    });

    test('multiple custom keys are stored', () {
      reporter.setCustomKey('a', '1');
      reporter.setCustomKey('b', '2');
      expect(reporter.metadata, containsPair('a', '1'));
      expect(reporter.metadata, containsPair('b', '2'));
    });

    test('setUserContext stores userId and email', () {
      reporter.setUserContext(userId: 'u42', email: 'u@example.com');
      expect(reporter.userId, 'u42');
      expect(reporter.email, 'u@example.com');
    });

    test('recordError does not throw', () {
      expect(
        () => reporter.recordError(Exception('oops'),
            stackTrace: StackTrace.current),
        returnsNormally,
      );
    });

    test('recordFatal does not throw (stub)', () {
      expect(
        () => reporter.recordFatal(Exception('fatal'),
            metadata: {'severity': 'high'}),
        returnsNormally,
      );
    });

    test('metadata is unmodifiable', () {
      reporter.setCustomKey('k', 'v');
      expect(() => reporter.metadata['x'] = 'y', throwsA(anything));
    });
  });
}
