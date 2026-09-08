import 'dart:io';
import 'package:path/path.dart' as p;
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../filesystem/vault_filesystem.dart';

enum VaultLifecycleState {
  uninitialized,
  initializing,
  active,
  closed,
  error,
}

/// Represents the doctor-owned Lipi Vault directory structure.
///
/// Follows ADR-0004 and ADR-0008 Section 8 & 10:
/// Lipi Vault/
/// ├── lipi.db
/// ├── doctor/
/// │   ├── profile.json
/// │   └── templates/
/// ├── patient/
/// │   └── `<patient_id>`/
/// │       └── prescriptions/
/// ├── documents/
/// └── attachments/
class LipiVault {
  final Directory rootDir;
  final VaultFilesystem fs;
  VaultLifecycleState _state = VaultLifecycleState.uninitialized;

  LipiVault(this.rootDir) : fs = VaultFilesystem(rootDir);

  VaultLifecycleState get state => _state;

  File get dbFile => File(p.join(rootDir.path, 'lipi.db'));
  Directory get doctorDir => Directory(p.join(rootDir.path, 'doctor'));
  Directory get templatesDir =>
      Directory(p.join(rootDir.path, 'doctor', 'templates'));
  Directory get patientDir => Directory(p.join(rootDir.path, 'patient'));
  Directory get documentsDir => Directory(p.join(rootDir.path, 'documents'));
  Directory get attachmentsDir =>
      Directory(p.join(rootDir.path, 'attachments'));

  File get doctorProfileJson => File(p.join(doctorDir.path, 'profile.json'));

  /// Ensures all essential Vault directories exist.
  Future<void> initialize() async {
    _state = VaultLifecycleState.initializing;
    try {
      if (!await rootDir.exists()) {
        await rootDir.create(recursive: true);
      }
      await fs.createDirectory('doctor');
      await fs.createDirectory(p.join('doctor', 'templates'));
      await fs.createDirectory('patient');
      await fs.createDirectory('documents');
      await fs.createDirectory('attachments');
      _state = VaultLifecycleState.active;
    } catch (e, st) {
      _state = VaultLifecycleState.error;
      throw VaultError('Failed to initialize Lipi Vault structure', e, st);
    }
  }

  /// Validates that the core Vault directories are accessible.
  Future<bool> validateStructure() async {
    return await fs.exists('doctor') &&
        await fs.exists(p.join('doctor', 'templates')) &&
        await fs.exists('patient') &&
        await fs.exists('documents') &&
        await fs.exists('attachments');
  }

  /// Relative path for a patient folder: `patient/<patientId>`
  String getPatientFolderRelativePath(PatientId patientId) =>
      p.join('patient', patientId.value);

  /// Relative path for a patient's prescriptions: `patient/<patientId>/prescriptions`
  String getPatientPrescriptionsFolderRelativePath(PatientId patientId) =>
      p.join('patient', patientId.value, 'prescriptions');

  /// Relative path for a .lipi prescription file:
  /// `patient/<patientId>/prescriptions/consultation_<consultationId>.lipi`
  String getPrescriptionRelativePath(
    PatientId patientId,
    ConsultationId consultationId,
  ) =>
      p.join(
        getPatientPrescriptionsFolderRelativePath(patientId),
        'consultation_${consultationId.value}.lipi',
      );

  /// Relative path for an exported PDF file:
  /// `patient/<patientId>/prescriptions/consultation_<consultationId>.pdf`
  String getPrescriptionPdfRelativePath(
    PatientId patientId,
    ConsultationId consultationId,
  ) =>
      p.join(
        getPatientPrescriptionsFolderRelativePath(patientId),
        'consultation_${consultationId.value}.pdf',
      );

  /// Closes the vault and releases resources.
  void close() {
    _state = VaultLifecycleState.closed;
  }
}
