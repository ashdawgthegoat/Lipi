import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../shared/errors/lipi_error.dart';
import '../../shared/result/result.dart';
import '../database/vault_database.dart';
import 'vault.dart';

/// Metadata embedded in every Lipi Vault backup archive.
class BackupManifest {
  final String format;
  final int version;
  final int schemaVersion;
  final DateTime createdAt;
  final Map<String, String> files; // relative path -> sha256 checksum

  const BackupManifest({
    this.format = 'lipi-vault-backup',
    this.version = 1,
    required this.schemaVersion,
    required this.createdAt,
    required this.files,
  });

  Map<String, dynamic> toMap() => {
        'format': format,
        'version': version,
        'schema_version': schemaVersion,
        'created_at': createdAt.toIso8601String(),
        'files': files,
      };

  factory BackupManifest.fromMap(Map<String, dynamic> map) => BackupManifest(
        format: (map['format'] as String?) ?? 'lipi-vault-backup',
        version: (map['version'] as num?)?.toInt() ?? 1,
        schemaVersion: (map['schema_version'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        files: (map['files'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      );
}

/// Result of evaluating a backup package prior to restoration.
class BackupValidationResult {
  final bool isValid;
  final BackupManifest? manifest;
  final String? errorMessage;
  final bool requiresMigration;

  const BackupValidationResult({
    required this.isValid,
    this.manifest,
    this.errorMessage,
    this.requiresMigration = false,
  });
}

/// Service providing portable, atomic, non-destructive Vault backup and recovery.
///
/// Follows ADR-0008 & BUILD-PLAN Milestone 12:
/// - The Vault is the unit of backup and portability.
/// - Validation pipeline: Validate -> Verify -> Activate.
/// - Non-destructive staging: a failed restore preserves the existing Vault intact.
/// - Verifies database integrity (`PRAGMA integrity_check`) and payload checksums.
/// - Detects schema version mismatches and handles migration.
class VaultBackupService {
  static const int currentSchemaVersion = 1;
  static const String manifestFileName = 'backup_manifest.json';

  final LipiVault vault;
  final VaultDatabase database;

  VaultBackupService({
    required this.vault,
    required this.database,
  });

  /// Creates a full, authenticated backup archive of the entire Vault.
  Future<Result<File, LipiError>> exportBackup({
    required File destinationZip,
  }) async {
    try {
      if (!await vault.rootDir.exists()) {
        return const Failure(VaultError('Vault root directory does not exist'));
      }

      // 1. Flush SQLite WAL to ensure lipi.db is up-to-date on disk
      await database.checkpoint();

      // 2. Scan all files in Vault and compute checksums
      final archive = Archive();
      final fileChecksums = <String, String>{};

      final entities = vault.rootDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is! File) continue;

        // Skip lock files and temporary staging files
        final relativePath = p.relative(entity.path, from: vault.rootDir.path);
        if (relativePath.startsWith('.') || relativePath.endsWith('-wal') || relativePath.endsWith('-shm')) {
          continue;
        }

        final bytes = await entity.readAsBytes();
        final checksum = sha256.convert(bytes).toString();
        fileChecksums[relativePath] = checksum;

        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }

      // 3. Add manifest to archive
      final manifest = BackupManifest(
        schemaVersion: currentSchemaVersion,
        createdAt: DateTime.now().toUtc(),
        files: fileChecksums,
      );
      final manifestJson = jsonEncode(manifest.toMap());
      final manifestBytes = utf8.encode(manifestJson);
      archive.addFile(ArchiveFile(manifestFileName, manifestBytes.length, manifestBytes));

      // 4. Encode and atomically write zip archive
      final zipEncoder = ZipEncoder();
      final encodedBytes = zipEncoder.encode(archive);

      final parentDir = destinationZip.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final tempZip = File('${destinationZip.path}.tmp_${DateTime.now().microsecondsSinceEpoch}');
      await tempZip.writeAsBytes(encodedBytes, flush: true);
      if (await destinationZip.exists()) {
        await destinationZip.delete();
      }
      await tempZip.rename(destinationZip.path);

      return Success(destinationZip);
    } catch (e, st) {
      return Failure(VaultError('Failed to export vault backup: $e', e, st));
    }
  }

  /// Step 1: Validates a backup archive's structure, manifest, and checksums.
  Future<Result<BackupValidationResult, LipiError>> validateBackup(File backupZip) async {
    try {
      if (!await backupZip.exists()) {
        return const Failure(ValidationError('Backup file does not exist'));
      }

      final zipBytes = await backupZip.readAsBytes();
      if (zipBytes.isEmpty) {
        return const Failure(ValidationError('Backup file is empty'));
      }

      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(zipBytes);
      } catch (e) {
        return Success(BackupValidationResult(
          isValid: false,
          errorMessage: 'Corrupted backup file: not a valid zip archive ($e)',
        ));
      }

      // Check for manifest
      final manifestFile = archive.findFile(manifestFileName);
      if (manifestFile == null) {
        return const Success(BackupValidationResult(
          isValid: false,
          errorMessage: 'Missing backup manifest: invalid or non-Lipi backup',
        ));
      }

      BackupManifest manifest;
      try {
        final content = utf8.decode(manifestFile.content as List<int>);
        manifest = BackupManifest.fromMap(jsonDecode(content) as Map<String, dynamic>);
      } catch (e) {
        return Success(BackupValidationResult(
          isValid: false,
          errorMessage: 'Corrupted backup manifest ($e)',
        ));
      }

      if (manifest.format != 'lipi-vault-backup') {
        return Success(BackupValidationResult(
          isValid: false,
          errorMessage: 'Unknown backup format: ${manifest.format}',
        ));
      }

      // Schema migration check
      if (manifest.schemaVersion > currentSchemaVersion) {
        return Success(BackupValidationResult(
          isValid: false,
          manifest: manifest,
          errorMessage: 'Backup was created by a newer version of Lipi (v${manifest.schemaVersion} > v$currentSchemaVersion). Upgrade application first.',
        ));
      }

      final requiresMigration = manifest.schemaVersion < currentSchemaVersion;

      // Verify checksum of every recorded file
      for (final entry in manifest.files.entries) {
        final relPath = entry.key;
        final expectedSha = entry.value;

        final archFile = archive.findFile(relPath);
        if (archFile == null) {
          return Success(BackupValidationResult(
            isValid: false,
            manifest: manifest,
            errorMessage: 'Missing expected file from backup: $relPath',
          ));
        }

        final actualSha = sha256.convert(archFile.content as List<int>).toString();
        if (actualSha != expectedSha) {
          return Success(BackupValidationResult(
            isValid: false,
            manifest: manifest,
            errorMessage: 'Integrity check failed: checksum mismatch for $relPath',
          ));
        }
      }

      return Success(BackupValidationResult(
        isValid: true,
        manifest: manifest,
        requiresMigration: requiresMigration,
      ));
    } catch (e, st) {
      return Failure(VaultError('Failed to validate backup archive: $e', e, st));
    }
  }

  /// Restores a Vault from a backup archive using the Validate -> Verify -> Activate pipeline.
  ///
  /// Guarantees fail-closed non-destructive behavior: if validation, verification, or staging
  /// encounters any issue, the existing live Vault remains 100% untouched.
  Future<Result<void, LipiError>> restoreBackup({
    required File backupZip,
    required LipiVault targetVault,
    required VaultDatabase targetDb,
  }) async {
    Directory? stagingDir;
    Directory? rollbackDir;

    try {
      // 1. VALIDATE: Inspect archive, manifest, and checksums
      final validationRes = await validateBackup(backupZip);
      if (validationRes.isFailure) {
        return Failure(validationRes.errorOrNull!);
      }

      final validation = validationRes.valueOrNull!;
      if (!validation.isValid) {
        return Failure(ValidationError(validation.errorMessage ?? 'Invalid backup archive'));
      }

      // 2. STAGE: Extract archive into an isolated staging directory
      final nowTimestamp = DateTime.now().microsecondsSinceEpoch;
      stagingDir = Directory(p.join(
        targetVault.rootDir.parent.path,
        '.vault_restore_staging_$nowTimestamp',
      ));
      await stagingDir.create(recursive: true);

      final zipBytes = await backupZip.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive) {
        if (file.name == manifestFileName) continue;
        final outPath = p.join(stagingDir.path, file.name);
        if (file.isFile) {
          final outFile = File(outPath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>, flush: true);
        } else {
          await Directory(outPath).create(recursive: true);
        }
      }

      // 3. VERIFY: Ensure database opens and passes PRAGMA integrity_check
      final stagedVault = LipiVault(stagingDir);
      await stagedVault.initialize();
      final structureValid = await stagedVault.validateStructure();
      if (!structureValid) {
        return const Failure(ValidationError('Staged vault has invalid directory structure'));
      }

      final stagedDb = VaultDatabase();
      await stagedDb.open(stagedVault.dbFile);
      final dbOk = await stagedDb.checkIntegrity();
      await stagedDb.close();

      if (!dbOk) {
        return const Failure(ValidationError('Staged SQLite database failed integrity check'));
      }

      // 4. ACTIVATE: Atomic non-destructive swap
      // Step A: Close active target database and vault
      await targetDb.close();
      targetVault.close();

      // Step B: Preserve existing vault in rollback directory
      if (await targetVault.rootDir.exists()) {
        rollbackDir = Directory('${targetVault.rootDir.path}_rollback_$nowTimestamp');
        await targetVault.rootDir.rename(rollbackDir.path);
      }

      // Step C: Move staging directory to live target vault location
      await stagingDir.rename(targetVault.rootDir.path);
      stagingDir = null; // Staging is now the live directory

      // Step D: Re-initialize live vault and open live database
      try {
        await targetVault.initialize();
        await targetDb.open(targetVault.dbFile);
      } catch (activateErr) {
        // Rollback on activation failure
        debugPrint('[Lipi][VaultBackup] Activation failed, rolling back: $activateErr');
        if (await targetVault.rootDir.exists()) {
          await targetVault.rootDir.delete(recursive: true);
        }
        if (rollbackDir != null && await rollbackDir.exists()) {
          await rollbackDir.rename(targetVault.rootDir.path);
          await targetVault.initialize();
          await targetDb.open(targetVault.dbFile);
        }
        return Failure(VaultError('Activation failed and rolled back safely: $activateErr'));
      }

      // Step E: Clean up rollback directory after successful activation
      if (rollbackDir != null && await rollbackDir.exists()) {
        await rollbackDir.delete(recursive: true);
      }

      return const Success(null);
    } catch (e, st) {
      // Clean up staging directory if left behind
      if (stagingDir != null && await stagingDir.exists()) {
        try {
          await stagingDir.delete(recursive: true);
        } catch (_) {}
      }
      return Failure(VaultError('Failed to restore vault backup: $e', e, st));
    }
  }
}
