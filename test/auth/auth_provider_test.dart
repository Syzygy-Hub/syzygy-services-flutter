import 'package:test/test.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';

void main() {
  group('AuthProvider', () {
    test('JWTAuthProvider stores and clears token', () {
      final provider = JWTAuthProvider();
      expect(provider.accessToken, isNull);
      provider.storeToken('tok123');
      expect(provider.accessToken, 'tok123');
      provider.clearToken();
      expect(provider.accessToken, isNull);
    });
  });
}
