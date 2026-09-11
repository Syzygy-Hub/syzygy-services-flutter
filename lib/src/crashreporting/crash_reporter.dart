/// Defines the contract for crash and non-fatal error reporting.
abstract class CrashReporter {
  /// Reports a fatal crash with the given [message] and optional [metadata].
  void reportCrash(String message, {Map<String, String> metadata = const {}});

  /// Records a non-fatal [error] with optional [metadata].
  void recordError(Object error, {Map<String, String> metadata = const {}});
}

/// A [CrashReporter] that logs crash and error events to the console.
class ConsoleCrashReporter implements CrashReporter {
  @override
  void reportCrash(String message, {Map<String, String> metadata = const {}}) {
    // ignore: avoid_print
    print('[CrashReporter] CRASH: $message $metadata');
  }

  @override
  void recordError(Object error, {Map<String, String> metadata = const {}}) {
    // ignore: avoid_print
    print('[CrashReporter] ERROR: $error $metadata');
  }
}
