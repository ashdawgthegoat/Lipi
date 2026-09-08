import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../../domains/doctor/doctor_repository.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/doctor/models/template_config.dart';
import '../../infrastructure/vault/vault.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/result/result.dart';

/// Configures or updates the doctor's profile and active letterhead template.
///
/// Follows ADR-0008 Section 4.2 & 15:
/// Mutable doctor profile is saved in SQLite and mirrored in Vault filesystem.
class ConfigureDoctorWorkflow {
  final LipiVault vault;
  final DoctorRepository doctorRepository;

  ConfigureDoctorWorkflow({
    required this.vault,
    required this.doctorRepository,
  });

  Future<Result<DoctorProfile, LipiError>> execute({
    required DoctorProfile profile,
    File? customTemplateFile,
    Uint8List? customTemplateBytes,
    String templateExtension = '.png',
  }) async {
    try {
      String? templateRelativePath = profile.templateConfig.customTemplatePath;

      // 1. If custom template file is provided, import to Vault templates dir
      if (customTemplateFile != null && await customTemplateFile.exists()) {
        final ext = p.extension(customTemplateFile.path).toLowerCase();
        final destRelPath = p.join('doctor', 'templates', 'custom_template$ext');
        final bytes = await customTemplateFile.readAsBytes();
        await vault.fs.writeBytes(destRelPath, bytes);
        templateRelativePath = destRelPath;
      } else if (customTemplateBytes != null && customTemplateBytes.isNotEmpty) {
        final destRelPath = p.join('doctor', 'templates', 'custom_template$templateExtension');
        await vault.fs.writeBytes(destRelPath, customTemplateBytes);
        templateRelativePath = destRelPath;
      }

      final updatedProfile = profile.copyWith(
        templateConfig: profile.templateConfig.copyWith(
          customTemplatePath: templateRelativePath,
          clearCustomTemplate: customTemplateFile == null && customTemplateBytes == null && profile.templateConfig.customTemplatePath == null,
        ),
      );

      // 2. Persist in repository
      final saveRes = await doctorRepository.saveProfile(updatedProfile);
      if (saveRes.isFailure) return Failure(saveRes.errorOrNull!);

      // 3. Mirror in vault/doctor/profile.json for portable inspection
      final jsonStr = const JsonEncoder.withIndent('  ').convert(updatedProfile.toMap());
      await vault.fs.writeString(p.join('doctor', 'profile.json'), jsonStr);

      return Success(updatedProfile);
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(StorageError('Failed to configure doctor profile', e, st));
    }
  }
}

/// Updates prescription template dimensions and letterhead configuration.
class ConfigureTemplateWorkflow {
  final ConfigureDoctorWorkflow configureDoctorWorkflow;
  final DoctorRepository doctorRepository;

  ConfigureTemplateWorkflow({
    required this.configureDoctorWorkflow,
    required this.doctorRepository,
  });

  Future<Result<DoctorProfile, LipiError>> execute({
    required TemplateConfig templateConfig,
    File? customTemplateFile,
    Uint8List? customTemplateBytes,
  }) async {
    final profileRes = await doctorRepository.getProfile();
    if (profileRes.isFailure) return Failure(profileRes.errorOrNull!);

    final currentProfile = profileRes.valueOrNull;
    if (currentProfile == null) {
      return const Failure(ValidationError('No existing doctor profile found to configure template for'));
    }

    final updated = currentProfile.copyWith(templateConfig: templateConfig);
    return await configureDoctorWorkflow.execute(
      profile: updated,
      customTemplateFile: customTemplateFile,
      customTemplateBytes: customTemplateBytes,
    );
  }
}
