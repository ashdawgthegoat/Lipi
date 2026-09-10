import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/app/dependencies.dart';
import 'package:lipi/domains/consultation/models/clinical_document.dart';
import 'package:lipi/domains/doctor/models/doctor_profile.dart';
import 'package:lipi/domains/doctor/models/template_config.dart';
import 'package:lipi/domains/patient/models/patient.dart';
import 'package:lipi/domains/patient/models/patient_info.dart';
import 'package:lipi/infrastructure/database/vault_database.dart';
import 'package:lipi/infrastructure/security/secure_key_store.dart';
import 'package:lipi/presentation/first_launch/first_launch_screen.dart';
import 'package:lipi/presentation/patient/patient_workspace_screen.dart';
import 'package:lipi/presentation/patient/widgets/prescription_file_item.dart';
import 'package:lipi/presentation/patients/main_workspace_screen.dart';
import 'package:lipi/presentation/prescription/prescription_workspace_screen.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VaultDatabase.initializeFfiIfRequired();

  late Directory tempDir;
  late LipiDependencies deps;

  final doctorProfile = DoctorProfile(
    id: DoctorId('doc-ui-1'),
    name: 'Dr. Priya Mehta',
    clinicName: 'Mehta Multispeciality',
    qualifications: 'MBBS, DNB',
    regNumber: 'REG-54321',
    templateConfig: const TemplateConfig(widthMm: 180, heightMm: 260),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_ui_test_');
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

  group('Milestone 10 — Production Clinical UI Tests', () {
    testWidgets('FirstLaunchScreen validates input and saves profile', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        theme: deps.themeService.activeTheme.toThemeData(),
        home: FirstLaunchScreen(dependencies: deps),
      ));
      await tester.pump();

      expect(find.text('Doctor & Clinic Profile'), findsOneWidget);
      expect(find.text('Dr. Aarti Sharma'), findsOneWidget);
      expect(find.text('City Health Clinic'), findsOneWidget);

      final saveBtn = find.text('Save & Enter Workspace');
      expect(saveBtn, findsOneWidget);
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      DoctorProfile? stored;
      await tester.runAsync(() async {
        final storedRes = await deps.doctorRepository.getProfile();
        stored = storedRes.valueOrNull;
      });

      expect(stored, isNotNull);
      expect(stored!.name, equals('Dr. Aarti Sharma'));
    });

    testWidgets('MainWorkspaceScreen renders registered patients and search', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed doctor and a patient
      await tester.runAsync(() async {
        await deps.doctorRepository.saveProfile(doctorProfile);
        await deps.createPatientWorkflow.execute(
          info: const PatientInfo(
            name: 'Ravi Kumar',
            age: 42,
            gender: 'Male',
            city: 'Pune',
          ),
        );
      });

      await tester.pumpWidget(MaterialApp(
        theme: deps.themeService.activeTheme.toThemeData(),
        home: MainWorkspaceScreen(
          dependencies: deps,
          doctorProfile: doctorProfile,
        ),
      ));

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text('Mehta Multispeciality'), findsOneWidget);
      expect(find.text('Dr. Priya Mehta'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('42 Y • Male • Pune'), findsOneWidget);

      // Search for Ravi
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Ravi');
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text('Ravi Kumar'), findsOneWidget);

      // Search for non-existent patient
      await tester.enterText(searchField, 'NonExistent');
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text('No matching patients found'), findsOneWidget);
    });

    testWidgets('PatientWorkspaceScreen renders details and starts prescription', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final patientInfo = const PatientInfo(
        name: 'Sunita Roy',
        age: 35,
        gender: 'Female',
        city: 'Kolkata',
      );

      late Patient patient;
      await tester.runAsync(() async {
        final pRes = await deps.createPatientWorkflow.execute(info: patientInfo);
        patient = pRes.valueOrNull!;
      });

      await tester.pumpWidget(MaterialApp(
        theme: deps.themeService.activeTheme.toThemeData(),
        home: PatientWorkspaceScreen(
          dependencies: deps,
          doctorProfile: doctorProfile,
          patient: patient,
        ),
      ));

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text('Sunita Roy'), findsWidgets);
      expect(find.text('35 Years'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Kolkata'), findsOneWidget);
      expect(find.text('No prescriptions recorded yet'), findsOneWidget);
      expect(find.text('New Prescription'), findsOneWidget);
    });

    testWidgets('PatientWorkspaceScreen supports deleting a specific prescription with confirmation', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late Patient patient;
      final cid1 = ConsultationId('con-del-1');
      final cid2 = ConsultationId('con-keep-2');

      await tester.runAsync(() async {
        await deps.doctorRepository.saveProfile(doctorProfile);
        final pRes = await deps.createPatientWorkflow.execute(
          info: const PatientInfo(
            name: 'Anjali Bose',
            age: 29,
            gender: 'Female',
            city: 'Bengaluru',
          ),
        );
        patient = pRes.valueOrNull!;

        // Create 2 prescriptions
        await deps.startConsultationWorkflow.execute(
          patientId: patient.id,
          consultationId: cid1,
        );
        await deps.startConsultationWorkflow.execute(
          patientId: patient.id,
          consultationId: cid2,
        );
      });

      await tester.pumpWidget(MaterialApp(
        theme: deps.themeService.activeTheme.toThemeData(),
        home: PatientWorkspaceScreen(
          dependencies: deps,
          doctorProfile: doctorProfile,
          patient: patient,
        ),
      ));

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Both prescriptions should be listed
      expect(find.byKey(Key('delete_prescription_${cid1.value}')), findsOneWidget);
      expect(find.byKey(Key('delete_prescription_${cid2.value}')), findsOneWidget);

      // Tap delete on prescription 1
      await tester.tap(find.byKey(Key('delete_prescription_${cid1.value}')));
      await tester.pumpAndSettle();

      // Destructive confirmation dialog appears
      expect(find.text('Delete Prescription?'), findsOneWidget);
      expect(find.text('Delete Permanently'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.textContaining('con-del-1'), findsNothing);

      // Cancel first -> nothing should be deleted
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Prescription?'), findsNothing);
      expect(find.byKey(Key('delete_prescription_${cid1.value}')), findsOneWidget);

      // Tap delete again and confirm
      await tester.tap(find.byKey(Key('delete_prescription_${cid1.value}')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Permanently'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        final exists = await tester.runAsync(() => deps.documentRepository.documentExists(patient.id, cid1));
        if (exists?.valueOrNull == false) break;
      }

      // Allow _loadConsultations to complete and dismiss spinner
      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      // Verify prescription 1 is removed from the UI
      expect(find.byKey(Key('delete_prescription_${cid1.value}')), findsNothing);
      // Verify prescription 2 remains in the UI
      expect(find.byKey(Key('delete_prescription_${cid2.value}')), findsOneWidget);

      // Verify on disk and database
      await tester.runAsync(() async {
        expect((await deps.documentRepository.documentExists(patient.id, cid1)).valueOrNull, isFalse);
        expect((await deps.documentRepository.documentExists(patient.id, cid2)).valueOrNull, isTrue);
      });
    });

    testWidgets('MainWorkspaceScreen supports deleting a patient via long-press contextual dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late Patient patient;
      final patId = PatientId('pat-longpress-del');

      await tester.runAsync(() async {
        await deps.doctorRepository.saveProfile(doctorProfile);
        final pRes = await deps.createPatientWorkflow.execute(
          id: patId,
          info: const PatientInfo(
            name: 'Kavita Sen',
            age: 38,
            gender: 'Female',
            city: 'Delhi',
          ),
        );
        patient = pRes.valueOrNull!;
      });

      await tester.pumpWidget(MaterialApp(
        theme: deps.themeService.activeTheme.toThemeData(),
        home: MainWorkspaceScreen(
          dependencies: deps,
          doctorProfile: doctorProfile,
        ),
      ));

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.text('Kavita Sen'), findsOneWidget);

      // Long-press on patient folder
      await tester.longPress(find.byKey(Key('patient_folder_${patient.id.value}')));
      await tester.pumpAndSettle();

      // Contextual dialog appears with "Delete Patient"
      expect(find.text('Delete Patient'), findsOneWidget);
      expect(find.text('Open Patient Folder'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Cancel contextual dialog -> patient remains
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Kavita Sen'), findsOneWidget);

      // Long press again
      await tester.longPress(find.byKey(Key('patient_folder_${patient.id.value}')));
      await tester.pumpAndSettle();

      // Tap Delete Patient in contextual dialog
      await tester.tap(find.text('Delete Patient'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Confirm Patient Deletion'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // Ensure internal ID is NOT exposed in the confirmation UI
      expect(find.textContaining('pat-longpress-del'), findsNothing);

      // Cancel confirmation -> patient remains
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Patient Deletion'), findsNothing);
      expect(find.text('Kavita Sen'), findsOneWidget);

      // Long press -> Delete Patient -> Confirm Delete
      await tester.longPress(find.byKey(Key('patient_folder_${patient.id.value}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Patient'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for deletion
      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        final exists = await tester.runAsync(() => deps.patientRepository.getPatientById(patId));
        if (exists?.valueOrNull == null) break;
      }

      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      // Patient is removed from UI
      expect(find.text('Kavita Sen'), findsNothing);

      // Verify in DB
      await tester.runAsync(() async {
        final p = await deps.patientRepository.getPatientById(patId);
        expect(p.valueOrNull, isNull);
      });
    });

    testWidgets('PatientWorkspaceScreen supports deleting prescription via long-press contextual dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late Patient patient;
      final cid1 = ConsultationId('con-longpress-del-1');
      final cid2 = ConsultationId('con-longpress-keep-2');

      await tester.runAsync(() async {
        await deps.doctorRepository.saveProfile(doctorProfile);
        final pRes = await deps.createPatientWorkflow.execute(
          info: const PatientInfo(
            name: 'Deepak Verma',
            age: 41,
            gender: 'Male',
            city: 'Chennai',
          ),
        );
        patient = pRes.valueOrNull!;

        await deps.startConsultationWorkflow.execute(
          patientId: patient.id,
          consultationId: cid1,
        );
        await deps.startConsultationWorkflow.execute(
          patientId: patient.id,
          consultationId: cid2,
        );
      });

      await tester.pumpWidget(MaterialApp(
        theme: deps.themeService.activeTheme.toThemeData(),
        home: PatientWorkspaceScreen(
          dependencies: deps,
          doctorProfile: doctorProfile,
          patient: patient,
        ),
      ));

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      final files = find.byType(PrescriptionFileItem);
      expect(files, findsNWidgets(2));

      final rx1Finder = find.ancestor(
        of: find.byKey(Key('delete_prescription_${cid1.value}')),
        matching: find.byType(PrescriptionFileItem),
      );

      // Long press on prescription 1
      await tester.longPress(rx1Finder);
      await tester.pumpAndSettle();

      // Contextual dialog appears
      expect(find.text('Delete Prescription'), findsOneWidget);
      expect(find.text('Open Prescription'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Cancel contextual dialog -> nothing deleted
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(PrescriptionFileItem), findsNWidgets(2));

      // Long press again -> tap Delete Prescription
      await tester.longPress(rx1Finder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Prescription'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Delete Prescription?'), findsOneWidget);
      expect(find.text('Delete Permanently'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // Ensure internal ID is NOT exposed in the confirmation dialog
      expect(find.textContaining('con-longpress-del'), findsNothing);

      // Cancel confirmation -> nothing deleted
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Prescription?'), findsNothing);
      expect(find.byType(PrescriptionFileItem), findsNWidgets(2));

      // Long press -> Delete Prescription -> Delete Permanently
      await tester.longPress(rx1Finder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Prescription'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Permanently'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        final exists = await tester.runAsync(() => deps.documentRepository.documentExists(patient.id, cid1));
        if (exists?.valueOrNull == false) break;
      }

      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      // One prescription remains
      expect(find.byType(PrescriptionFileItem), findsOneWidget);

      await tester.runAsync(() async {
        expect((await deps.documentRepository.documentExists(patient.id, cid1)).valueOrNull, isFalse);
        expect((await deps.documentRepository.documentExists(patient.id, cid2)).valueOrNull, isTrue);
      });
    });

    testWidgets('PrescriptionWorkspaceScreen renders desktop canvas and save status', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late Patient patient;
      final consultationId = ConsultationId('con-rx-1');
      late ClinicalDocument doc;

      await tester.runAsync(() async {
        await deps.doctorRepository.saveProfile(doctorProfile);
        final pRes = await deps.createPatientWorkflow.execute(
          info: const PatientInfo(
            name: 'Vikram Singh',
            age: 50,
            gender: 'Male',
            city: 'Jaipur',
          ),
        );
        patient = pRes.valueOrNull!;

        final startRes = await deps.startConsultationWorkflow.execute(
          patientId: patient.id,
          consultationId: consultationId,
        );
        doc = startRes.valueOrNull!;
      });

      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(
        theme: deps.themeService.activeTheme.toThemeData(),
        home: PrescriptionWorkspaceScreen(
          dependencies: deps,
          doctorProfile: doctorProfile,
          patient: patient,
          consultationId: consultationId,
          isReopen: false,
          initialDocument: doc,
        ),
      ));

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text('Prescription — Vikram Singh (50 Y)'), findsOneWidget);
      expect(find.text('Desktop Stylus Mode'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);

      // Use pointer events directly on the canvas to draw a stroke
      final canvasFinder = find.byKey(const Key('desktop_drawing_canvas'));
      await tester.drag(canvasFinder, const Offset(60, 0));
      await tester.pump();

      // State transitions to unsaved / dirty
      expect(find.text('Unsaved changes'), findsOneWidget);

      // Tap Done -> triggers immediate save
      await tester.runAsync(() async {
        await tester.tap(find.text('Done'));
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      ClinicalDocument? loaded;
      await tester.runAsync(() async {
        final loadRes = await deps.loadConsultationWorkflow.execute(
          patientId: patient.id,
          consultationId: consultationId,
        );
        loaded = loadRes.valueOrNull;
      });

      expect(loaded, isNotNull);
      expect(loaded!.ink.strokeCount, greaterThanOrEqualTo(1));
    });
  });
}
