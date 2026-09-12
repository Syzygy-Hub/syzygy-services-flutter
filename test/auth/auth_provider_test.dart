import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

// A JWT whose exp is in the year 2030 (unix 1893456000).
// Header.Payload.Signature — only payload matters for expiry detection.
// payload JSON: {"sub":"1","exp":1893456000}
const _validJwt =
    'eyJhbGciOiJIUzI1NiJ9'
    '.eyJzdWIiOiIxIiwiZXhwIjoxODkzNDU2MDAwfQ'
    '.signature';

// A JWT whose exp is in 2000 (unix 946684800) — always expired.
// payload JSON: {"sub":"1","exp":946684800}
const _expiredJwt =
    'eyJhbGciOiJIUzI1NiJ9'
    '.eyJzdWIiOiIxIiwiZXhwIjo5NDY2ODQ4MDB9'
    '.signature';

void main() {
  late InMemoryStorageProvider storage;
  late TokenAuthProvider auth;

  setUp(() {
    storage = InMemoryStorageProvider();
    auth = TokenAuthProvider(storage);
  });

  tearDown(() => auth.dispose());

  group('TokenAuthProvider', () {
    test('initial state is Unauthenticated', () {
      expect(auth.state, isA<Unauthenticated>());
    });

    test('authenticate transitions state to Authenticated', () {
      const token = AuthToken(accessToken: _validJwt);
      auth.authenticate(token);
      expect(auth.state, isA<Authenticated>());
      expect((auth.state as Authenticated).token.accessToken, _validJwt);
    });

    test('signOut transitions state back to Unauthenticated', () {
      auth.authenticate(const AuthToken(accessToken: _validJwt));
      auth.signOut();
      expect(auth.state, isA<Unauthenticated>());
    });

    test('state stream emits on authenticate and signOut', () async {
      final states = <AuthState>[];
      final sub = auth.stateStream.listen(states.add);

      auth.authenticate(const AuthToken(accessToken: _validJwt));
      auth.signOut();

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states.length, 2);
      expect(states[0], isA<Authenticated>());
      expect(states[1], isA<Unauthenticated>());
    });

    test('token is persisted to storage on authenticate', () {
      const key = StorageKey<String>('auth.accessToken');
      auth.authenticate(const AuthToken(accessToken: _validJwt));
      expect(storage.getSecure<String>(key), _validJwt);
    });

    test('jwtIsExpired returns false for future exp', () {
      expect(jwtIsExpired(_validJwt), isFalse);
    });

    test('jwtIsExpired returns true for past exp', () {
      expect(jwtIsExpired(_expiredJwt), isTrue);
    });
  });
}
