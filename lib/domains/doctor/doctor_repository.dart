import '../../shared/errors/lipi_error.dart';
import '../../shared/result/result.dart';
import 'models/doctor_profile.dart';

/// Port for saving and loading the active doctor profile.
///
/// Follows ADR-0008 Section 4.2.
abstract class DoctorRepository {
  Future<Result<DoctorProfile?, LipiError>> getProfile();

  Future<Result<void, LipiError>> saveProfile(DoctorProfile profile);

  Future<Result<bool, LipiError>> hasProfile();
}
