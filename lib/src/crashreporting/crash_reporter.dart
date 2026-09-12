/// Abstract contract for crash and non-fatal error reporting.
///
/// Implementations delegate to real crash-reporting SDKs such as Sentry,
/// Firebase Crashlytics, or Datadog.
abstract class CrashReporter {
  /// Records a non-fatal [error] with an optional [stackTrace] and
  /// key-value [metadata].
  void recordError(Object error, {StackTrace? stackTrace,
      Map<String, String> metadata = const {}});

  /// Records a fatal crash. In production this should flush the report and
  /// may not return.
  void recordFatal(Object error, {StackTrace? stackTrace,
      Map<String, String> metadata = const {}});

  /// Associates the current user session with [userId] and optional [email].
  void setUserContext({String? userId, String? email});

  /// Sets an arbitrary key-value pair that is attached to subsequent reports.
  void setCustomKey(String key, String value);
}

/// [CrashReporter] that prints events to the console.
///
/// All metadata is stored in memory so tests can inspect it.
class ConsoleCrashReporter implements CrashReporter {
  final Map<String, String> _metadata = {};
  String? _userId;
  String? _email;

  /// Returns a copy of the currently stored metadata.
  Map<String, String> get metadata => Map.unmodifiable(_metadata);

  /// The userId supplied via [setUserContext], or `null`.
  String? get userId => _userId;

  /// The email supplied via [setUserContext], or `null`.
  String? get email => _email;

  @override
  void recordError(Object error, {StackTrace? stackTrace,
      Map<String, String> metadata = const {}}) {
    final merged = {..._metadata, ...metadata};
    // ignore: avoid_print
    print('[CrashReporter] NON-FATAL: $error\n'
        '  metadata=$merged\n'
        '  user=$_userId\n'
        '  ${stackTrace ?? ''}');
  }

  @override
  void recordFatal(Object error, {StackTrace? stackTrace,
      Map<String, String> metadata = const {}}) {
    final merged = {..._metadata, ...metadata};
    // ignore: avoid_print
    print('[CrashReporter] FATAL: $error\n'
        '  metadata=$merged\n'
        '  user=$_userId\n'
        '  ${stackTrace ?? ''}');
    // Stub — does not terminate the process.
  }

  @override
  void setUserContext({String? userId, String? email}) {
    _userId = userId;
    _email = email;
  }

  @override
  void setCustomKey(String key, String value) {
    _metadata[key] = value;
  }
}
