import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:lipi_s4_prototype/domains/doctor/doctor_service.dart';
import 'package:lipi_s4_prototype/domains/doctor/models/doctor_profile.dart';
import 'package:lipi_s4_prototype/domains/patient/patient_service.dart';
import 'package:lipi_s4_prototype/infrastructure/export/pdf_exporter.dart';
import 'package:lipi_s4_prototype/infrastructure/ink/inkml_converter.dart';
import 'package:lipi_s4_prototype/infrastructure/storage/lipi_database.dart';
import 'package:lipi_s4_prototype/infrastructure/storage/lipi_package.dart';
import 'package:lipi_s4_prototype/infrastructure/storage/vault.dart';

void main() {
  late Directory tempDir;
  late LipiVault vault;
  late LipiDatabase database;
  late DoctorService doctorService;
  late PatientService patientService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_roundtrip_test_');
    vault = LipiVault(tempDir);
    await vault.initialize();

    database = LipiDatabase();
    await database.init(vault.dbFile);

    doctorService = DoctorService(vault: vault, database: database);
    patientService = PatientService(vault: vault, database: database);
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Full Lipi Prescription Workflow: Create -> Write -> Auto-save .lipi -> Reopen -> Export PDF', () async {
    // ── Phase 1: Doctor Setup (First Run) ──
    final docProfile = DoctorProfile(
      id: const Uuid().v4(),
      name: 'Dr. Aarti Sharma',
      clinicName: 'City Health Clinic',
      qualifications: 'MBBS, MD (General Medicine)',
      regNumber: 'MCI-45892',
      templateWidthMm: 180.0,
      templateHeightMm: 260.0,
      templateUnit: 'mm',
    );
    await doctorService.saveProfile(docProfile);

    final retrievedDoc = await doctorService.getProfile();
    expect(retrievedDoc, isNotNull);
    expect(retrievedDoc!.name, 'Dr. Aarti Sharma');

    // ── Phase 2: Patient Creation ──
    final patient = await patientService.createPatient(
      name: 'Ravi Kumar',
      age: 42,
      gender: 'Male',
      city: 'Pune',
    );
    expect(patient.id, isNotEmpty);
    expect(await vault.getPatientFolder(patient.id).exists(), isTrue);

    // ── Phase 3: Create Prescription Consultation ──
    final consultationId = const Uuid().v4();
    final template = retrievedDoc;

    // Doctor Domain provides template page dimensions
    expect(template.templateWidthMm, 180.0);
    expect(template.templateHeightMm, 260.0);

    // ── Phase 4: Doctor Writes Handwriting (Simulated Excalidraw Freedraw Strokes) ──
    // Multiple prescription lines: Paracetamol, Amoxicillin, Rest instructions
    final excalidrawStrokes = [
      // Line 1: "Rx Tab Paracetamol 650mg TDS"
      {
        'id': 'stroke_1',
        'type': 'freedraw',
        'x': 60.0,
        'y': 150.0,
        'width': 220.0,
        'height': 25.0,
        'strokeColor': '#000000',
        'strokeWidth': 1.5,
        'points': [
          [0.0, 0.0],
          [50.0, 10.0],
          [120.0, 5.0],
          [180.0, 12.0],
          [220.0, 8.0],
        ],
        'pressures': [0.5, 0.6, 0.7, 0.6, 0.5],
        'isDeleted': false,
      },
      // Line 2: "Cap Amoxicillin 500mg BD x 5 days"
      {
        'id': 'stroke_2',
        'type': 'freedraw',
        'x': 60.0,
        'y': 200.0,
        'width': 240.0,
        'height': 30.0,
        'strokeColor': '#1a365d',
        'strokeWidth': 2.0,
        'points': [
          [0.0, 0.0],
          [60.0, 8.0],
          [130.0, 12.0],
          [200.0, 15.0],
          [240.0, 10.0],
        ],
        'pressures': [0.4, 0.6, 0.8, 0.7, 0.4],
        'isDeleted': false,
      },
      // Line 3: "Adequate hydration & rest"
      {
        'id': 'stroke_3',
        'type': 'freedraw',
        'x': 60.0,
        'y': 250.0,
        'width': 190.0,
        'height': 20.0,
        'strokeColor': '#000000',
        'strokeWidth': 1.5,
        'points': [
          [0.0, 0.0],
          [50.0, 5.0],
          [110.0, 10.0],
          [190.0, 8.0],
        ],
        'pressures': [0.5, 0.5, 0.6, 0.5],
        'isDeleted': false,
      },
    ];

    // ── Phase 5: Automatic Save to .lipi File ──
    // Convert to InkML subset
    final inkml = InkMLConverter.excalidrawToInkML(excalidrawStrokes);
    expect(inkml, contains('<trace'));

    final manifest = LipiManifest(
      consultationId: consultationId,
      page: PageDimensions(
        width: template.templateWidthMm,
        height: template.templateHeightMm,
        unit: template.templateUnit,
      ),
      patientSnapshot: PatientSnapshot(
        name: patient.name,
        age: patient.age,
        gender: patient.gender,
        city: patient.city,
      ),
      doctorSnapshot: DoctorSnapshot(
        name: template.name,
        clinic: template.clinicName,
        qualifications: template.qualifications,
        regNumber: template.regNumber,
      ),
    );

    final lipiFile = vault.getPrescriptionFile(patient.id, consultationId);
    await LipiPackage.write(lipiFile, manifest: manifest, inkmlContent: inkml);

    expect(await lipiFile.exists(), isTrue);

    // Update SQLite index
    await database.upsertPrescription(
      consultationId: consultationId,
      patientId: patient.id,
      filePath: lipiFile.path,
      updatedAt: DateTime.now(),
    );

    // ── Phase 6: Leave Workspace and Verify SQLite History ──
    final history = await patientService.getPatientPrescriptions(patient.id);
    expect(history.length, 1);
    expect(history.first.consultationId, consultationId);
    expect(history.first.hasPdf, isFalse);

    // ── Phase 7: Reopen Saved .lipi and Reconstruct Prescription ──
    final reopenedPackage = await LipiPackage.read(lipiFile);

    // Verify all Section 20 requirements:
    // 1. Consultation ID
    expect(reopenedPackage.manifest.consultationId, consultationId);
    // 2. Page dimensions
    expect(reopenedPackage.manifest.page.width, 180.0);
    expect(reopenedPackage.manifest.page.height, 260.0);
    expect(reopenedPackage.manifest.page.unit, 'mm');
    // 3. Template appearance
    expect(reopenedPackage.manifest.doctorSnapshot?.clinic, 'City Health Clinic');
    expect(reopenedPackage.manifest.doctorSnapshot?.name, 'Dr. Aarti Sharma');
    // 4. Patient Name, Age, Gender, City
    expect(reopenedPackage.manifest.patientSnapshot.name, 'Ravi Kumar');
    expect(reopenedPackage.manifest.patientSnapshot.age, 42);
    expect(reopenedPackage.manifest.patientSnapshot.gender, 'Male');
    expect(reopenedPackage.manifest.patientSnapshot.city, 'Pune');

    // 5. Handwritten content reconstructed back to Excalidraw elements
    final reconstructedElements = InkMLConverter.inkMLToExcalidraw(reopenedPackage.inkmlContent);
    expect(reconstructedElements.length, 3);
    // Preserves stroke 1
    expect(reconstructedElements[0]['type'], 'freedraw');
    expect(reconstructedElements[0]['strokeColor'], '#000000');
    expect(reconstructedElements[0]['strokeWidth'], 1.5);
    // Preserves stroke 2
    expect(reconstructedElements[1]['type'], 'freedraw');
    expect(reconstructedElements[1]['strokeColor'], '#1a365d');
    expect(reconstructedElements[1]['strokeWidth'], 2.0);
    // Preserves stroke 3
    expect(reconstructedElements[2]['type'], 'freedraw');
    expect(reconstructedElements[2]['strokeColor'], '#000000');

    // ── Phase 8: PDF Export ──
    final pdfFile = vault.getPrescriptionPdfFile(patient.id, consultationId);
    final exportedPdf = await PdfExporter.exportToPdf(
      targetFile: pdfFile,
      manifest: reopenedPackage.manifest,
      inkmlContent: reopenedPackage.inkmlContent,
    );

    expect(await exportedPdf.exists(), isTrue);
    final pdfBytes = await exportedPdf.readAsBytes();
    expect(pdfBytes.length, greaterThan(2000));

    // Recheck patient history: now hasPdf should be true
    final updatedHistory = await patientService.getPatientPrescriptions(patient.id);
    expect(updatedHistory.first.hasPdf, isTrue);

    // ── Phase 9: Returning Patient Workflow ──
    // Doctor searches for "Ravi"
    final searchResults = await patientService.searchPatients('Ravi');
    expect(searchResults.length, 1);
    final returningPatient = searchResults.first;
    expect(returningPatient.id, patient.id);

    // Doctor creates a second prescription for returning patient
    final secondConsultationId = const Uuid().v4();
    final secondLipiFile = vault.getPrescriptionFile(returningPatient.id, secondConsultationId);
    final secondManifest = LipiManifest(
      consultationId: secondConsultationId,
      page: manifest.page,
      patientSnapshot: PatientSnapshot(
        name: returningPatient.name,
        age: returningPatient.age, // Preserves entered age
        gender: returningPatient.gender,
        city: returningPatient.city,
      ),
      doctorSnapshot: manifest.doctorSnapshot,
    );

    const secondInk = '<ink><trace color="#000000" width="1.5">10 10 0.5, 20 20 0.5</trace></ink>';
    await LipiPackage.write(secondLipiFile, manifest: secondManifest, inkmlContent: secondInk);

    await database.upsertPrescription(
      consultationId: secondConsultationId,
      patientId: returningPatient.id,
      filePath: secondLipiFile.path,
      updatedAt: DateTime.now(),
    );

    // Both historical prescriptions must be intact
    final patientPrescriptions = await patientService.getPatientPrescriptions(returningPatient.id);
    expect(patientPrescriptions.length, 2);

    // The first prescription remains unchanged
    final firstFileCheck = await LipiPackage.read(lipiFile);
    expect(firstFileCheck.manifest.consultationId, consultationId);
    expect(firstFileCheck.manifest.patientSnapshot.age, 42);
  });
}
