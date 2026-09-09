import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/app/dependencies.dart';
import 'package:lipi/domains/consultation/models/consultation.dart';
import 'package:lipi/domains/consultation/models/consultation_status.dart';
import 'package:lipi/domains/consultation/models/doctor_snapshot.dart';
import 'package:lipi/domains/consultation/models/page_dimensions.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/doctor/models/doctor_preferences.dart';
import 'package:lipi/domains/doctor/models/doctor_profile.dart';
import 'package:lipi/domains/doctor/models/template_config.dart';
import 'package:lipi/domains/patient/models/patient.dart';
import 'package:lipi/domains/patient/models/patient_info.dart';
import 'package:lipi/infrastructure/database/vault_database.dart';
import 'package:lipi/infrastructure/security/secure_key_store.dart';
import 'package:lipi/presentation/patient/patient_workspace_screen.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VaultDatabase.initializeFfiIfRequired();

  late Directory tempDir;
  late LipiDependencies deps;

  final doctor = DoctorProfile(
    id: DoctorId('doc-ui-search'),
    name: 'Dr. Ramesh Rao',
    clinicName: 'Rao Clinic',
    qualifications: 'MBBS, MD',
    regNumber: 'MCI-8899',
    templateConfig: const TemplateConfig(),
    preferences: const DoctorPreferences(),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_search_ui_test_');
    deps = await LipiDependencies.create(
      customVaultDir: tempDir,
      customSecureStorage: InMemorySecureKeyStore(),
    );
  });

  tearDown(() async {
    await deps.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('PatientWorkspaceScreen search field filters consultations and restores on clear', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late Patient patient;
    final cid1 = ConsultationId('c-sep08');
    final cid2 = ConsultationId('c-aug15');

    await tester.runAsync(() async {
      await deps.doctorRepository.saveProfile(doctor);
      final pRes = await deps.createPatientWorkflow.execute(
        info: const PatientInfo(
          name: 'Anjali Sharma',
          age: 28,
          gender: 'Female',
          city: 'Mumbai',
        ),
      );
      patient = pRes.valueOrNull!;

      final c1 = Consultation(
        id: cid1,
        patientId: patient.id,
        patientSnapshot: PatientSnapshot(name: patient.name, age: patient.age, gender: patient.gender, city: patient.city),
        doctorSnapshot: DoctorSnapshot(name: doctor.name, clinic: doctor.clinicName, qualifications: doctor.qualifications, regNumber: doctor.regNumber),
        pageDimensions: const PageDimensions(width: 180, height: 260, unit: 'mm'),
        status: ConsultationStatus.saved,
        lipiRelativePath: 'patient/${patient.id.value}/prescriptions/${cid1.value}.lipi',
        createdAt: DateTime(2026, 9, 8, 10, 0),
        updatedAt: DateTime(2026, 9, 8, 10, 0),
      );

      final c2 = Consultation(
        id: cid2,
        patientId: patient.id,
        patientSnapshot: PatientSnapshot(name: patient.name, age: patient.age, gender: patient.gender, city: patient.city),
        doctorSnapshot: DoctorSnapshot(name: doctor.name, clinic: doctor.clinicName, qualifications: doctor.qualifications, regNumber: doctor.regNumber),
        pageDimensions: const PageDimensions(width: 180, height: 260, unit: 'mm'),
        status: ConsultationStatus.saved,
        lipiRelativePath: 'patient/${patient.id.value}/prescriptions/${cid2.value}.lipi',
        createdAt: DateTime(2026, 8, 15, 15, 30),
        updatedAt: DateTime(2026, 8, 15, 15, 30),
      );

      await deps.consultationRepository.upsertConsultation(c1);
      await deps.consultationRepository.upsertConsultation(c2);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: deps.themeService.activeTheme.toThemeData(),
        home: PatientWorkspaceScreen(
          dependencies: deps,
          doctorProfile: doctor,
          patient: patient,
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify both are listed initially
    expect(find.text('2 Prescriptions'), findsOneWidget);
    expect(find.byKey(const Key('patient_prescription_search_field')), findsOneWidget);

    // Search for "August"
    await tester.enterText(find.byKey(const Key('patient_prescription_search_field')), 'August');
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1 Found'), findsOneWidget);

    // Search for non-existent date
    await tester.enterText(find.byKey(const Key('patient_prescription_search_field')), '2029');
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('0 Found'), findsOneWidget);
    expect(find.text('No prescriptions found matching "2029"'), findsOneWidget);
    expect(find.text('Clear search filter'), findsOneWidget);

    // Tap "Clear search filter" button
    await tester.tap(find.text('Clear search filter'));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('2 Prescriptions'), findsOneWidget);
  });
}
