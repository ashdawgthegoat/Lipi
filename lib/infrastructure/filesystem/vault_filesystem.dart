import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../../shared/errors/lipi_error.dart';

/// Filesystem abstraction for Lipi Vault operations.
///
/// Follows ADR-0008 Section 10 and IMPLEMENTATION-CONTRACT Section 7 & 22:
/// - Shields domain and application layers from raw filesystem APIs.
/// - Enforces atomic document replacement (write to temp file -> flush -> atomic rename).
class VaultFilesystem {
  final Directory rootDir;

  VaultFilesystem(this.rootDir);

  String get rootPath => rootDir.path;

  /// Resolves relative path segments against the Vault root.
  String resolve(String relativeOrAbsolutePath) {
    if (p.isAbsolute(relativeOrAbsolutePath)) {
      return relativeOrAbsolutePath;
    }
    return p.normalize(p.join(rootDir.path, relativeOrAbsolutePath));
  }

  /// Checks if a file or directory exists.
  Future<bool> exists(String path) async {
    final fullPath = resolve(path);
    return await File(fullPath).exists() || await Directory(fullPath).exists();
  }

  /// Creates directory recursively.
  Future<Directory> createDirectory(String path) async {
    try {
      final dir = Directory(resolve(path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e, st) {
      throw StorageError('Failed to create directory at $path', e, st);
    }
  }

  /// Reads bytes from a file.
  Future<Uint8List> readBytes(String path) async {
    try {
      final file = File(resolve(path));
      if (!await file.exists()) {
        throw StorageError('File does not exist: $path');
      }
      return await file.readAsBytes();
    } catch (e, st) {
      if (e is LipiError) rethrow;
      throw StorageError('Failed to read bytes from $path', e, st);
    }
  }

  /// Writes bytes directly to a file.
  Future<File> writeBytes(String path, Uint8List bytes, {bool flush = true}) async {
    try {
      final file = File(resolve(path));
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      return await file.writeAsBytes(bytes, flush: flush);
    } catch (e, st) {
      throw StorageError('Failed to write bytes to $path', e, st);
    }
  }

  /// Reads string content from a file (UTF-8).
  Future<String> readString(String path) async {
    try {
      final file = File(resolve(path));
      if (!await file.exists()) {
        throw StorageError('File does not exist: $path');
      }
      return await file.readAsString();
    } catch (e, st) {
      if (e is LipiError) rethrow;
      throw StorageError('Failed to read string from $path', e, st);
    }
  }

  /// Writes string content to a file (UTF-8).
  Future<File> writeString(String path, String content, {bool flush = true}) async {
    try {
      final file = File(resolve(path));
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      return await file.writeAsString(content, flush: flush);
    } catch (e, st) {
      throw StorageError('Failed to write string to $path', e, st);
    }
  }

  /// Atomically replaces the target file with [bytes].
  ///
  /// Writes data to a temporary sibling file first, flushes to durable storage,
  /// and atomically renames the temporary file over the destination.
  /// If writing fails at any point prior to commit, the target file remains intact.
  ///
  /// Enforces IMPLEMENTATION-CONTRACT Section 22.
  Future<File> atomicReplace(String path, Uint8List bytes) async {
    final targetFile = File(resolve(path));
    final parent = targetFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final tempFile = File(
      p.join(parent.path, '.tmp_${DateTime.now().microsecondsSinceEpoch}_${p.basename(path)}'),
    );

    try {
      // 1. Write completely to temp file and flush
      await tempFile.writeAsBytes(bytes, flush: true);

      // 2. Atomically rename/replace target
      return await tempFile.rename(targetFile.path);
    } catch (e, st) {
      // Clean up temp file on failure to maintain clean state
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      throw StorageError('Atomic replace failed for $path', e, st);
    }
  }

  /// Deletes a file or directory if it exists.
  Future<void> delete(String path, {bool recursive = false}) async {
    try {
      final fullPath = resolve(path);
      final file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
        return;
      }
      final dir = Directory(fullPath);
      if (await dir.exists()) {
        await dir.delete(recursive: recursive);
      }
    } catch (e, st) {
      throw StorageError('Failed to delete $path', e, st);
    }
  }
}
