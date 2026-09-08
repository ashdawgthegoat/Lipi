import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../shared/errors/lipi_error.dart';
import 'lipi_manifest.dart';

class ValidatedPackage {
  final Archive archive;
  final LipiManifest manifest;
  final String inkmlContent;
  final Uint8List? templateBytes;

  const ValidatedPackage({
    required this.archive,
    required this.manifest,
    required this.inkmlContent,
    this.templateBytes,
  });
}

/// Strict package validator for .lipi document packages.
///
/// Follows ADR-0008 Section 7 and Section 23 (Fail-Closed):
/// When validity cannot be established, the document must be rejected.
class LipiPackageValidator {
  /// Validates a raw .lipi ZIP archive and extracts verified package components.
  static ValidatedPackage validate(Uint8List zipBytes) {
    if (zipBytes.isEmpty) {
      throw const DocumentError('Empty .lipi package bytes');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e, st) {
      throw DocumentError('Corrupted or invalid ZIP archive for .lipi package', e, st);
    }

    // 1. Verify exactly one manifest.json
    final manifestEntries = archive.files.where((f) => f.name == 'manifest.json').toList();
    if (manifestEntries.isEmpty) {
      throw const DocumentError('Invalid .lipi package: manifest.json is missing');
    }
    if (manifestEntries.length > 1) {
      throw const DocumentError('Invalid .lipi package: multiple manifest.json entries found');
    }

    final manifestFile = manifestEntries.first;
    final Map<String, dynamic> manifestMap;
    try {
      final jsonStr = utf8.decode(manifestFile.content as List<int>);
      manifestMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e, st) {
      throw DocumentError('Malformed manifest.json in .lipi package', e, st);
    }

    final LipiManifest manifest;
    try {
      manifest = LipiManifest.fromJson(manifestMap);
      manifest.validate();
    } catch (e, st) {
      if (e is LipiError) rethrow;
      throw DocumentError('Invalid manifest structure in .lipi package', e, st);
    }

    // 2. Verify referenced ink file exists
    final inkFile = archive.findFile(manifest.ink);
    if (inkFile == null) {
      throw DocumentError('Referenced ink file "${manifest.ink}" is missing from .lipi package');
    }

    final String inkmlContent;
    try {
      inkmlContent = utf8.decode(inkFile.content as List<int>);
    } catch (e, st) {
      throw DocumentError('Failed to read ink file "${manifest.ink}"', e, st);
    }

    // 3. Verify custom template image if specified in snapshot
    Uint8List? templateBytes;
    final templateImageFile = manifest.doctorSnapshot?.templateImageFile;
    if (templateImageFile != null && templateImageFile.isNotEmpty) {
      final imgEntry = archive.findFile(templateImageFile);
      if (imgEntry == null) {
        throw DocumentError('Referenced template file "$templateImageFile" is missing from .lipi package');
      }
      templateBytes = Uint8List.fromList(imgEntry.content as List<int>);
    }

    return ValidatedPackage(
      archive: archive,
      manifest: manifest,
      inkmlContent: inkmlContent,
      templateBytes: templateBytes,
    );
  }
}
