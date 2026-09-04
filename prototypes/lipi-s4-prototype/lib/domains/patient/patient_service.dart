import 'package:uuid/uuid.dart';
import '../../infrastructure/storage/lipi_database.dart';
import '../../infrastructure/storage/vault.dart';
import 'models/patient_record.dart';

class PatientService {
  final LipiVault vault;
  final LipiDatabase database;
  static const _uuid = Uuid();

  PatientService({
    required this.vault,
    required this.database,
  });

  /// Creates a new patient record in SQLite and creates their filesystem folder in the Vault.
  Future<PatientRecord> createPatient({
    required String name,
    required int age,
    required String gender,
    required String city,
  }) async {
    final patientId = _uuid.v4();
    final patient = PatientRecord(
      id: patientId,
      name: name.trim(),
      age: age,
      gender: gender.trim(),
      city: city.trim(),
      createdAt: DateTime.now(),
    );

    // 1. Store in SQLite
    await database.insertPatient(patient);

    // 2. Create patient filesystem folder and prescriptions folder inside Vault
    final folder = vault.getPatientFolder(patientId);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final rxFolder = vault.getPatientPrescriptionsFolder(patientId);
    if (!await rxFolder.exists()) {
      await rxFolder.create(recursive: true);
    }

    return patient;
  }

  /// Searches patients in SQLite by query (matching name or city).
  Future<List<PatientRecord>> searchPatients(String query) async {
    return await database.searchPatients(query);
  }

  /// Retrieves a patient by their machine-level ID.
  Future<PatientRecord?> getPatient(String id) async {
    return await database.getPatient(id);
  }

  /// Lists all prescriptions for a patient from SQLite and verifies filesystem status.
  Future<List<PrescriptionSummary>> getPatientPrescriptions(String patientId) async {
    final rows = await database.getPrescriptionsForPatient(patientId);
    final list = <PrescriptionSummary>[];

    for (final row in rows) {
      final consultationId = row['consultation_id'] as String;
      final filePath = row['file_path'] as String;
      final createdAt = DateTime.parse(row['created_at'] as String);
      final updatedAt = DateTime.parse(row['updated_at'] as String);

      final pdfFile = vault.getPrescriptionPdfFile(patientId, consultationId);
      final hasPdf = await pdfFile.exists();

      list.add(PrescriptionSummary(
        consultationId: consultationId,
        patientId: patientId,
        filePath: filePath,
        createdAt: createdAt,
        updatedAt: updatedAt,
        hasPdf: hasPdf,
      ));
    }

    return list;
  }
}
