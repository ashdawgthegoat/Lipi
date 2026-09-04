import 'dart:io';
import 'package:path/path.dart' as p;

/// Represents the user-owned Lipi Vault directory on the filesystem.
///
/// Follows ADR-0004:
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

  LipiVault(this.rootDir);

  File get dbFile => File(p.join(rootDir.path, 'lipi.db'));
  Directory get doctorDir => Directory(p.join(rootDir.path, 'doctor'));
  Directory get templatesDir => Directory(p.join(rootDir.path, 'doctor', 'templates'));
  Directory get patientDir => Directory(p.join(rootDir.path, 'patient'));
  Directory get documentsDir => Directory(p.join(rootDir.path, 'documents'));
  Directory get attachmentsDir => Directory(p.join(rootDir.path, 'attachments'));

  File get doctorProfileJson => File(p.join(doctorDir.path, 'profile.json'));

  /// Ensures the essential Vault directory structure exists.
  Future<void> initialize() async {
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }
    await doctorDir.create(recursive: true);
    await templatesDir.create(recursive: true);
    await patientDir.create(recursive: true);
    await documentsDir.create(recursive: true);
    await attachmentsDir.create(recursive: true);
  }

  /// Patient folder: `<vault>/patient/<patientId>/`
  Directory getPatientFolder(String patientId) {
    return Directory(p.join(patientDir.path, patientId));
  }

  /// Patient prescriptions folder: `<vault>/patient/<patientId>/prescriptions/`
  Directory getPatientPrescriptionsFolder(String patientId) {
    return Directory(p.join(patientDir.path, patientId, 'prescriptions'));
  }

  /// Path for a .lipi prescription file
  File getPrescriptionFile(String patientId, String consultationId) {
    return File(p.join(
      getPatientPrescriptionsFolder(patientId).path,
      'consultation_$consultationId.lipi',
    ));
  }

  /// Path for an exported PDF file
  File getPrescriptionPdfFile(String patientId, String consultationId) {
    return File(p.join(
      getPatientPrescriptionsFolder(patientId).path,
      'consultation_$consultationId.pdf',
    ));
  }
}
