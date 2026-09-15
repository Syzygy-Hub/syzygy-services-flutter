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

    test('leaveBreadcrumb stores a breadcrumb', () {
      reporter.leaveBreadcrumb('user tapped button');
      expect(reporter.breadcrumbs, hasLength(1));
      expect(reporter.breadcrumbs.first.message, 'user tapped button');
    });

    test('leaveBreadcrumb with metadata stores metadata', () {
      reporter.leaveBreadcrumb('action', metadata: {'screen': 'home'});
      expect(reporter.breadcrumbs.first.metadata['screen'], 'home');
    });

    test('clearBreadcrumbs removes all breadcrumbs', () {
      reporter.leaveBreadcrumb('a');
      reporter.leaveBreadcrumb('b');
      reporter.clearBreadcrumbs();
      expect(reporter.breadcrumbs, isEmpty);
    });
  });

  group('InMemoryCrashReporter', () {
    late InMemoryCrashReporter inMemory;

    setUp(() => inMemory = InMemoryCrashReporter());

    test('leaveBreadcrumb stores breadcrumbs up to 20', () {
      for (var i = 0; i < 25; i++) {
        inMemory.leaveBreadcrumb('crumb $i');
      }
      expect(inMemory.breadcrumbs, hasLength(20));
      // Oldest 5 should have been evicted; the first kept is 'crumb 5'.
      expect(inMemory.breadcrumbs.first.message, 'crumb 5');
    });

    test('breadcrumbs circular buffer keeps most recent 20', () {
      for (var i = 0; i < 22; i++) {
        inMemory.leaveBreadcrumb('b$i');
      }
      expect(inMemory.breadcrumbs.length, 20);
      expect(inMemory.breadcrumbs.last.message, 'b21');
    });

    test('clearBreadcrumbs empties the buffer', () {
      inMemory.leaveBreadcrumb('x');
      inMemory.clearBreadcrumbs();
      expect(inMemory.breadcrumbs, isEmpty);
    });

    test('recordError includes breadcrumbs in the report', () {
      inMemory.leaveBreadcrumb('nav to settings');
      inMemory.recordError(Exception('oops'));
      final report = inMemory.errors.first;
      final crumbs = report['breadcrumbs'] as List<Breadcrumb>;
      expect(crumbs, hasLength(1));
      expect(crumbs.first.message, 'nav to settings');
    });

    test('recordFatal includes breadcrumbs in the report', () {
      inMemory.leaveBreadcrumb('startup');
      inMemory.recordFatal(Error());
      final report = inMemory.fatals.first;
      final crumbs = report['breadcrumbs'] as List<Breadcrumb>;
      expect(crumbs.first.message, 'startup');
    });

    test('breadcrumbs snapshot is taken at time of recordError', () {
      inMemory.leaveBreadcrumb('before');
      inMemory.recordError(Exception('e'));
      inMemory.leaveBreadcrumb('after');
      final crumbs = inMemory.errors.first['breadcrumbs'] as List<Breadcrumb>;
      expect(crumbs, hasLength(1));
      expect(crumbs.first.message, 'before');
    });

    test('recordError does not throw', () {
      expect(() => inMemory.recordError(Exception('e')), returnsNormally);
    });

    test('recordFatal does not throw (stub)', () {
      expect(() => inMemory.recordFatal(Error()), returnsNormally);
    });
  });
}
