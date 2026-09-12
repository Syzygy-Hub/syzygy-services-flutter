import 'dart:io';
import 'dart:typed_data';

/// Abstract contract for file-system I/O operations.
///
/// Implementations may target the real file system, an in-memory layer,
/// or a sandboxed environment.
abstract class FileProvider {
  /// Reads the file at [path] and returns its bytes.
  Future<Uint8List> readBytes(String path);

  /// Writes [data] to the file at [path], creating it if necessary.
  Future<void> writeBytes(String path, Uint8List data);

  /// Deletes the file at [path].
  Future<void> delete(String path);

  /// Returns `true` if a file exists at [path].
  bool exists(String path);

  /// Creates a directory at [path], including any missing ancestors.
  Future<void> createDirectory(String path);

  /// Deletes the directory at [path] and all its contents.
  Future<void> deleteDirectory(String path);

  /// Copies the file at [source] to [destination].
  Future<void> copy(String source, String destination);

  /// Moves the file at [source] to [destination].
  Future<void> move(String source, String destination);

  /// Returns the path of the system temporary directory.
  String get tempDirectoryPath;
}

/// [FileProvider] backed by [dart:io] — reads and writes the real file system.
class IoFileProvider implements FileProvider {
  @override
  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  @override
  Future<void> writeBytes(String path, Uint8List data) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data, flush: true);
  }

  @override
  Future<void> delete(String path) => File(path).delete();

  @override
  bool exists(String path) => File(path).existsSync();

  @override
  Future<void> createDirectory(String path) =>
      Directory(path).create(recursive: true);

  @override
  Future<void> deleteDirectory(String path) =>
      Directory(path).delete(recursive: true);

  @override
  Future<void> copy(String source, String destination) =>
      File(source).copy(destination);

  @override
  Future<void> move(String source, String destination) =>
      File(source).rename(destination);

  @override
  String get tempDirectoryPath => Directory.systemTemp.path;
}
