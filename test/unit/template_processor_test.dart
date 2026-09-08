import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/app/workflows/consultation_workflows.dart';
import 'package:lipi/app/workflows/doctor_workflows.dart';
import 'package:lipi/app/workflows/patient_workflows.dart';
import 'package:lipi/domains/doctor/models/doctor_preferences.dart';
import 'package:lipi/domains/doctor/models/doctor_profile.dart';
import 'package:lipi/domains/doctor/models/template_config.dart';
import 'package:lipi/domains/patient/models/patient_info.dart';
import 'package:lipi/infrastructure/database/sqlite_consultation_repository.dart';
import 'package:lipi/infrastructure/database/sqlite_doctor_repository.dart';
import 'package:lipi/infrastructure/database/sqlite_patient_repository.dart';
import 'package:lipi/infrastructure/database/vault_database.dart';
import 'package:lipi/infrastructure/documents/vault_document_repository.dart';
import 'package:lipi/infrastructure/templates/template_processor.dart';
import 'package:lipi/infrastructure/vault/vault.dart';
import 'package:lipi/shared/errors/lipi_error.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VaultDatabase.initializeFfiIfRequired();

  group('TemplateProcessor Unit Tests', () {
    test('Image template processing validates and returns image bytes', () async {
      final fakePngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final result = await TemplateProcessor.process(
        bytes: fakePngBytes,
        filename: 'clinic_header.png',
      );

      expect(result.isPdf, isFalse);
      expect(result.extension, '.png');
      expect(result.pageCount, 1);
      expect(result.imageBytes, fakePngBytes);
      expect(result.originalPdfBytes, isNull);
      expect(result.warningMessage, isNull);
    });

    test('Unsupported file extensions fail validation closed', () async {
      final dummyBytes = Uint8List.fromList(utf8.encode('malicious executable'));
      expect(
        () => TemplateProcessor.process(bytes: dummyBytes, filename: 'virus.exe'),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => TemplateProcessor.process(bytes: dummyBytes, filename: 'notes.txt'),
        throwsA(isA<ValidationError>()),
      );
    });

    test('Empty bytes fail validation closed', () async {
      expect(
        () => TemplateProcessor.process(bytes: Uint8List(0), filename: 'empty.pdf'),
        throwsA(isA<ValidationError>()),
      );
    });

    test('PDF template counts pages and converts Page 1 using rasterizer', () async {
      final fakePdf = '%PDF-1.4\n1 0 obj\n<< /Type /Page >>\nendobj\n2 0 obj\n<< /Type /Page >>\nendobj\n%%EOF';
      final pdfBytes = Uint8List.fromList(utf8.encode(fakePdf));

      final pageCount = TemplateProcessor.countPdfPages(pdfBytes);
      expect(pageCount, 2);

      final expectedPngBytes = Uint8List.fromList([1, 2, 3, 4]);
      TemplateProcessor.testRasterizer = (bytes, {int pageIndex = 0, double dpi = 200}) async {
        expect(pageIndex, 0);
        return expectedPngBytes;
      };

      try {
        final result = await TemplateProcessor.process(
          bytes: pdfBytes,
          filename: 'multipage_letterhead.pdf',
        );

        expect(result.isPdf, isTrue);
        expect(result.extension, '.png');
        expect(result.pageCount, 2);
        expect(result.imageBytes, expectedPngBytes);
        expect(result.originalPdfBytes, pdfBytes);
        expect(result.warningMessage, contains('Multi-page PDF detected (2 pages)'));
      } finally {
        TemplateProcessor.testRasterizer = null;
      }
    });
  });

  group('Template Workflow & Historical Preservation Tests', () {
    late Directory tempDir;
    late LipiVault vault;
    late VaultDatabase database;
    late SqlitePatientRepository patientRepo;
    late SqliteDoctorRepository doctorRepo;
    late SqliteConsultationRepository consultationRepo;
    late VaultDocumentRepository docRepo;
    late ConfigureDoctorWorkflow configureDoctorWorkflow;
    late CreatePatientWorkflow createPatientWorkflow;
    late StartConsultationWorkflow startConsultationWorkflow;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('lipi_template_test_');
      vault = LipiVault(tempDir);
      await vault.initialize();

      database = VaultDatabase();
      await database.open(vault.dbFile);

      patientRepo = SqlitePatientRepository(database);
      doctorRepo = SqliteDoctorRepository(database);
      consultationRepo = SqliteConsultationRepository(database);
      docRepo = VaultDocumentRepository(vault);

      configureDoctorWorkflow = ConfigureDoctorWorkflow(
        vault: vault,
        doctorRepository: doctorRepo,
      );
      createPatientWorkflow = CreatePatientWorkflow(
        vault: vault,
        patientRepository: patientRepo,
      );
      startConsultationWorkflow = StartConsultationWorkflow(
        vault: vault,
        patientRepository: patientRepo,
        doctorRepository: doctorRepo,
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

    test('PDF template import stores raster PNG and original PDF in vault, preserving in consultations', () async {
      final fakePdf = '%PDF-1.4\n1 0 obj\n<< /Type /Page >>\nendobj\n%%EOF';
      final pdfBytes = Uint8List.fromList(utf8.encode(fakePdf));
      final fakePngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      TemplateProcessor.testRasterizer = (bytes, {int pageIndex = 0, double dpi = 200}) async => fakePngBytes;

      try {
        final profile = DoctorProfile(
          id: DoctorId('doc-pdf-test'),
          name: 'Dr. Test PDF',
          clinicName: 'Test Clinic',
          qualifications: 'MBBS',
          regNumber: 'REG-1234',
          templateConfig: const TemplateConfig(),
          preferences: const DoctorPreferences(),
        );

        final res = await configureDoctorWorkflow.execute(
          profile: profile,
          customTemplateBytes: pdfBytes,
          templateExtension: '.pdf',
        );

        expect(res.isSuccess, isTrue);
        final saved = res.valueOrNull!;
        expect(saved.templatePath, 'doctor/templates/custom_template.png');

        // Verify Vault stores raster PNG for inking/printing
        expect(await vault.fs.exists('doctor/templates/custom_template.png'), isTrue);
        final readPng = await vault.fs.readBytes('doctor/templates/custom_template.png');
        expect(readPng, fakePngBytes);

        // Verify Vault preserves original vector PDF
        expect(await vault.fs.exists('doctor/templates/custom_template_original.pdf'), isTrue);
        final readPdf = await vault.fs.readBytes('doctor/templates/custom_template_original.pdf');
        expect(readPdf, pdfBytes);

        // Create patient and verify startConsultation packages the template bytes
        final pRes = await createPatientWorkflow.execute(
          info: const PatientInfo(
            name: 'Sita Ram',
            age: 30,
            gender: 'Female',
            city: 'Delhi',
          ),
        );
        expect(pRes.isSuccess, isTrue);
        final patient = pRes.valueOrNull!;

        final docRes = await startConsultationWorkflow.execute(patientId: patient.id);
        expect(docRes.isSuccess, isTrue);
        final document = docRes.valueOrNull!;
        expect(document.templateBytes, fakePngBytes);
      } finally {
        TemplateProcessor.testRasterizer = null;
      }
    });
  });
}
