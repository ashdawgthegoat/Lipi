import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../infrastructure/storage/lipi_database.dart';
import '../../infrastructure/storage/vault.dart';
import 'models/doctor_profile.dart';

class DoctorService {
  final LipiVault vault;
  final LipiDatabase database;

  DoctorService({
    required this.vault,
    required this.database,
  });

  Future<DoctorProfile?> getProfile() async {
    final fromDb = await database.getDoctorProfile();
    if (fromDb != null) return fromDb;

    // Fallback to vault filesystem json if available
    if (await vault.doctorProfileJson.exists()) {
      try {
        final content = await vault.doctorProfileJson.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        final profile = DoctorProfile.fromMap(map);
        await database.saveDoctorProfile(profile);
        return profile;
      } catch (_) {}
    }
    return null;
  }

  /// Saves the doctor profile. If [customTemplateFile] is provided, copies it
  /// into the Vault templates directory.
  ///
  /// Returns the persisted [DoctorProfile] — which contains the resolved
  /// [templatePath]. Always use the returned value; the input [profile] object
  /// does NOT have the template path populated.
  Future<DoctorProfile> saveProfile(DoctorProfile profile, {File? customTemplateFile}) async {
    String? templatePath = profile.templatePath;

    if (customTemplateFile != null && await customTemplateFile.exists()) {
      final ext = p.extension(customTemplateFile.path).toLowerCase();
      final destFile = File(p.join(vault.templatesDir.path, 'custom_template$ext'));
      if (customTemplateFile.path != destFile.path) {
        await customTemplateFile.copy(destFile.path);
      }
      templatePath = destFile.path;
      debugPrint('[Lipi][Template] Custom template imported to Vault: ${customTemplateFile.path} -> ${destFile.path}');
    } else if (customTemplateFile == null) {
      templatePath = null;
      debugPrint('[Lipi][Template] No custom template specified; templatePath set to null (Default Template)');
    }

    final updatedProfile = DoctorProfile(
      id: profile.id,
      name: profile.name,
      clinicName: profile.clinicName,
      qualifications: profile.qualifications,
      regNumber: profile.regNumber,
      templatePath: templatePath,
      templateWidthMm: profile.templateWidthMm,
      templateHeightMm: profile.templateHeightMm,
      templateUnit: profile.templateUnit,
    );

    debugPrint('[Lipi][Template] Saving profile to DB and Vault — templatePath: $templatePath');

    await database.saveDoctorProfile(updatedProfile);

    // Also persist profile.json in vault/doctor/
    await vault.doctorProfileJson.writeAsString(
      const JsonEncoder.withIndent('  ').convert(updatedProfile.toMap()),
    );

    return updatedProfile;
  }

  Future<File?> getTemplateFile(DoctorProfile profile) async {
    debugPrint('[Lipi][Template] getTemplateFile query: profile.templatePath = ${profile.templatePath}');
    if (profile.templatePath != null) {
      final file = File(profile.templatePath!);
      final exists = await file.exists();
      debugPrint('[Lipi][Template] Template file lookup: path=${file.path}, exists=$exists');
      if (exists) return file;
    }
    return null;
  }
}
