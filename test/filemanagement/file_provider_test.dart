import 'dart:io';
import 'dart:typed_data';

import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  late IoFileProvider provider;
  late Directory tempDir;

  setUp(() async {
    provider = IoFileProvider();
    tempDir = await Directory.systemTemp.createTemp('file_provider_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  String p(String name) => '${tempDir.path}/$name';

  group('IoFileProvider', () {
    test('write and read roundtrip', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      await provider.writeBytes(p('test.bin'), data);
      final read = await provider.readBytes(p('test.bin'));
      expect(read, data);
    });

    test('exists returns true after write', () async {
      await provider.writeBytes(p('exists.txt'), Uint8List.fromList([65]));
      expect(provider.exists(p('exists.txt')), isTrue);
    });

    test('exists returns false for absent file', () {
      expect(provider.exists(p('nope.txt')), isFalse);
    });

    test('delete removes file', () async {
      await provider.writeBytes(p('del.txt'), Uint8List.fromList([1]));
      await provider.delete(p('del.txt'));
      expect(provider.exists(p('del.txt')), isFalse);
    });

    test('copy creates a duplicate', () async {
      final data = Uint8List.fromList([9, 8, 7]);
      await provider.writeBytes(p('src.bin'), data);
      await provider.copy(p('src.bin'), p('dst.bin'));
      expect(provider.exists(p('dst.bin')), isTrue);
      expect(await provider.readBytes(p('dst.bin')), data);
    });

    test('move renames file', () async {
      await provider.writeBytes(p('before.txt'), Uint8List.fromList([1]));
      await provider.move(p('before.txt'), p('after.txt'));
      expect(provider.exists(p('before.txt')), isFalse);
      expect(provider.exists(p('after.txt')), isTrue);
    });

    test('createDirectory creates nested directories', () async {
      final nested = '${tempDir.path}/a/b/c';
      await provider.createDirectory(nested);
      expect(Directory(nested).existsSync(), isTrue);
    });

    test('tempDirectoryPath is non-empty', () {
      expect(provider.tempDirectoryPath, isNotEmpty);
    });
  });
}
