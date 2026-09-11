import 'dart:io';

/// Defines the contract for file I/O operations.
abstract class FileProvider {
  /// Reads and returns the content of the file at [path].
  Future<List<int>> read(String path);

  /// Writes [data] to the file at [path], creating it if necessary.
  Future<void> write(String path, List<int> data);

  /// Deletes the file at [path].
  Future<void> delete(String path);

  /// Returns true if a file exists at [path].
  bool exists(String path);
}

/// A [FileProvider] backed by [dart:io] [File].
class DartFileProvider implements FileProvider {
  @override
  Future<List<int>> read(String path) => File(path).readAsBytes();

  @override
  Future<void> write(String path, List<int> data) =>
      File(path).writeAsBytes(data);

  @override
  Future<void> delete(String path) => File(path).delete();

  @override
  bool exists(String path) => File(path).existsSync();
}
