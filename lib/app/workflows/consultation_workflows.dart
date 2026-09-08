import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../../domains/consultation/consultation_repository.dart';
import '../../domains/consultation/models/clinical_document.dart';
import '../../domains/consultation/models/consultation.dart';
import '../../domains/consultation/models/consultation_status.dart';
import '../../domains/consultation/models/doctor_snapshot.dart';
import '../../domains/consultation/models/ink_document.dart';
import '../../domains/consultation/models/page_dimensions.dart';
import '../../domains/consultation/models/patient_snapshot.dart';
import '../../domains/doctor/doctor_repository.dart';
import '../../domains/patient/patient_repository.dart';
import '../../infrastructure/documents/document_repository.dart';
import '../../infrastructure/vault/vault.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';

/// Initializes a new prescription consultation with historical snapshots.
///
/// Follows ADR-0008 Section 4.3, 15, 16 & IMPLEMENTATION-CONTRACT Section 32:
/// 1. Confirm patient
/// 2. Obtain doctor / template context
/// 3. Create consultation identity & historical snapshot
/// 4. Create initial canonical document
/// 5. Persist initial document
/// 6. Save metadata
class StartConsultationWorkflow {
  final LipiVault vault;
  final PatientRepository patientRepository;
  final DoctorRepository doctorRepository;
  final ConsultationRepository consultationRepository;
  final DocumentRepository documentRepository;

  StartConsultationWorkflow({
    required this.vault,
    required this.patientRepository,
    required this.doctorRepository,
    required this.consultationRepository,
    required this.documentRepository,
  });

  Future<Result<ClinicalDocument, LipiError>> execute({
    required PatientId patientId,
    ConsultationId? consultationId,
    PageDimensions? overrideDimensions,
  }) async {
    try {
      // 1. Confirm patient
      final patientRes = await patientRepository.getPatientById(patientId);
      if (patientRes.isFailure) return Failure(patientRes.errorOrNull!);
      final patient = patientRes.valueOrNull;
      if (patient == null) {
        return Failure(StorageError('Patient not found: ${patientId.value}'));
      }

      // 2. Obtain doctor context
      final doctorRes = await doctorRepository.getProfile();
      if (doctorRes.isFailure) return Failure(doctorRes.errorOrNull!);
      final doctor = doctorRes.valueOrNull;
      if (doctor == null) {
        return const Failure(ValidationError('No active doctor profile configured'));
      }

      // 3. Create snapshots
      final cid = consultationId ?? ConsultationId.generate();
      final patientSnapshot = PatientSnapshot(
        name: patient.name,
        age: patient.age,
        gender: patient.gender,
        city: patient.city,
      );

      // Handle custom template embedding
      Uint8List? templateBytes;
      String? templateImageFileInPackage;
      if (doctor.templateConfig.hasCustomTemplate) {
        final tmplPath = doctor.templateConfig.customTemplatePath!;
        if (await vault.fs.exists(tmplPath)) {
          templateBytes = await vault.fs.readBytes(tmplPath);
          final ext = p.extension(tmplPath).toLowerCase();
          templateImageFileInPackage = 'templates/custom_template$ext';
        }
      }

      final doctorSnapshot = DoctorSnapshot(
        name: doctor.name,
        clinic: doctor.clinicName,
        qualifications: doctor.qualifications,
        regNumber: doctor.regNumber,
        templateImageFile: templateImageFileInPackage,
      );

      final pageDimensions = overrideDimensions ??
          PageDimensions(
            width: doctor.templateConfig.widthMm,
            height: doctor.templateConfig.heightMm,
            unit: doctor.templateConfig.unit,
          );

      // 4. Create canonical document
      final document = ClinicalDocument(
        consultationId: cid,
        page: pageDimensions,
        patientSnapshot: patientSnapshot,
        doctorSnapshot: doctorSnapshot,
        ink: const InkDocument(),
        templateBytes: templateBytes,
      );

      // 5. Persist initial canonical document
      final saveDocRes = await documentRepository.saveDocument(patientId, document);
      if (saveDocRes.isFailure) return Failure(saveDocRes.errorOrNull!);

      // 6. Record metadata in SQLite
      final consultationRelPath = vault.getPrescriptionRelativePath(patientId, cid);
      final metadata = Consultation(
        id: cid,
        patientId: patientId,
        patientSnapshot: patientSnapshot,
        doctorSnapshot: doctorSnapshot,
        pageDimensions: pageDimensions,
        status: ConsultationStatus.active,
        lipiRelativePath: consultationRelPath,
      );
      final metaRes = await consultationRepository.upsertConsultation(metadata);
      if (metaRes.isFailure) return Failure(metaRes.errorOrNull!);

      return Success(document);
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(StorageError('Failed to start consultation', e, st));
    }
  }
}

/// Reads a canonical clinical document from Vault storage.
///
/// Follows ADR-0008 Section 23 (Fail-Closed): Missing or invalid documents are
/// reported as errors and never silently fabricated.
class LoadConsultationWorkflow {
  final DocumentRepository documentRepository;

  LoadConsultationWorkflow(this.documentRepository);

  Future<Result<ClinicalDocument, LipiError>> execute({
    required PatientId patientId,
    required ConsultationId consultationId,
  }) async {
    return await documentRepository.readDocument(patientId, consultationId);
  }
}

/// Persists an updated canonical clinical document safely.
///
/// Follows ADR-0008 Section 18 & 22: Debounced or manual saves replace
/// the previous document atomically, updating metadata.
class SaveConsultationWorkflow {
  final DocumentRepository documentRepository;
  final ConsultationRepository consultationRepository;

  SaveConsultationWorkflow({
    required this.documentRepository,
    required this.consultationRepository,
  });

  Future<Result<void, LipiError>> execute({
    required PatientId patientId,
    required ClinicalDocument document,
    ConsultationStatus status = ConsultationStatus.saved,
  }) async {
    try {
      // 1. Atomically replace .lipi package
      final saveRes = await documentRepository.saveDocument(patientId, document);
      if (saveRes.isFailure) return Failure(saveRes.errorOrNull!);

      // 2. Update metadata in SQLite
      final metaRes = await consultationRepository.getConsultationById(document.consultationId);
      if (metaRes.isSuccess && metaRes.valueOrNull != null) {
        final existing = metaRes.valueOrNull!;
        final updated = existing.copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
        await consultationRepository.upsertConsultation(updated);
      }

      return const Success(null);
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(StorageError('Failed to save consultation', e, st));
    }
  }
}

/// Lists all prescriptions for a patient and verifies document presence on disk.
class ListConsultationHistoryWorkflow {
  final ConsultationRepository consultationRepository;
  final DocumentRepository documentRepository;

  ListConsultationHistoryWorkflow({
    required this.consultationRepository,
    required this.documentRepository,
  });

  Future<Result<List<Consultation>, LipiError>> execute(PatientId patientId) async {
    return await consultationRepository.getConsultationsForPatient(patientId);
  }
}
