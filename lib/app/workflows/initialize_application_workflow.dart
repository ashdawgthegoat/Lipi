import '../../domains/doctor/doctor_repository.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../infrastructure/database/vault_database.dart';
import '../../infrastructure/vault/vault.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/result/result.dart';

enum AppLaunchDestination {
  doctorSetup,
  mainWorkspace,
}

class AppInitResult {
  final AppLaunchDestination destination;
  final DoctorProfile? doctorProfile;

  const AppInitResult({
    required this.destination,
    this.doctorProfile,
  });
}

/// Initializes Vault structure, database connection, and determines initial route.
///
/// Follows ADR-0008 Section 4.4 & 37 (Startup Contract):
/// Startup does not assume a valid active vault exists; it discovers, initializes,
/// validates schema, and safely routes to Doctor Setup or Main Workspace.
class InitializeApplicationWorkflow {
  final LipiVault vault;
  final VaultDatabase database;
  final DoctorRepository doctorRepository;

  InitializeApplicationWorkflow({
    required this.vault,
    required this.database,
    required this.doctorRepository,
  });

  Future<Result<AppInitResult, LipiError>> execute() async {
    try {
      // 1. Initialize & validate Vault structure
      await vault.initialize();
      final isStructureValid = await vault.validateStructure();
      if (!isStructureValid) {
        return const Failure(VaultError('Vault structure validation failed'));
      }

      // 2. Open SQLite database if not already open
      if (!database.isOpen) {
        await database.open(vault.dbFile);
      }

      // 3. Check for doctor profile
      final doctorRes = await doctorRepository.getProfile();
      if (doctorRes.isFailure) {
        return Failure(doctorRes.errorOrNull!);
      }

      final profile = doctorRes.valueOrNull;
      if (profile == null) {
        return const Success(
          AppInitResult(destination: AppLaunchDestination.doctorSetup),
        );
      }

      return Success(
        AppInitResult(
          destination: AppLaunchDestination.mainWorkspace,
          doctorProfile: profile,
        ),
      );
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(VaultError('Application startup initialization failed', e, st));
    }
  }
}
