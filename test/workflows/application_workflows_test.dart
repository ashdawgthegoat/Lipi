import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/app/workflows/consultation_workflows.dart';
import 'package:lipi/app/workflows/doctor_workflows.dart';
import 'package:lipi/app/workflows/initialize_application_workflow.dart';
import 'package:lipi/app/workflows/patient_workflows.dart';
import 'package:lipi/domains/consultation/models/consultation_status.dart';
import 'package:lipi/domains/consultation/models/ink_document.dart';
import 'package:lipi/domains/consultation/models/stroke.dart';
import 'package:lipi/domains/consultation/models/stroke_point.dart';
import 'package:lipi/domains/doctor/models/doctor_profile.dart';
import 'package:lipi/domains/doctor/models/template_config.dart';
import 'package:lipi/domains/patient/models/allergy.dart';
import 'package:lipi/domains/patient/models/clinical_history.dart';
import 'package:lipi/domains/patient/models/patient_info.dart';
import 'package:lipi/infrastructure/database/sqlite_consultation_repository.dart';
import 'package:lipi/infrastructure/database/sqlite_doctor_repository.dart';
import 'package:lipi/infrastructure/database/sqlite_patient_repository.dart';
import 'package:lipi/infrastructure/database/vault_database.dart';
import 'package:lipi/infrastructure/documents/vault_document_repository.dart';
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
  late VaultDocumentRepository docRepo;

  // Workflows
  late InitializeApplicationWorkflow initAppWorkflow;
  late ConfigureDoctorWorkflow configureDoctorWorkflow;
  late CreatePatientWorkflow createPatientWorkflow;
  late SearchPatientsWorkflow searchPatientsWorkflow;
  late OpenPatientWorkflow openPatientWorkflow;
  late DeletePatientWorkflow deletePatientWorkflow;
  late StartConsultationWorkflow startConsultationWorkflow;
  late LoadConsultationWorkflow loadConsultationWorkflow;
  late SaveConsultationWorkflow saveConsultationWorkflow;
  late ListConsultationHistoryWorkflow listHistoryWorkflow;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_workflows_test_');
    vault = LipiVault(tempDir);
    await vault.initialize();

    database = VaultDatabase();
    await database.open(vault.dbFile);

    patientRepo = SqlitePatientRepository(database);
    doctorRepo = SqliteDoctorRepository(database);
    consultationRepo = SqliteConsultationRepository(database);
    docRepo = VaultDocumentRepository(vault);

    initAppWorkflow = InitializeApplicationWorkflow(
      vault: vault,
      database: database,
      doctorRepository: doctorRepo,
    );

    configureDoctorWorkflow = ConfigureDoctorWorkflow(
      vault: vault,
      doctorRepository: doctorRepo,
    );

    createPatientWorkflow = CreatePatientWorkflow(
      vault: vault,
      patientRepository: patientRepo,
    );

    searchPatientsWorkflow = SearchPatientsWorkflow(patientRepo);

    openPatientWorkflow = OpenPatientWorkflow(
      patientRepository: patientRepo,
      consultationRepository: consultationRepo,
    );

    deletePatientWorkflow = DeletePatientWorkflow(
      vault: vault,
      patientRepository: patientRepo,
      consultationRepository: consultationRepo,
    );

    startConsultationWorkflow = StartConsultationWorkflow(
      vault: vault,
      patientRepository: patientRepo,
      doctorRepository: doctorRepo,
      consultationRepository: consultationRepo,
      documentRepository: docRepo,
    );

    loadConsultationWorkflow = LoadConsultationWorkflow(docRepo);

    saveConsultationWorkflow = SaveConsultationWorkflow(
      documentRepository: docRepo,
      consultationRepository: consultationRepo,
    );

    listHistoryWorkflow = ListConsultationHistoryWorkflow(
      consultationRepository: consultationRepo,
      documentRepository: docRepo,
    );
  });

  tearDown(() async {
    await database.close();
    vault.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('End-to-End Non-UI Clinical Workflow Sequence', () async {
    // 1. Initial Launch without doctor setup -> routes to Doctor Setup
    final init1 = await initAppWorkflow.execute();
    expect(init1.isSuccess, isTrue);
    expect(init1.valueOrNull?.destination, equals(AppLaunchDestination.doctorSetup));

    // 2. Doctor Setup with custom template
    final dummyTemplateBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x01]);
    final doctorProfile = DoctorProfile(
      id: const DoctorId('doc-100'),
      name: 'Dr. Aarti Sharma',
      clinicName: 'City Health Clinic',
      qualifications: 'MBBS, MD (Medicine)',
      regNumber: 'MCI-55443',
      templateConfig: const TemplateConfig(widthMm: 180, heightMm: 260),
    );

    final configRes = await configureDoctorWorkflow.execute(
      profile: doctorProfile,
      customTemplateBytes: dummyTemplateBytes,
    );
    expect(configRes.isSuccess, isTrue);
    final savedDoctor = configRes.valueOrNull!;
    expect(savedDoctor.templateConfig.hasCustomTemplate, isTrue);

    // Verify vault/doctor/profile.json exists
    expect(await vault.fs.exists('doctor/profile.json'), isTrue);

    // 3. Next App Launch -> routes to Main Workspace
    final init2 = await initAppWorkflow.execute();
    expect(init2.isSuccess, isTrue);
    expect(init2.valueOrNull?.destination, equals(AppLaunchDestination.mainWorkspace));

    // 4. Create Patient
    final createPatRes = await createPatientWorkflow.execute(
      info: const PatientInfo(
        name: 'Ravi Kumar',
        age: 42,
        gender: 'Male',
        city: 'Pune',
      ),
      history: const ClinicalHistory(
        previousConditions: ['Hypertension'],
        allergies: [Allergy(allergen: 'Penicillin', severity: 'Severe')],
      ),
    );
    expect(createPatRes.isSuccess, isTrue);
    final patient = createPatRes.valueOrNull!;
    expect(patient.name, equals('Ravi Kumar'));

    // Check patient directory in Vault exists
    final patientFolderRel = vault.getPatientFolderRelativePath(patient.id);
    expect(await vault.fs.exists(patientFolderRel), isTrue);

    // 5. Search Patients
    final searchRes = await searchPatientsWorkflow.execute('ravi');
    expect(searchRes.isSuccess, isTrue);
    expect(searchRes.valueOrNull?.length, equals(1));
    expect(searchRes.valueOrNull?.first.id, equals(patient.id));

    // 6. Open Patient Workspace
    final openRes = await openPatientWorkflow.execute(patient.id);
    expect(openRes.isSuccess, isTrue);
    expect(openRes.valueOrNull?.patient.name, equals('Ravi Kumar'));
    expect(openRes.valueOrNull?.consultations, isEmpty);

    // 7. Start New Consultation (Prescription)
    final startRes = await startConsultationWorkflow.execute(patientId: patient.id);
    expect(startRes.isSuccess, isTrue);
    final clinicalDoc = startRes.valueOrNull!;
    expect(clinicalDoc.patientSnapshot.name, equals('Ravi Kumar'));
    expect(clinicalDoc.doctorSnapshot?.clinic, equals('City Health Clinic'));
    expect(clinicalDoc.hasCustomTemplate, isTrue);

    // Verify initial .lipi file exists on disk
    final docExists = await docRepo.documentExists(patient.id, clinicalDoc.consultationId);
    expect(docExists.valueOrNull, isTrue);

    // 8. Add handwriting strokes & Save
    final updatedDoc = clinicalDoc.copyWith(
      ink: InkDocument(strokes: [
        const Stroke(
          points: [
            StrokePoint(x: 50.0, y: 100.0, pressure: 0.6),
            StrokePoint(x: 120.0, y: 105.0, pressure: 0.7),
          ],
          color: '#1A365D',
          strokeWidth: 2.0,
        ),
      ]),
    );

    final saveRes = await saveConsultationWorkflow.execute(
      patientId: patient.id,
      document: updatedDoc,
      status: ConsultationStatus.saved,
    );
    expect(saveRes.isSuccess, isTrue);

    // 9. Load Consultation back from disk
    final loadRes = await loadConsultationWorkflow.execute(
      patientId: patient.id,
      consultationId: clinicalDoc.consultationId,
    );
    expect(loadRes.isSuccess, isTrue);
    final reloadedDoc = loadRes.valueOrNull!;
    expect(reloadedDoc.ink.strokeCount, equals(1));
    expect(reloadedDoc.ink.strokes.first.points.length, equals(2));
    expect(reloadedDoc.ink.strokes.first.color, equals('#1A365D'));

    // 10. List consultation history for patient
    final historyList = await listHistoryWorkflow.execute(patient.id);
    expect(historyList.isSuccess, isTrue);
    expect(historyList.valueOrNull?.length, equals(1));
    expect(historyList.valueOrNull?.first.id, equals(clinicalDoc.consultationId));
    expect(historyList.valueOrNull?.first.status, equals(ConsultationStatus.saved));

    // 11. Explicit Patient Deletion
    final deleteRes = await deletePatientWorkflow.execute(patient.id);
    expect(deleteRes.isSuccess, isTrue);

    // Verify patient folder deleted from Vault
    expect(await vault.fs.exists(patientFolderRel), isFalse);

    // Verify database record deleted
    final checkPat = await patientRepo.getPatientById(patient.id);
    expect(checkPat.valueOrNull, isNull);

    // Verify consultations deleted
    final checkCons = await consultationRepo.getConsultationsForPatient(patient.id);
    expect(checkCons.valueOrNull, isEmpty);
  });
}
