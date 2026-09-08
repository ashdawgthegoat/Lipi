import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/models/consultation.dart';
import 'package:lipi/domains/consultation/models/consultation_status.dart';
import 'package:lipi/domains/consultation/models/doctor_snapshot.dart';
import 'package:lipi/domains/consultation/models/page_dimensions.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/doctor/models/doctor_preferences.dart';
import 'package:lipi/domains/doctor/models/doctor_profile.dart';
import 'package:lipi/domains/doctor/models/template_config.dart';
import 'package:lipi/domains/patient/models/allergy.dart';
import 'package:lipi/domains/patient/models/clinical_history.dart';
import 'package:lipi/domains/patient/models/medication_record.dart';
import 'package:lipi/domains/patient/models/patient.dart';
import 'package:lipi/domains/patient/models/patient_info.dart';
import 'package:lipi/infrastructure/database/sqlite_consultation_repository.dart';
import 'package:lipi/infrastructure/database/sqlite_doctor_repository.dart';
import 'package:lipi/infrastructure/database/sqlite_patient_repository.dart';
import 'package:lipi/infrastructure/database/vault_database.dart';
import 'package:lipi/infrastructure/vault/vault.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VaultDatabase.initializeFfiIfRequired();

  late Directory tempDir;
  late LipiVault vault;
  late VaultDatabase database;
  late SqlitePatientRepository patientRepo;
  late SqliteDoctorRepository doctorRepo;
  late SqliteConsultationRepository consultationRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_vault_test_');
    vault = LipiVault(tempDir);
    await vault.initialize();

    database = VaultDatabase();
    await database.open(vault.dbFile);

    patientRepo = SqlitePatientRepository(database);
    doctorRepo = SqliteDoctorRepository(database);
    consultationRepo = SqliteConsultationRepository(database);
  });

  tearDown(() async {
    await database.close();
    vault.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Vault & Filesystem Tests', () {
    test('Vault initialization creates required directories', () async {
      expect(await vault.validateStructure(), isTrue);
      expect(await vault.doctorDir.exists(), isTrue);
      expect(await vault.templatesDir.exists(), isTrue);
      expect(await vault.patientDir.exists(), isTrue);
      expect(await vault.documentsDir.exists(), isTrue);
      expect(await vault.attachmentsDir.exists(), isTrue);
      expect(vault.state, equals(VaultLifecycleState.active));
    });

    test('VaultFilesystem atomicReplace guarantees safe atomic replacement', () async {
      final fs = vault.fs;
      final testPath = 'documents/test_atomic.txt';

      // Write initial valid content
      await fs.writeString(testPath, 'Initial Version 1');
      expect(await fs.readString(testPath), equals('Initial Version 1'));

      // Perform atomic replace with Version 2
      final newBytes = Uint8List.fromList('Updated Version 2'.codeUnits);
      await fs.atomicReplace(testPath, newBytes);
      expect(await fs.readString(testPath), equals('Updated Version 2'));
    });
  });

  group('Database Persistence & Repositories', () {
    test('DoctorProfile CRUD works correctly', () async {
      final profile = DoctorProfile(
        id: const DoctorId('doc-1'),
        name: 'Dr. Aarti Sharma',
        clinicName: 'City Clinic',
        qualifications: 'MBBS, MD',
        regNumber: 'REG-12345',
        templateConfig: const TemplateConfig(
          widthMm: 180,
          heightMm: 260,
          customTemplatePath: '/custom/template.png',
        ),
        preferences: const DoctorPreferences(
          defaultPenWidth: 2.0,
          defaultPenColor: '#003366',
        ),
      );

      final saveRes = await doctorRepo.saveProfile(profile);
      expect(saveRes.isSuccess, isTrue);

      final hasProfileRes = await doctorRepo.hasProfile();
      expect(hasProfileRes.valueOrNull, isTrue);

      final loadRes = await doctorRepo.getProfile();
      expect(loadRes.isSuccess, isTrue);
      final loaded = loadRes.valueOrNull!;
      expect(loaded.id, equals(profile.id));
      expect(loaded.name, equals('Dr. Aarti Sharma'));
      expect(loaded.templatePath, equals('/custom/template.png'));
      expect(loaded.preferences.defaultPenColor, equals('#003366'));
    });

    test('Patient CRUD and search work correctly', () async {
      final p1 = Patient(
        id: const PatientId('pat-1'),
        info: const PatientInfo(
          name: 'Ravi Kumar',
          age: 42,
          gender: 'Male',
          city: 'Pune',
          phoneNumber: '9876543210',
        ),
        history: const ClinicalHistory(
          previousConditions: ['Hypertension'],
          allergies: [
            Allergy(allergen: 'Penicillin', severity: 'High'),
          ],
          medications: [
            MedicationRecord(medicationName: 'Amlodipine', dosage: '5mg'),
          ],
        ),
      );

      final p2 = Patient(
        id: const PatientId('pat-2'),
        info: const PatientInfo(
          name: 'Pooja Verma',
          age: 29,
          gender: 'Female',
          city: 'Mumbai',
        ),
      );

      await patientRepo.createPatient(p1);
      await patientRepo.createPatient(p2);

      expect((await patientRepo.countPatients()).valueOrNull, equals(2));

      // Search by name
      final searchRavi = await patientRepo.searchPatients('ravi');
      expect(searchRavi.valueOrNull?.length, equals(1));
      expect(searchRavi.valueOrNull?.first.name, equals('Ravi Kumar'));
      expect(searchRavi.valueOrNull?.first.history.allergies.first.allergen, equals('Penicillin'));

      // Search by city
      final searchMumbai = await patientRepo.searchPatients('Mumbai');
      expect(searchMumbai.valueOrNull?.length, equals(1));
      expect(searchMumbai.valueOrNull?.first.name, equals('Pooja Verma'));

      // Update patient
      final updatedP1 = p1.copyWith(
        info: p1.info.copyWith(city: 'Bangalore'),
      );
      await patientRepo.updatePatient(updatedP1);
      final loadedP1 = await patientRepo.getPatientById(p1.id);
      expect(loadedP1.valueOrNull?.city, equals('Bangalore'));

      // Delete patient
      await patientRepo.deletePatient(p2.id);
      expect((await patientRepo.countPatients()).valueOrNull, equals(1));
    });

    test('Consultation CRUD and patient relation work correctly', () async {
      final consultation = Consultation(
        id: const ConsultationId('cons-101'),
        patientId: const PatientId('pat-1'),
        patientSnapshot: const PatientSnapshot(
          name: 'Ravi Kumar',
          age: 42,
          gender: 'Male',
          city: 'Pune',
        ),
        doctorSnapshot: const DoctorSnapshot(
          name: 'Dr. Aarti',
          clinic: 'City Clinic',
          qualifications: 'MBBS',
          regNumber: '123',
        ),
        pageDimensions: const PageDimensions(width: 180, height: 260),
        status: ConsultationStatus.saved,
        lipiRelativePath: 'patient/pat-1/prescriptions/consultation_cons-101.lipi',
      );

      await consultationRepo.upsertConsultation(consultation);

      final retrieved = await consultationRepo.getConsultationById(consultation.id);
      expect(retrieved.isSuccess, isTrue);
      expect(retrieved.valueOrNull?.patientSnapshot.name, equals('Ravi Kumar'));
      expect(retrieved.valueOrNull?.status, equals(ConsultationStatus.saved));

      final patientList = await consultationRepo.getConsultationsForPatient(const PatientId('pat-1'));
      expect(patientList.valueOrNull?.length, equals(1));

      // Reopening existing database on disk
      await database.close();
      final reopenedDb = VaultDatabase();
      await reopenedDb.open(vault.dbFile);
      final reopenedRepo = SqliteConsultationRepository(reopenedDb);

      final checkReopened = await reopenedRepo.getConsultationById(consultation.id);
      expect(checkReopened.valueOrNull?.id, equals(consultation.id));
      await reopenedDb.close();
    });

    test('Transaction rollback prevents inconsistent state', () async {
      try {
        await database.transaction((txn) async {
          await txn.insert('patients', {
            'id': 'pat-fail',
            'name': 'Should Rollback',
            'age': 30,
            'gender': 'Male',
            'city': 'Test',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          // Intentionally throw
          throw Exception('Simulated transaction failure');
        });
      } catch (_) {}

      // Verify pat-fail was rolled back
      final check = await patientRepo.getPatientById(const PatientId('pat-fail'));
      expect(check.valueOrNull, isNull);
    });
  });
}
