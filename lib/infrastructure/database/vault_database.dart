import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../shared/errors/lipi_error.dart';

/// Structured SQLite metadata storage for the Lipi Vault.
///
/// Follows ADR-0004 and ADR-0008 Section 9:
/// SQLite stores structured metadata and references. Canonical handwritten
/// ink and document state belong to the canonical Lipi document and Vault storage.
class VaultDatabase {
  Database? _db;

  Database get db {
    if (_db == null) {
      throw const StorageError(
          'VaultDatabase is not initialized. Call open() first.');
    }
    return _db!;
  }

  bool get isOpen => _db != null && _db!.isOpen;

  /// Initializes FFI database factory when running on desktop / test environments.
  static void initializeFfiIfRequired() {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// Opens or creates the SQLite database at [dbFile].
  Future<void> open(File dbFile) async {
    initializeFfiIfRequired();

    try {
      _db = await openDatabase(
        dbFile.path,
        version: 1,
        onCreate: (db, version) async {
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Explicit migration path per ADR-0008 Section 38
        },
      );
    } catch (e, st) {
      throw StorageError('Failed to open Vault database at ${dbFile.path}', e, st);
    }
  }

  Future<void> _createTables(Database db) async {
    // 1. Doctor Profile Table
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
        template_unit TEXT,
        preferences_json TEXT
      )
    ''');

    // 2. Patients Table
    await db.execute('''
      CREATE TABLE patients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        city TEXT NOT NULL,
        height_cm REAL,
        weight_kg REAL,
        phone_number TEXT,
        clinical_history_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 3. Consultations Table
    await db.execute('''
      CREATE TABLE consultations (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        patient_snapshot_json TEXT NOT NULL,
        doctor_snapshot_json TEXT NOT NULL,
        page_dimensions_json TEXT NOT NULL,
        status TEXT NOT NULL,
        lipi_relative_path TEXT NOT NULL,
        pdf_relative_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');

    // 4. Indexes for rapid clinical discovery
    await db.execute('CREATE INDEX idx_patients_name ON patients(name)');
    await db.execute('CREATE INDEX idx_patients_city ON patients(city)');
    await db.execute('CREATE INDEX idx_consultations_patient ON consultations(patient_id)');
    await db.execute('CREATE INDEX idx_consultations_created ON consultations(created_at DESC)');
  }

  /// Runs an operation inside a database transaction.
  /// Rollback occurs automatically if an exception is thrown.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    try {
      return await db.transaction(action);
    } catch (e, st) {
      if (e is LipiError) rethrow;
      throw StorageError('Transaction failed and rolled back', e, st);
    }
  }

  /// Flushes write-ahead log to main database file.
  Future<void> checkpoint() async {
    if (isOpen) {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    }
  }

  /// Verifies database file integrity.
  Future<bool> checkIntegrity() async {
    if (!isOpen) return false;
    final res = await db.rawQuery('PRAGMA integrity_check');
    if (res.isNotEmpty && res.first.values.isNotEmpty) {
      return res.first.values.first.toString().toLowerCase() == 'ok';
    }
    return false;
  }

  /// Safely closes the database.
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
