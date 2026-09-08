import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';
import 'models/consultation.dart';

/// Port for structured consultation metadata persistence.
///
/// Follows ADR-0008 Section 4.3 and 9:
/// SQLite stores structured metadata and references. Canonical handwritten
/// ink and document state belong to the canonical Lipi document and Vault storage.
abstract class ConsultationRepository {
  Future<Result<void, LipiError>> upsertConsultation(Consultation consultation);

  Future<Result<Consultation?, LipiError>> getConsultationById(
      ConsultationId id);

  Future<Result<List<Consultation>, LipiError>> getConsultationsForPatient(
      PatientId patientId);

  /// Searches consultations strictly within a patient's historical records.
  ///
  /// Matches on structured metadata (date in multiple standard formats,
  /// consultation ID, status). An empty query returns the complete chronological list.
  Future<Result<List<Consultation>, LipiError>> searchConsultationsForPatient({
    required PatientId patientId,
    required String query,
  });

  Future<Result<void, LipiError>> deleteConsultation(ConsultationId id);

  Future<Result<void, LipiError>> deleteConsultationsForPatient(
      PatientId patientId);
}
