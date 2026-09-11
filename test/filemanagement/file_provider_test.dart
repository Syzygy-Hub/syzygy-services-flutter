import 'dart:io';
import 'package:test/test.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';

void main() {
  group('FileProvider', () {
    test('DartFileProvider round-trips data', () async {
      final provider = DartFileProvider();
      final dir = Directory.systemTemp;
      final path = '${dir.path}/syzygy-test-${DateTime.now().millisecondsSinceEpoch}.bin';
      final data = [104, 101, 108, 108, 111]; // 'hello'
      await provider.write(path, data);
      expect(provider.exists(path), isTrue);
      final read = await provider.read(path);
      expect(read, data);
      await provider.delete(path);
      expect(provider.exists(path), isFalse);
    });
  });
}
