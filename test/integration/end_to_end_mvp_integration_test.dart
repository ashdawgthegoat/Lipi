import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:lipi/app/dependencies.dart';
import 'package:lipi/app/workflows/initialize_application_workflow.dart';
import 'package:lipi/domains/consultation/models/consultation_status.dart';
import 'package:lipi/domains/consultation/models/ink_document.dart';
import 'package:lipi/domains/consultation/models/stroke.dart';
import 'package:lipi/domains/consultation/models/stroke_point.dart';
import 'package:lipi/domains/doctor/models/doctor_profile.dart';
import 'package:lipi/domains/doctor/models/template_config.dart';
import 'package:lipi/domains/patient/models/allergy.dart';
import 'package:lipi/domains/patient/models/clinical_history.dart';
import 'package:lipi/domains/patient/models/patient_info.dart';
import 'package:lipi/infrastructure/database/vault_database.dart';
import 'package:lipi/infrastructure/export/pdf_exporter.dart';
import 'package:lipi/infrastructure/security/secure_key_store.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VaultDatabase.initializeFfiIfRequired();

  late Directory tempVaultDir;
  late LipiDependencies deps;

  setUp(() async {
    tempVaultDir = await Directory.systemTemp.createTemp('lipi_e2e_test_');
    deps = await LipiDependencies.create(
      customVaultDir: tempVaultDir,
      customSecureStorage: InMemorySecureKeyStore(),
    );
  });

  tearDown(() async {
    await deps.dispose();
    if (await tempVaultDir.exists()) {
      await tempVaultDir.delete(recursive: true);
    }
  });

  group('Milestone 13 — End-to-End Integration Test', () {
    test('Executes complete clinical MVP lifecycle against real production stack', () async {
      // 1. Fresh Launch Detection
      final initRes = await deps.initWorkflow.execute();
      expect(initRes.isSuccess, isTrue);
      expect(initRes.valueOrNull!.destination, equals(AppLaunchDestination.doctorSetup));

      // 2. Doctor Setup
      final doctorProfile = DoctorProfile(
        id: const DoctorId('doc-e2e-1'),
        name: 'Dr. Radhika Sen',
        clinicName: 'Sen Multispecialty Clinic',
        qualifications: 'MBBS, MD (Medicine)',
        regNumber: 'WB-MED-445566',
      );
      final doctorRes = await deps.configureDoctorWorkflow.execute(profile: doctorProfile);
      expect(doctorRes.isSuccess, isTrue);

      // Verify app initialization now succeeds
      final initPostDoc = await deps.initWorkflow.execute();
      expect(initPostDoc.isSuccess, isTrue);
      expect(initPostDoc.valueOrNull!.destination, equals(AppLaunchDestination.mainWorkspace));

      // 3. Template Setup
      const templateConfig = TemplateConfig(
        widthMm: 210.0,
        heightMm: 297.0,
        unit: 'mm',
      );
      final tmplRes = await deps.configureTemplateWorkflow.execute(
        templateConfig: templateConfig,
      );
      expect(tmplRes.isSuccess, isTrue);
      expect(tmplRes.valueOrNull!.templateConfig, isNotNull);
      expect(tmplRes.valueOrNull!.templateConfig.widthMm, equals(210.0));

      // 4. Create Patient with full clinical info
      const patientInfo = PatientInfo(
        name: 'Aarav Mukherjee',
        age: 42,
        gender: 'Male',
        city: 'Kolkata',
        phoneNumber: '+91 98765 43210',
        heightCm: 175.0,
        weightKg: 78.5,
      );
      const clinicalHistory = ClinicalHistory(
        previousConditions: ['Type 2 Diabetes', 'Hypertension'],
        allergies: [
          Allergy(allergen: 'Penicillin', severity: 'Severe', reaction: 'Anaphylaxis'),
        ],
      );

      final createPatientRes = await deps.createPatientWorkflow.execute(
        info: patientInfo,
        history: clinicalHistory,
      );
      expect(createPatientRes.isSuccess, isTrue);
      final patient = createPatientRes.valueOrNull!;
      expect(patient.name, equals('Aarav Mukherjee'));
      expect(patient.history.allergies.first.allergen, equals('Penicillin'));

      // 5. Open Patient Workspace
      final openPatientRes = await deps.openPatientWorkflow.execute(patient.id);
      expect(openPatientRes.isSuccess, isTrue);
      final patientWorkspace = openPatientRes.valueOrNull!;
      expect(patientWorkspace.patient.name, equals('Aarav Mukherjee'));
      expect(patientWorkspace.consultations, isEmpty);

      // 6. Create / Start Prescription
      final consultationId = ConsultationId('consultation-e2e-001');
      final startPrescriptionRes = await deps.startConsultationWorkflow.execute(
        patientId: patient.id,
        consultationId: consultationId,
      );
      expect(startPrescriptionRes.isSuccess, isTrue);
      var currentDocument = startPrescriptionRes.valueOrNull!;
      expect(currentDocument.patientSnapshot.name, equals('Aarav Mukherjee'));
      expect(currentDocument.doctorSnapshot?.clinic, equals('Sen Multispecialty Clinic'));
      expect(currentDocument.ink.isEmpty, isTrue);

      // 7. Write with Stylus (Add realistic digital ink strokes)
      final stroke1 = Stroke(
        points: const [
          StrokePoint(x: 100.0, y: 200.0, pressure: 0.6),
          StrokePoint(x: 110.0, y: 205.0, pressure: 0.7),
          StrokePoint(x: 125.0, y: 215.0, pressure: 0.65),
          StrokePoint(x: 140.0, y: 220.0, pressure: 0.5),
        ],
        color: '#1A365D',
        strokeWidth: 2.5,
      );

      final stroke2 = Stroke(
        points: const [
          StrokePoint(x: 100.0, y: 250.0, pressure: 0.5),
          StrokePoint(x: 130.0, y: 250.0, pressure: 0.6),
          StrokePoint(x: 160.0, y: 252.0, pressure: 0.55),
        ],
        color: '#1A365D',
        strokeWidth: 2.0,
      );

      currentDocument = currentDocument.copyWith(
        ink: InkDocument(strokes: [stroke1, stroke2]),
      );
      expect(currentDocument.ink.strokeCount, equals(2));

      // 8. Autosave / Persist
      final saveRes = await deps.writeCoordinator.requestWrite(
        patientId: patient.id,
        document: currentDocument,
        status: ConsultationStatus.saved,
      );
      expect(saveRes.isSuccess, isTrue);

      // 9. Leave Prescription & 10. Reopen
      final reloadRes = await deps.loadConsultationWorkflow.execute(
        patientId: patient.id,
        consultationId: consultationId,
      );
      expect(reloadRes.isSuccess, isTrue);
      final reloadedDoc = reloadRes.valueOrNull!;

      // 11. Verify Handwriting Fidelity (Coordinates, Points, Pressure, Color)
      expect(reloadedDoc.ink.strokeCount, equals(2));
      expect(reloadedDoc.ink.strokes.first.points.length, equals(4));
      expect(reloadedDoc.ink.strokes.first.points.first.x, equals(100.0));
      expect(reloadedDoc.ink.strokes.first.points.first.pressure, equals(0.6));
      expect(reloadedDoc.ink.strokes.first.color, equals('#1A365D'));

      // 12. Open History
      final historyRes = await deps.listConsultationHistoryWorkflow.execute(patient.id);
      expect(historyRes.isSuccess, isTrue);
      final historyList = historyRes.valueOrNull!;
      expect(historyList.length, equals(1));
      expect(historyList.first.id, equals(consultationId));

      // 13. Edit Intentionally (Add 3rd stroke)
      final stroke3 = Stroke(
        points: const [
          StrokePoint(x: 200.0, y: 300.0, pressure: 0.8),
          StrokePoint(x: 220.0, y: 310.0, pressure: 0.75),
        ],
        color: '#0F172A',
        strokeWidth: 1.8,
      );
      final updatedDoc = reloadedDoc.copyWith(
        ink: InkDocument(strokes: [...reloadedDoc.ink.strokes, stroke3]),
      );

      // 14. Verify Persistence of Intentional Edit
      final secondSave = await deps.writeCoordinator.requestWrite(
        patientId: patient.id,
        document: updatedDoc,
        status: ConsultationStatus.saved,
      );
      expect(secondSave.isSuccess, isTrue);

      final reloadSecond = await deps.loadConsultationWorkflow.execute(
        patientId: patient.id,
        consultationId: consultationId,
      );
      expect(reloadSecond.isSuccess, isTrue);
      expect(reloadSecond.valueOrNull!.ink.strokeCount, equals(3));

      // 15. Export PDF (Verify zero displacement and PDF generation without altering canonical source)
      final pdfBytes = await PdfExporter.generatePdfBytes(
        document: reloadSecond.valueOrNull!,
      );
      expect(pdfBytes.isNotEmpty, isTrue);
      // Valid PDF magic header %PDF-
      expect(String.fromCharCodes(pdfBytes.take(5)), equals('%PDF-'));

      // Canonical document unchanged after PDF export
      final docAfterPdf = await deps.loadConsultationWorkflow.execute(
        patientId: patient.id,
        consultationId: consultationId,
      );
      expect(docAfterPdf.valueOrNull!.ink.strokeCount, equals(3));

      // 16. Search Patient
      final searchRes = await deps.searchPatientsWorkflow.execute('Aarav');
      expect(searchRes.isSuccess, isTrue);
      expect(searchRes.valueOrNull!.length, equals(1));
      expect(searchRes.valueOrNull!.first.name, equals('Aarav Mukherjee'));

      // 17. Delete Patient Intentionally (Verify database and filesystem cleanup)
      final deleteRes = await deps.deletePatientWorkflow.execute(patient.id);
      expect(deleteRes.isSuccess, isTrue);

      // Search should return no results
      final searchAfterDelete = await deps.searchPatientsWorkflow.execute('Aarav');
      expect(searchAfterDelete.valueOrNull, isEmpty);

      // Patient directory on disk should be removed
      final patientDirPath = p.join(deps.vault.rootDir.path, deps.vault.getPatientFolderRelativePath(patient.id));
      expect(await Directory(patientDirPath).exists(), isFalse);
    });
  });
}
