import '../../domains/consultation/models/clinical_document.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';

/// Port for saving, reading, and replacing canonical clinical documents.
///
/// Follows ADR-0008 Section 7, 8, 10 and IMPLEMENTATION-CONTRACT Section 10:
/// The repository operates on Lipi's document abstraction rather than Excalidraw state.
/// A failure to read or validate a document is an error, never an invitation
/// to reconstruct the document silently from secondary metadata.
abstract class DocumentRepository {
  Future<Result<void, LipiError>> saveDocument(
    PatientId patientId,
    ClinicalDocument document,
  );

  Future<Result<ClinicalDocument, LipiError>> readDocument(
    PatientId patientId,
    ConsultationId consultationId,
  );

  Future<Result<bool, LipiError>> documentExists(
    PatientId patientId,
    ConsultationId consultationId,
  );

  Future<Result<void, LipiError>> deleteDocument(
    PatientId patientId,
    ConsultationId consultationId,
  );
}
