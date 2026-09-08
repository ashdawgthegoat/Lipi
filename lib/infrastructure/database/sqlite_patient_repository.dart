import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../domains/patient/models/clinical_history.dart';
import '../../domains/patient/models/patient.dart';
import '../../domains/patient/models/patient_info.dart';
import '../../domains/patient/patient_repository.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';
import 'vault_database.dart';

class SqlitePatientRepository implements PatientRepository {
  final VaultDatabase database;

  SqlitePatientRepository(this.database);

  Database get _db => database.db;

  @override
  Future<Result<Patient, LipiError>> createPatient(Patient patient) async {
    try {
      patient.info.validate();
      await _db.insert(
        'patients',
        {
          'id': patient.id.value,
          'name': patient.name,
          'age': patient.age,
          'gender': patient.gender,
          'city': patient.city,
          'height_cm': patient.info.heightCm,
          'weight_kg': patient.info.weightKg,
          'phone_number': patient.info.phoneNumber,
          'clinical_history_json': jsonEncode(patient.history.toMap()),
          'created_at': patient.createdAt.toIso8601String(),
          'updated_at': patient.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return Success(patient);
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(StorageError('Failed to insert patient: ${patient.id.value}', e, st));
    }
  }

  @override
  Future<Result<Patient?, LipiError>> getPatientById(PatientId id) async {
    try {
      final rows = await _db.query(
        'patients',
        where: 'id = ?',
        whereArgs: [id.value],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);
      return Success(_rowToPatient(rows.first));
    } catch (e, st) {
      return Failure(StorageError('Failed to retrieve patient: ${id.value}', e, st));
    }
  }

  @override
  Future<Result<List<Patient>, LipiError>> searchPatients(String query) async {
    try {
      final trimmed = query.trim();
      final List<Map<String, dynamic>> rows;
      if (trimmed.isEmpty) {
        rows = await _db.query(
          'patients',
          orderBy: 'created_at DESC',
          limit: 100,
        );
      } else {
        rows = await _db.query(
          'patients',
          where: 'name LIKE ? OR city LIKE ? OR phone_number LIKE ?',
          whereArgs: ['%$trimmed%', '%$trimmed%', '%$trimmed%'],
          orderBy: 'name ASC',
          limit: 100,
        );
      }
      final list = rows.map(_rowToPatient).toList();
      return Success(list);
    } catch (e, st) {
      return Failure(StorageError('Failed to search patients', e, st));
    }
  }

  @override
  Future<Result<void, LipiError>> updatePatient(Patient patient) async {
    try {
      patient.info.validate();
      final count = await _db.update(
        'patients',
        {
          'name': patient.name,
          'age': patient.age,
          'gender': patient.gender,
          'city': patient.city,
          'height_cm': patient.info.heightCm,
          'weight_kg': patient.info.weightKg,
          'phone_number': patient.info.phoneNumber,
          'clinical_history_json': jsonEncode(patient.history.toMap()),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [patient.id.value],
      );
      if (count == 0) {
        return Failure(StorageError('Patient not found for update: ${patient.id.value}'));
      }
      return const Success(null);
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(StorageError('Failed to update patient: ${patient.id.value}', e, st));
    }
  }

  @override
  Future<Result<void, LipiError>> deletePatient(PatientId id) async {
    try {
      final count = await _db.delete(
        'patients',
        where: 'id = ?',
        whereArgs: [id.value],
      );
      if (count == 0) {
        return Failure(StorageError('Patient not found for deletion: ${id.value}'));
      }
      return const Success(null);
    } catch (e, st) {
      return Failure(StorageError('Failed to delete patient: ${id.value}', e, st));
    }
  }

  @override
  Future<Result<int, LipiError>> countPatients() async {
    try {
      final result = await _db.rawQuery('SELECT COUNT(*) as cnt FROM patients');
      final count = (result.first['cnt'] as num?)?.toInt() ?? 0;
      return Success(count);
    } catch (e, st) {
      return Failure(StorageError('Failed to count patients', e, st));
    }
  }

  Patient _rowToPatient(Map<String, dynamic> row) {
    ClinicalHistory history = const ClinicalHistory();
    final historyJson = row['clinical_history_json'] as String?;
    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(historyJson) as Map<String, dynamic>;
        history = ClinicalHistory.fromMap(decoded);
      } catch (_) {}
    }

    final info = PatientInfo(
      name: row['name'] as String,
      age: (row['age'] as num).toInt(),
      gender: row['gender'] as String,
      city: row['city'] as String,
      heightCm: (row['height_cm'] as num?)?.toDouble(),
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      phoneNumber: row['phone_number'] as String?,
    );

    return Patient(
      id: PatientId(row['id'] as String),
      info: info,
      history: history,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
