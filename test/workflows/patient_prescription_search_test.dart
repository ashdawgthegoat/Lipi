import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/app/workflows/consultation_workflows.dart';
import 'package:lipi/app/workflows/patient_workflows.dart';
import 'package:lipi/domains/consultation/models/consultation.dart';
import 'package:lipi/domains/consultation/models/consultation_status.dart';
import 'package:lipi/domains/consultation/models/doctor_snapshot.dart';
import 'package:lipi/domains/consultation/models/page_dimensions.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/patient/models/patient_info.dart';
import 'package:lipi/infrastructure/database/sqlite_consultation_repository.dart';
import 'package:lipi/infrastructure/database/sqlite_patient_repository.dart';
import 'package:lipi/infrastructure/database/vault_database.dart';
import 'package:lipi/infrastructure/vault/vault.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VaultDatabase.initializeFfiIfRequired();

  group('Patient-Scoped Prescription Search Tests', () {
    late Directory tempDir;
    late LipiVault vault;
    late VaultDatabase database;
    late SqlitePatientRepository patientRepo;
    late SqliteConsultationRepository consultationRepo;
    late CreatePatientWorkflow createPatientWorkflow;
    late SearchConsultationsWorkflow searchConsultationsWorkflow;
    late ListConsultationHistoryWorkflow listConsultationHistoryWorkflow;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('lipi_search_test_');
      vault = LipiVault(tempDir);
      await vault.initialize();

      database = VaultDatabase();
      await database.open(vault.dbFile);

      patientRepo = SqlitePatientRepository(database);
      consultationRepo = SqliteConsultationRepository(database);

      createPatientWorkflow = CreatePatientWorkflow(
        vault: vault,
        patientRepository: patientRepo,
      );
      searchConsultationsWorkflow = SearchConsultationsWorkflow(
        consultationRepository: consultationRepo,
      );
      listConsultationHistoryWorkflow = ListConsultationHistoryWorkflow(
        consultationRepository: consultationRepo,
      );
    });

    tearDown(() async {
      await database.close();
      vault.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Searches within patient history by date, ID, status and preserves patient scoping', () async {
      // 1. Create Patient A and Patient B
      final pResA = await createPatientWorkflow.execute(
        info: const PatientInfo(name: 'Ramesh Kumar', age: 45, gender: 'Male', city: 'Jaipur'),
      );
      final patientA = pResA.valueOrNull!;

      final pResB = await createPatientWorkflow.execute(
        info: const PatientInfo(name: 'Sunita Sharma', age: 38, gender: 'Female', city: 'Delhi'),
      );
      final patientB = pResB.valueOrNull!;

      // 2. Insert structured consultations for Patient A on specific dates
      final c1 = Consultation(
        id: ConsultationId('c-ramesh-sep08'),
        patientId: patientA.id,
        patientSnapshot: PatientSnapshot(name: patientA.name, age: patientA.age, gender: patientA.gender, city: patientA.city),
        doctorSnapshot: const DoctorSnapshot(name: 'Dr. Rao', clinic: 'Apollo', qualifications: 'MD', regNumber: '123'),
        pageDimensions: const PageDimensions(width: 180, height: 260, unit: 'mm'),
        status: ConsultationStatus.saved,
        lipiRelativePath: 'patient/${patientA.id.value}/prescriptions/c-ramesh-sep08.lipi',
        createdAt: DateTime(2026, 9, 8, 10, 30),
        updatedAt: DateTime(2026, 9, 8, 10, 30),
      );

      final c2 = Consultation(
        id: ConsultationId('c-ramesh-aug21'),
        patientId: patientA.id,
        patientSnapshot: PatientSnapshot(name: patientA.name, age: patientA.age, gender: patientA.gender, city: patientA.city),
        doctorSnapshot: const DoctorSnapshot(name: 'Dr. Rao', clinic: 'Apollo', qualifications: 'MD', regNumber: '123'),
        pageDimensions: const PageDimensions(width: 180, height: 260, unit: 'mm'),
        status: ConsultationStatus.saved,
        lipiRelativePath: 'patient/${patientA.id.value}/prescriptions/c-ramesh-aug21.lipi',
        createdAt: DateTime(2026, 8, 21, 14, 15),
        updatedAt: DateTime(2026, 8, 21, 14, 15),
      );

      final c3 = Consultation(
        id: ConsultationId('c-ramesh-jul12'),
        patientId: patientA.id,
        patientSnapshot: PatientSnapshot(name: patientA.name, age: patientA.age, gender: patientA.gender, city: patientA.city),
        doctorSnapshot: const DoctorSnapshot(name: 'Dr. Rao', clinic: 'Apollo', qualifications: 'MD', regNumber: '123'),
        pageDimensions: const PageDimensions(width: 180, height: 260, unit: 'mm'),
        status: ConsultationStatus.active,
        lipiRelativePath: 'patient/${patientA.id.value}/prescriptions/c-ramesh-jul12.lipi',
        createdAt: DateTime(2026, 7, 12, 11, 0),
        updatedAt: DateTime(2026, 7, 12, 11, 0),
      );

      // Consultation for Patient B on 2026-09-08 (same date as c1)
      final cB = Consultation(
        id: ConsultationId('c-sunita-sep08'),
        patientId: patientB.id,
        patientSnapshot: PatientSnapshot(name: patientB.name, age: patientB.age, gender: patientB.gender, city: patientB.city),
        doctorSnapshot: const DoctorSnapshot(name: 'Dr. Rao', clinic: 'Apollo', qualifications: 'MD', regNumber: '123'),
        pageDimensions: const PageDimensions(width: 180, height: 260, unit: 'mm'),
        status: ConsultationStatus.saved,
        lipiRelativePath: 'patient/${patientB.id.value}/prescriptions/c-sunita-sep08.lipi',
        createdAt: DateTime(2026, 9, 8, 16, 0),
        updatedAt: DateTime(2026, 9, 8, 16, 0),
      );

      await consultationRepo.upsertConsultation(c1);
      await consultationRepo.upsertConsultation(c2);
      await consultationRepo.upsertConsultation(c3);
      await consultationRepo.upsertConsultation(cB);

      // 3. Test: Empty query returns all 3 for Patient A, ordered newest first
      final allRes = await searchConsultationsWorkflow.execute(patientId: patientA.id, query: '');
      expect(allRes.isSuccess, isTrue);
      final all = allRes.valueOrNull!;
      expect(all.length, 3);
      expect(all.map((c) => c.id.value).toList(), ['c-ramesh-sep08', 'c-ramesh-aug21', 'c-ramesh-jul12']);

      // 4. Test: Search by ISO date "2026-09-08" -> returns c1 only, strictly excludes cB (Patient B)
      final sepRes = await searchConsultationsWorkflow.execute(patientId: patientA.id, query: '2026-09-08');
      expect(sepRes.isSuccess, isTrue);
      final sepMatches = sepRes.valueOrNull!;
      expect(sepMatches.length, 1);
      expect(sepMatches.first.id.value, 'c-ramesh-sep08');
      expect(sepMatches.every((c) => c.patientId == patientA.id), isTrue);

      // 5. Test: Search by month "August" or "Aug" -> returns c2
      final augRes = await searchConsultationsWorkflow.execute(patientId: patientA.id, query: 'August');
      expect(augRes.isSuccess, isTrue);
      expect(augRes.valueOrNull!.length, 1);
      expect(augRes.valueOrNull!.first.id.value, 'c-ramesh-aug21');

      // 6. Test: Search by ID fragment "jul12" -> returns c3
      final idRes = await searchConsultationsWorkflow.execute(patientId: patientA.id, query: 'jul12');
      expect(idRes.isSuccess, isTrue);
      expect(idRes.valueOrNull!.length, 1);
      expect(idRes.valueOrNull!.first.id.value, 'c-ramesh-jul12');

      // 7. Test: Non-matching query returns empty list
      final noneRes = await searchConsultationsWorkflow.execute(patientId: patientA.id, query: 'nonexistent-query-2029');
      expect(noneRes.isSuccess, isTrue);
      expect(noneRes.valueOrNull!, isEmpty);

      // 8. Test: Search does NOT mutate records (consultation count in DB unchanged)
      final listRes = await listConsultationHistoryWorkflow.execute(patientA.id);
      expect(listRes.valueOrNull!.length, 3);
    });
  });
}
