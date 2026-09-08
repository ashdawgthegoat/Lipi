import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:lipi/domains/doctor/models/doctor_profile.dart';
import 'package:lipi/domains/patient/models/patient.dart';
import 'package:lipi/domains/patient/models/patient_info.dart';
import 'package:lipi/infrastructure/database/sqlite_doctor_repository.dart';
import 'package:lipi/infrastructure/database/sqlite_patient_repository.dart';
import 'package:lipi/infrastructure/database/vault_database.dart';
import 'package:lipi/infrastructure/vault/vault.dart';
import 'package:lipi/infrastructure/vault/vault_backup_service.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VaultDatabase.initializeFfiIfRequired();

  late Directory tempBaseDir;
  late Directory vaultDir;
  late LipiVault vault;
  late VaultDatabase db;
  late VaultBackupService backupService;

  setUp(() async {
    tempBaseDir = await Directory.systemTemp.createTemp('lipi_backup_test_');
    vaultDir = Directory(p.join(tempBaseDir.path, 'vault'));
    vault = LipiVault(vaultDir);
    await vault.initialize();

    db = VaultDatabase();
    await db.open(vault.dbFile);

    // Populate some initial clinical data
    final docRepo = SqliteDoctorRepository(db);
    await docRepo.saveProfile(DoctorProfile(
      id: const DoctorId('doc-1'),
      name: 'Dr. Arjun Verma',
      clinicName: 'Verma Heart Care',
      qualifications: 'MBBS, MD',
      regNumber: 'MCI-998811',
    ));

    final patientRepo = SqlitePatientRepository(db);
    final now = DateTime.now().toUtc();
    await patientRepo.createPatient(Patient(
      id: PatientId('pat-1'),
      info: const PatientInfo(
        name: 'Ramesh Patel',
        age: 48,
        gender: 'Male',
        city: 'Ahmedabad',
      ),
      createdAt: now,
      updatedAt: now,
    ));

    backupService = VaultBackupService(vault: vault, database: db);
  });

  tearDown(() async {
    await db.close();
    vault.close();
    if (await tempBaseDir.exists()) {
      await tempBaseDir.delete(recursive: true);
    }
  });

  group('Milestone 12 — Vault Backup, Transfer, Migration, and Recovery', () {
    test('exportBackup creates valid zip archive with manifest and file checksums', () async {
      final backupZip = File(p.join(tempBaseDir.path, 'export_test.zip'));
      final exportRes = await backupService.exportBackup(destinationZip: backupZip);

      expect(exportRes.isSuccess, isTrue);
      expect(await backupZip.exists(), isTrue);
      expect(await backupZip.length(), greaterThan(0));

      // Read archive and verify manifest
      final bytes = await backupZip.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final manifestFile = archive.findFile('backup_manifest.json');
      expect(manifestFile, isNotNull);

      final manifest = BackupManifest.fromMap(
        jsonDecode(utf8.decode(manifestFile!.content as List<int>)) as Map<String, dynamic>,
      );
      expect(manifest.format, equals('lipi-vault-backup'));
      expect(manifest.schemaVersion, equals(VaultBackupService.currentSchemaVersion));
      expect(manifest.files.containsKey('lipi.db'), isTrue);
    });

    test('validateBackup succeeds on intact backup archive', () async {
      final backupZip = File(p.join(tempBaseDir.path, 'valid_backup.zip'));
      await backupService.exportBackup(destinationZip: backupZip);

      final valRes = await backupService.validateBackup(backupZip);
      expect(valRes.isSuccess, isTrue);

      final validation = valRes.valueOrNull!;
      expect(validation.isValid, isTrue);
      expect(validation.errorMessage, isNull);
      expect(validation.manifest, isNotNull);
      expect(validation.manifest!.schemaVersion, equals(1));
    });

    test('validateBackup fails on corrupted zip file', () async {
      final corruptZip = File(p.join(tempBaseDir.path, 'corrupt.zip'));
      await corruptZip.writeAsString('THIS IS NOT A VALID ZIP FILE');

      final valRes = await backupService.validateBackup(corruptZip);
      expect(valRes.isSuccess, isTrue);
      expect(valRes.valueOrNull!.isValid, isFalse);
      expect(valRes.valueOrNull!.errorMessage, isNotNull);
    });

    test('validateBackup fails on missing expected file (incomplete transfer)', () async {
      final backupZip = File(p.join(tempBaseDir.path, 'incomplete.zip'));
      await backupService.exportBackup(destinationZip: backupZip);

      // Create an archive that modifies the manifest to require a file that does not exist
      final origBytes = await backupZip.readAsBytes();
      final origArchive = ZipDecoder().decodeBytes(origBytes);

      final manifestFile = origArchive.findFile('backup_manifest.json')!;
      final manifestMap = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
      final filesMap = (manifestMap['files'] as Map<String, dynamic>);
      filesMap['doctor/missing_letterhead.png'] = '112233445566778899aabbccddeeff';

      final newArchive = Archive();
      for (final f in origArchive) {
        if (f.name == 'backup_manifest.json') {
          final newManifestBytes = utf8.encode(jsonEncode(manifestMap));
          newArchive.addFile(ArchiveFile('backup_manifest.json', newManifestBytes.length, newManifestBytes));
        } else {
          newArchive.addFile(f);
        }
      }

      final tamperedZip = File(p.join(tempBaseDir.path, 'tampered_missing.zip'));
      await tamperedZip.writeAsBytes(ZipEncoder().encode(newArchive));

      final valRes = await backupService.validateBackup(tamperedZip);
      expect(valRes.isSuccess, isTrue);
      expect(valRes.valueOrNull!.isValid, isFalse);
      expect(valRes.valueOrNull!.errorMessage, contains('Missing expected file'));
    });

    test('validateBackup fails on checksum mismatch (tampered/corrupted file)', () async {
      final backupZip = File(p.join(tempBaseDir.path, 'tampered_data.zip'));
      await backupService.exportBackup(destinationZip: backupZip);

      final origBytes = await backupZip.readAsBytes();
      final origArchive = ZipDecoder().decodeBytes(origBytes);

      final newArchive = Archive();
      for (final f in origArchive) {
        if (f.name == 'lipi.db') {
          // Corrupt the database contents
          final corruptedContent = List<int>.from(f.content as List<int>);
          if (corruptedContent.isNotEmpty) corruptedContent[0] ^= 0xFF;
          newArchive.addFile(ArchiveFile(f.name, corruptedContent.length, corruptedContent));
        } else {
          newArchive.addFile(f);
        }
      }

      await backupZip.writeAsBytes(ZipEncoder().encode(newArchive));

      final valRes = await backupService.validateBackup(backupZip);
      expect(valRes.isSuccess, isTrue);
      expect(valRes.valueOrNull!.isValid, isFalse);
      expect(valRes.valueOrNull!.errorMessage, contains('Integrity check failed: checksum mismatch'));
    });

    test('validateBackup detects newer version and fails closed', () async {
      final backupZip = File(p.join(tempBaseDir.path, 'future_version.zip'));
      await backupService.exportBackup(destinationZip: backupZip);

      final origBytes = await backupZip.readAsBytes();
      final origArchive = ZipDecoder().decodeBytes(origBytes);

      final manifestFile = origArchive.findFile('backup_manifest.json')!;
      final manifestMap = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
      manifestMap['schema_version'] = 999; // Future schema version

      final newArchive = Archive();
      for (final f in origArchive) {
        if (f.name == 'backup_manifest.json') {
          final newManifestBytes = utf8.encode(jsonEncode(manifestMap));
          newArchive.addFile(ArchiveFile('backup_manifest.json', newManifestBytes.length, newManifestBytes));
        } else {
          newArchive.addFile(f);
        }
      }

      await backupZip.writeAsBytes(ZipEncoder().encode(newArchive));

      final valRes = await backupService.validateBackup(backupZip);
      expect(valRes.isSuccess, isTrue);
      expect(valRes.valueOrNull!.isValid, isFalse);
      expect(valRes.valueOrNull!.errorMessage, contains('newer version of Lipi'));
    });

    test('restoreBackup restores clinical records onto empty target vault', () async {
      final backupZip = File(p.join(tempBaseDir.path, 'full_backup.zip'));
      await backupService.exportBackup(destinationZip: backupZip);

      // Create a fresh target vault in another directory
      final targetVaultDir = Directory(p.join(tempBaseDir.path, 'target_vault'));
      final targetVault = LipiVault(targetVaultDir);
      await targetVault.initialize();
      final targetDb = VaultDatabase();
      await targetDb.open(targetVault.dbFile);

      // Verify target is currently empty
      final initialDoctorRes = await SqliteDoctorRepository(targetDb).getProfile();
      expect(initialDoctorRes.valueOrNull, isNull);

      // Execute Restore: Validate -> Verify -> Activate
      final restoreRes = await backupService.restoreBackup(
        backupZip: backupZip,
        targetVault: targetVault,
        targetDb: targetDb,
      );

      expect(restoreRes.isSuccess, isTrue);

      // Verify restored data in target vault
      final restoredDoctorRes = await SqliteDoctorRepository(targetDb).getProfile();
      final restoredDoctor = restoredDoctorRes.valueOrNull;
      expect(restoredDoctor, isNotNull);
      expect(restoredDoctor!.name, equals('Dr. Arjun Verma'));
      expect(restoredDoctor.clinicName, equals('Verma Heart Care'));

      final restoredPatientsRes = await SqlitePatientRepository(targetDb).searchPatients('Ramesh');
      final restoredPatients = restoredPatientsRes.valueOrNull!;
      expect(restoredPatients.length, equals(1));
      expect(restoredPatients.first.name, equals('Ramesh Patel'));
      expect(restoredPatients.first.city, equals('Ahmedabad'));

      await targetDb.close();
      targetVault.close();
    });

    test('restoreBackup non-destructive rollback leaves existing vault intact on failure', () async {
      // Create invalid backup (checksums deliberately broken)
      final badZip = File(p.join(tempBaseDir.path, 'broken_backup.zip'));
      await backupService.exportBackup(destinationZip: badZip);

      final origBytes = await badZip.readAsBytes();
      final origArchive = ZipDecoder().decodeBytes(origBytes);
      final newArchive = Archive();
      for (final f in origArchive) {
        if (f.name == 'lipi.db') {
          // Alter content without updating manifest
          newArchive.addFile(ArchiveFile('lipi.db', 4, utf8.encode('DEAD')));
        } else {
          newArchive.addFile(f);
        }
      }
      await badZip.writeAsBytes(ZipEncoder().encode(newArchive));

      // Attempt restore into live vault
      final restoreRes = await backupService.restoreBackup(
        backupZip: badZip,
        targetVault: vault,
        targetDb: db,
      );

      // Restore fails
      expect(restoreRes.isFailure, isTrue);

      // Existing clinical records must remain 100% intact and unaffected
      final doctorRes = await SqliteDoctorRepository(db).getProfile();
      final doctor = doctorRes.valueOrNull;
      expect(doctor, isNotNull);
      expect(doctor!.name, equals('Dr. Arjun Verma'));

      final patientsRes = await SqlitePatientRepository(db).searchPatients('Ramesh');
      final patients = patientsRes.valueOrNull!;
      expect(patients.length, equals(1));
      expect(patients.first.name, equals('Ramesh Patel'));
    });
  });
}
