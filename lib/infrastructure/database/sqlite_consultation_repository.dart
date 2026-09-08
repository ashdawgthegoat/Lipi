import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../domains/consultation/consultation_repository.dart';
import '../../domains/consultation/models/consultation.dart';
import '../../domains/consultation/models/consultation_status.dart';
import '../../domains/consultation/models/doctor_snapshot.dart';
import '../../domains/consultation/models/page_dimensions.dart';
import '../../domains/consultation/models/patient_snapshot.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';
import 'vault_database.dart';

class SqliteConsultationRepository implements ConsultationRepository {
  final VaultDatabase database;

  SqliteConsultationRepository(this.database);

  Database get _db => database.db;

  @override
  Future<Result<void, LipiError>> upsertConsultation(
      Consultation consultation) async {
    try {
      await _db.insert(
        'consultations',
        {
          'id': consultation.id.value,
          'patient_id': consultation.patientId.value,
          'patient_snapshot_json':
              jsonEncode(consultation.patientSnapshot.toJson()),
          'doctor_snapshot_json':
              jsonEncode(consultation.doctorSnapshot.toJson()),
          'page_dimensions_json':
              jsonEncode(consultation.pageDimensions.toJson()),
          'status': consultation.status.name,
          'lipi_relative_path': consultation.lipiRelativePath,
          'pdf_relative_path': consultation.pdfRelativePath,
          'created_at': consultation.createdAt.toIso8601String(),
          'updated_at': consultation.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(StorageError(
          'Failed to upsert consultation metadata: ${consultation.id.value}',
          e,
          st));
    }
  }

  @override
  Future<Result<Consultation?, LipiError>> getConsultationById(
      ConsultationId id) async {
    try {
      final rows = await _db.query(
        'consultations',
        where: 'id = ?',
        whereArgs: [id.value],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);
      return Success(_rowToConsultation(rows.first));
    } catch (e, st) {
      return Failure(StorageError(
          'Failed to retrieve consultation: ${id.value}', e, st));
    }
  }

  @override
  Future<Result<List<Consultation>, LipiError>> getConsultationsForPatient(
      PatientId patientId) async {
    try {
      final rows = await _db.query(
        'consultations',
        where: 'patient_id = ?',
        whereArgs: [patientId.value],
        orderBy: 'created_at DESC',
      );
      final list = rows.map(_rowToConsultation).toList();
      return Success(list);
    } catch (e, st) {
      return Failure(StorageError(
          'Failed to list consultations for patient: ${patientId.value}',
          e,
          st));
    }
  }

  @override
  Future<Result<void, LipiError>> deleteConsultation(ConsultationId id) async {
    try {
      final count = await _db.delete(
        'consultations',
        where: 'id = ?',
        whereArgs: [id.value],
      );
      if (count == 0) {
        return Failure(StorageError(
            'Consultation not found for deletion: ${id.value}'));
      }
      return const Success(null);
    } catch (e, st) {
      return Failure(StorageError(
          'Failed to delete consultation: ${id.value}', e, st));
    }
  }

  @override
  Future<Result<void, LipiError>> deleteConsultationsForPatient(
      PatientId patientId) async {
    try {
      await _db.delete(
        'consultations',
        where: 'patient_id = ?',
        whereArgs: [patientId.value],
      );
      return const Success(null);
    } catch (e, st) {
      return Failure(StorageError(
          'Failed to delete consultations for patient: ${patientId.value}',
          e,
          st));
    }
  }

  Consultation _rowToConsultation(Map<String, dynamic> row) {
    final patientSnapshot = PatientSnapshot.fromJson(
      jsonDecode(row['patient_snapshot_json'] as String)
          as Map<String, dynamic>,
    );
    final doctorSnapshot = DoctorSnapshot.fromJson(
      jsonDecode(row['doctor_snapshot_json'] as String)
          as Map<String, dynamic>,
    );
    final pageDimensions = PageDimensions.fromJson(
      jsonDecode(row['page_dimensions_json'] as String)
          as Map<String, dynamic>,
    );

    return Consultation(
      id: ConsultationId(row['id'] as String),
      patientId: PatientId(row['patient_id'] as String),
      patientSnapshot: patientSnapshot,
      doctorSnapshot: doctorSnapshot,
      pageDimensions: pageDimensions,
      status: ConsultationStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => ConsultationStatus.saved,
      ),
      lipiRelativePath: row['lipi_relative_path'] as String,
      pdfRelativePath: row['pdf_relative_path'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
