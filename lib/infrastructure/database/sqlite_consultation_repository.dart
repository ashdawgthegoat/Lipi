import 'dart:convert';
import 'package:intl/intl.dart';
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
  Future<Result<List<Consultation>, LipiError>> searchConsultationsForPatient({
    required PatientId patientId,
    required String query,
  }) async {
    try {
      final allRes = await getConsultationsForPatient(patientId);
      if (allRes.isFailure) return allRes;
      final all = allRes.valueOrNull ?? [];

      final trimmed = query.trim().toLowerCase();
      if (trimmed.isEmpty) {
        return Success(all);
      }

      final dateFormatFull = DateFormat('dd MMM yyyy');
      final dateFormatISO = DateFormat('yyyy-MM-dd');
      final dateFormatMonth = DateFormat('MMMM yyyy');
      final dateFormatDay = DateFormat('EEEE');

      final filtered = all.where((c) {
        // 1. Match consultation ID
        if (c.id.value.toLowerCase().contains(trimmed)) return true;

        // 2. Match status
        if (c.status.name.toLowerCase().contains(trimmed)) return true;

        // 3. Match dates across common clinical query formats
        final date = c.createdAt;
        if (dateFormatISO.format(date).toLowerCase().contains(trimmed)) return true;
        if (dateFormatFull.format(date).toLowerCase().contains(trimmed)) return true;
        if (dateFormatMonth.format(date).toLowerCase().contains(trimmed)) return true;
        if (dateFormatDay.format(date).toLowerCase().contains(trimmed)) return true;
        if (date.year.toString().contains(trimmed)) return true;
        if (date.day.toString().padLeft(2, '0').contains(trimmed)) return true;

        return false;
      }).toList();

      return Success(filtered);
    } catch (e, st) {
      return Failure(StorageError(
        'Failed to search consultations for patient: ${patientId.value}',
        e,
        st,
      ));
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

  Consultation _rowToConsultation(Map<String, Object?> row) {
    final patientSnapshotMap = jsonDecode(row['patient_snapshot_json'] as String)
        as Map<String, dynamic>;
    final doctorSnapshotMap = jsonDecode(row['doctor_snapshot_json'] as String)
        as Map<String, dynamic>;
    final pageDimensionsMap = jsonDecode(row['page_dimensions_json'] as String)
        as Map<String, dynamic>;

    return Consultation(
      id: ConsultationId(row['id'] as String),
      patientId: PatientId(row['patient_id'] as String),
      patientSnapshot: PatientSnapshot.fromJson(patientSnapshotMap),
      doctorSnapshot: DoctorSnapshot.fromJson(doctorSnapshotMap),
      pageDimensions: PageDimensions.fromJson(pageDimensionsMap),
      status: ConsultationStatus.values.byName(row['status'] as String),
      lipiRelativePath: row['lipi_relative_path'] as String,
      pdfRelativePath: row['pdf_relative_path'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
