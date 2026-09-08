import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';
import 'models/patient.dart';

/// Port for patient persistence and discovery.
///
/// Follows ADR-0008 Section 4.1. Domain defines the contract,
/// infrastructure provides the SQLite/filesystem implementation.
abstract class PatientRepository {
  Future<Result<Patient, LipiError>> createPatient(Patient patient);

  Future<Result<Patient?, LipiError>> getPatientById(PatientId id);

  Future<Result<List<Patient>, LipiError>> searchPatients(String query);

  Future<Result<void, LipiError>> updatePatient(Patient patient);

  Future<Result<void, LipiError>> deletePatient(PatientId id);

  Future<Result<int, LipiError>> countPatients();
}
