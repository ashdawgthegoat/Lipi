import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../domains/doctor/doctor_repository.dart';
import '../../domains/doctor/models/doctor_preferences.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/doctor/models/template_config.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';
import 'vault_database.dart';

class SqliteDoctorRepository implements DoctorRepository {
  final VaultDatabase database;

  SqliteDoctorRepository(this.database);

  Database get _db => database.db;

  @override
  Future<Result<DoctorProfile?, LipiError>> getProfile() async {
    try {
      final rows = await _db.query('doctor_profile', limit: 1);
      if (rows.isEmpty) return const Success(null);
      final row = rows.first;

      DoctorPreferences preferences = const DoctorPreferences();
      final prefJson = row['preferences_json'] as String?;
      if (prefJson != null && prefJson.isNotEmpty) {
        try {
          preferences = DoctorPreferences.fromMap(
              jsonDecode(prefJson) as Map<String, dynamic>);
        } catch (_) {}
      }

      final profile = DoctorProfile(
        id: DoctorId(row['id'] as String),
        name: row['name'] as String,
        clinicName: row['clinic_name'] as String,
        qualifications: (row['qualifications'] as String?) ?? '',
        regNumber: (row['reg_number'] as String?) ?? '',
        templateConfig: TemplateConfig(
          widthMm: (row['template_width_mm'] as num?)?.toDouble() ?? 180.0,
          heightMm: (row['template_height_mm'] as num?)?.toDouble() ?? 260.0,
          unit: (row['template_unit'] as String?) ?? 'mm',
          customTemplatePath: row['template_path'] as String?,
        ),
        preferences: preferences,
      );

      return Success(profile);
    } catch (e, st) {
      return Failure(StorageError('Failed to read doctor profile', e, st));
    }
  }

  @override
  Future<Result<void, LipiError>> saveProfile(DoctorProfile profile) async {
    try {
      profile.validate();
      await _db.insert(
        'doctor_profile',
        {
          'id': profile.id.value,
          'name': profile.name,
          'clinic_name': profile.clinicName,
          'qualifications': profile.qualifications,
          'reg_number': profile.regNumber,
          'template_path': profile.templateConfig.customTemplatePath,
          'template_width_mm': profile.templateConfig.widthMm,
          'template_height_mm': profile.templateConfig.heightMm,
          'template_unit': profile.templateConfig.unit,
          'preferences_json': jsonEncode(profile.preferences.toMap()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Success(null);
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(StorageError('Failed to save doctor profile', e, st));
    }
  }

  @override
  Future<Result<bool, LipiError>> hasProfile() async {
    try {
      final rows = await _db.rawQuery(
          'SELECT COUNT(*) as cnt FROM doctor_profile');
      final count = (rows.first['cnt'] as num?)?.toInt() ?? 0;
      return Success(count > 0);
    } catch (e, st) {
      return Failure(StorageError('Failed to check doctor profile', e, st));
    }
  }
}
