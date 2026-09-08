import '../../domains/consultation/consultation_repository.dart';
import '../../domains/consultation/models/consultation.dart';
import '../../domains/patient/models/clinical_history.dart';
import '../../domains/patient/models/patient.dart';
import '../../domains/patient/models/patient_info.dart';
import '../../domains/patient/patient_repository.dart';
import '../../infrastructure/vault/vault.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';

/// Creates a new patient, establishes their Vault directory, and persists metadata.
///
/// Follows ADR-0008 Section 4.1 & IMPLEMENTATION-CONTRACT Section 5.1 & 7.
class CreatePatientWorkflow {
  final LipiVault vault;
  final PatientRepository patientRepository;

  CreatePatientWorkflow({
    required this.vault,
    required this.patientRepository,
  });

  Future<Result<Patient, LipiError>> execute({
    required PatientInfo info,
    ClinicalHistory history = const ClinicalHistory(),
    PatientId? id,
  }) async {
    try {
      final patientId = id ?? PatientId.generate();
      final patient = Patient(
        id: patientId,
        info: info,
        history: history,
      );

      // 1. Establish patient folder structure in Vault
      final rxFolderRelPath = vault.getPatientPrescriptionsFolderRelativePath(patientId);
      await vault.fs.createDirectory(rxFolderRelPath);

      // 2. Persist in database
      final createRes = await patientRepository.createPatient(patient);
      return createRes;
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(StorageError('Failed to create patient', e, st));
    }
  }
}

/// Discovers patients by search query (name, city, phone).
class SearchPatientsWorkflow {
  final PatientRepository patientRepository;

  SearchPatientsWorkflow(this.patientRepository);

  Future<Result<List<Patient>, LipiError>> execute(String query) async {
    return await patientRepository.searchPatients(query);
  }
}

class PatientWorkspaceData {
  final Patient patient;
  final List<Consultation> consultations;

  const PatientWorkspaceData({
    required this.patient,
    required this.consultations,
  });
}

/// Opens a patient workspace, loading patient info and previous consultation history.
class OpenPatientWorkflow {
  final PatientRepository patientRepository;
  final ConsultationRepository consultationRepository;

  OpenPatientWorkflow({
    required this.patientRepository,
    required this.consultationRepository,
  });

  Future<Result<PatientWorkspaceData, LipiError>> execute(PatientId id) async {
    final patientRes = await patientRepository.getPatientById(id);
    if (patientRes.isFailure) return Failure(patientRes.errorOrNull!);

    final patient = patientRes.valueOrNull;
    if (patient == null) {
      return Failure(StorageError('Patient not found with id: ${id.value}'));
    }

    final historyRes = await consultationRepository.getConsultationsForPatient(id);
    if (historyRes.isFailure) return Failure(historyRes.errorOrNull!);

    return Success(PatientWorkspaceData(
      patient: patient,
      consultations: historyRes.valueOrNull ?? [],
    ));
  }
}

/// Explicit patient deletion handling both database references and Vault filesystem files.
///
/// Follows IMPLEMENTATION-CONTRACT Section 35:
/// Patient deletion is destructive, removes all related clinical data consistently,
/// and never leaves dangling files or references.
class DeletePatientWorkflow {
  final LipiVault vault;
  final PatientRepository patientRepository;
  final ConsultationRepository consultationRepository;

  DeletePatientWorkflow({
    required this.vault,
    required this.patientRepository,
    required this.consultationRepository,
  });

  Future<Result<void, LipiError>> execute(PatientId patientId) async {
    try {
      // 1. Delete all consultations for patient from database
      final delConsultationsRes =
          await consultationRepository.deleteConsultationsForPatient(patientId);
      if (delConsultationsRes.isFailure) {
        return Failure(delConsultationsRes.errorOrNull!);
      }

      // 2. Delete patient from database
      final delPatientRes = await patientRepository.deletePatient(patientId);
      if (delPatientRes.isFailure) {
        return Failure(delPatientRes.errorOrNull!);
      }

      // 3. Remove patient directory from Vault filesystem
      final patientFolderRelPath = vault.getPatientFolderRelativePath(patientId);
      await vault.fs.delete(patientFolderRelPath, recursive: true);

      return const Success(null);
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(StorageError('Failed to delete patient data', e, st));
    }
  }
}
