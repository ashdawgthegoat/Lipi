import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/patient/models/patient_record.dart';

class LipiDatabase {
  Database? _db;

  Database get db {
    if (_db == null) {
      throw StateError('LipiDatabase is not initialized. Call init() first.');
    }
    return _db!;
  }

  Future<void> init(File dbFile) async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _db = await openDatabase(
      dbFile.path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE doctor_profile (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            clinic_name TEXT NOT NULL,
            qualifications TEXT,
            reg_number TEXT,
            template_path TEXT,
            template_width_mm REAL,
            template_height_mm REAL,
            template_unit TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE patients (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            age INTEGER NOT NULL,
            gender TEXT NOT NULL,
            city TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE prescriptions (
            consultation_id TEXT PRIMARY KEY,
            patient_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (patient_id) REFERENCES patients(id)
          )
        ''');

        await db.execute('CREATE INDEX idx_patients_name ON patients(name)');
        await db.execute('CREATE INDEX idx_prescriptions_patient ON prescriptions(patient_id)');
      },
    );
  }

  // --- Doctor Domain ---
  Future<void> saveDoctorProfile(DoctorProfile profile) async {
    await db.insert(
      'doctor_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DoctorProfile?> getDoctorProfile() async {
    final results = await db.query('doctor_profile', limit: 1);
    if (results.isEmpty) return null;
    return DoctorProfile.fromMap(results.first);
  }

  // --- Patient Domain ---
  Future<void> insertPatient(PatientRecord patient) async {
    await db.insert(
      'patients',
      patient.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<PatientRecord?> getPatient(String id) async {
    final results = await db.query(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return PatientRecord.fromMap(results.first);
  }

  Future<List<PatientRecord>> searchPatients(String query) async {
    final trimmed = query.trim();
    final List<Map<String, dynamic>> results;
    if (trimmed.isEmpty) {
      results = await db.query(
        'patients',
        orderBy: 'created_at DESC',
        limit: 50,
      );
    } else {
      results = await db.query(
        'patients',
        where: 'name LIKE ? OR city LIKE ?',
        whereArgs: ['%$trimmed%', '%$trimmed%'],
        orderBy: 'name ASC',
        limit: 50,
      );
    }
    return results.map((m) => PatientRecord.fromMap(m)).toList();
  }

  // --- Prescription Metadata ---
  Future<void> upsertPrescription({
    required String consultationId,
    required String patientId,
    required String filePath,
    required DateTime updatedAt,
    DateTime? createdAt,
  }) async {
    final existing = await getPrescription(consultationId);
    final effectiveCreatedAt = existing != null
        ? existing['created_at'] as String
        : (createdAt ?? updatedAt).toIso8601String();

    await db.insert(
      'prescriptions',
      {
        'consultation_id': consultationId,
        'patient_id': patientId,
        'file_path': filePath,
        'created_at': effectiveCreatedAt,
        'updated_at': updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getPrescription(String consultationId) async {
    final results = await db.query(
      'prescriptions',
      where: 'consultation_id = ?',
      whereArgs: [consultationId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<List<Map<String, dynamic>>> getPrescriptionsForPatient(String patientId) async {
    return await db.query(
      'prescriptions',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
