import 'package:test/test.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';

void main() {
  group('CrashReporter', () {
    test('ConsoleCrashReporter records error without throwing', () {
      final reporter = ConsoleCrashReporter();
      expect(
        () => reporter.recordError(Exception('test'), metadata: {'ctx': 'test'}),
        returnsNormally,
      );
      expect(
        () => reporter.reportCrash('test crash'),
        returnsNormally,
      );
    });
  });
}
