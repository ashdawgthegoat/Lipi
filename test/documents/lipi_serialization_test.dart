import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/models/clinical_document.dart';
import 'package:lipi/domains/consultation/models/doctor_snapshot.dart';
import 'package:lipi/domains/consultation/models/ink_document.dart';
import 'package:lipi/domains/consultation/models/page_dimensions.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/consultation/models/stroke.dart';
import 'package:lipi/domains/consultation/models/stroke_point.dart';
import 'package:lipi/infrastructure/documents/lipi_document_deserializer.dart';
import 'package:lipi/infrastructure/documents/lipi_document_serializer.dart';
import 'package:lipi/infrastructure/documents/lipi_package_validator.dart';
import 'package:lipi/infrastructure/documents/vault_document_repository.dart';
import 'package:lipi/infrastructure/vault/vault.dart';
import 'package:lipi/shared/errors/lipi_error.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('.lipi Serialization and Deserialization Round-Trip', () {
    test('Round-trip preserves all canonical document properties and ink vector geometry', () {
      final dummyPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final originalDoc = ClinicalDocument(
        consultationId: const ConsultationId('roundtrip-c-1'),
        page: const PageDimensions(width: 180, height: 260, unit: 'mm'),
        patientSnapshot: const PatientSnapshot(
          name: 'Ravi Kumar',
          age: 42,
          gender: 'Male',
          city: 'Pune',
        ),
        doctorSnapshot: const DoctorSnapshot(
          name: 'Dr. Aarti Sharma',
          clinic: 'City Health Clinic',
          qualifications: 'MBBS, MD',
          regNumber: 'REG-12345',
          templateImageFile: 'templates/custom_template.png',
        ),
        ink: InkDocument(strokes: [
          const Stroke(
            points: [
              StrokePoint(x: 10.5, y: 20.5, pressure: 0.35),
              StrokePoint(x: 45.0, y: 60.25, pressure: 0.75),
              StrokePoint(x: 90.1, y: 120.0, pressure: 0.95),
            ],
            color: '#1A365D',
            strokeWidth: 2.0,
          ),
          const Stroke(
            points: [
              StrokePoint(x: 100.0, y: 150.0, pressure: 0.5),
            ],
            color: '#D32F2F',
            strokeWidth: 1.5,
          ),
        ]),
        templateBytes: dummyPng,
      );

      // 1. Serialize
      final zipBytes = LipiDocumentSerializer.serialize(originalDoc);
      expect(zipBytes.isNotEmpty, isTrue);

      // 2. Deserialize
      final reconstructed = LipiDocumentDeserializer.deserialize(zipBytes);

      // 3. Verify
      expect(reconstructed.format, equals(originalDoc.format));
      expect(reconstructed.version, equals(originalDoc.version));
      expect(reconstructed.consultationId, equals(originalDoc.consultationId));
      expect(reconstructed.page.width, equals(180.0));
      expect(reconstructed.page.height, equals(260.0));
      expect(reconstructed.patientSnapshot.name, equals('Ravi Kumar'));
      expect(reconstructed.patientSnapshot.age, equals(42));
      expect(reconstructed.doctorSnapshot?.clinic, equals('City Health Clinic'));
      expect(reconstructed.doctorSnapshot?.regNumber, equals('REG-12345'));

      // Check ink preservation
      expect(reconstructed.ink.strokeCount, equals(2));
      final s1 = reconstructed.ink.strokes[0];
      expect(s1.points.length, equals(3));
      expect(s1.points[0].x, closeTo(10.5, 0.01));
      expect(s1.points[0].y, closeTo(20.5, 0.01));
      expect(s1.points[0].pressure, closeTo(0.35, 0.01));
      expect(s1.color, equals('#1A365D'));
      expect(s1.strokeWidth, closeTo(2.0, 0.01));

      final s2 = reconstructed.ink.strokes[1];
      expect(s2.points.length, equals(1));
      expect(s2.color, equals('#D32F2F'));

      // Check template bytes
      expect(reconstructed.templateBytes, isNotNull);
      expect(reconstructed.templateBytes, equals(dummyPng));
    });
  });

  group('.lipi Package Validator Fail-Closed Behavior', () {
    test('Rejects corrupt or empty bytes', () {
      expect(
        () => LipiPackageValidator.validate(Uint8List(0)),
        throwsA(isA<DocumentError>()),
      );
      expect(
        () => LipiPackageValidator.validate(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<DocumentError>()),
      );
    });

    test('Rejects archive missing manifest.json', () {
      final archive = Archive();
      archive.addFile(ArchiveFile('some_file.txt', 4, [1, 2, 3, 4]));
      final zip = Uint8List.fromList(ZipEncoder().encode(archive));

      expect(
        () => LipiPackageValidator.validate(zip),
        throwsA(isA<DocumentError>()),
      );
    });

    test('Rejects archive with missing referenced ink file', () {
      final archive = Archive();
      const manifestJson = '''{
        "format": "lipi",
        "version": 1,
        "consultation_id": "c-test",
        "created_at": "2026-09-08T12:00:00.000",
        "page": {"width": 180, "height": 260, "unit": "mm"},
        "patient_snapshot": {"name": "Test", "age": 30, "gender": "M", "city": "City"},
        "ink": "ink/page-001.inkml"
      }''';
      archive.addFile(ArchiveFile.string('manifest.json', manifestJson));
      final zip = Uint8List.fromList(ZipEncoder().encode(archive));

      expect(
        () => LipiPackageValidator.validate(zip),
        throwsA(isA<DocumentError>()),
      );
    });

    test('Rejects archive with missing referenced template file', () {
      final archive = Archive();
      const manifestJson = '''{
        "format": "lipi",
        "version": 1,
        "consultation_id": "c-test",
        "created_at": "2026-09-08T12:00:00.000",
        "page": {"width": 180, "height": 260, "unit": "mm"},
        "patient_snapshot": {"name": "Test", "age": 30, "gender": "M", "city": "City"},
        "doctor_snapshot": {"name": "Dr", "clinic": "C", "qualifications": "Q", "reg_number": "R", "template_image_file": "templates/custom.png"},
        "ink": "ink/page-001.inkml"
      }''';
      archive.addFile(ArchiveFile.string('manifest.json', manifestJson));
      archive.addFile(ArchiveFile.string('ink/page-001.inkml', '<ink xmlns="http://www.w3.org/2003/InkML"></ink>'));
      final zip = Uint8List.fromList(ZipEncoder().encode(archive));

      expect(
        () => LipiPackageValidator.validate(zip),
        throwsA(isA<DocumentError>()),
      );
    });
  });

  group('VaultDocumentRepository Integration', () {
    late Directory tempDir;
    late LipiVault vault;
    late VaultDocumentRepository docRepo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('lipi_doc_repo_test_');
      vault = LipiVault(tempDir);
      await vault.initialize();
      docRepo = VaultDocumentRepository(vault);
    });

    tearDown(() async {
      vault.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Saves, checks existence, reads, and deletes canonical document', () async {
      const patientId = PatientId('pat-555');
      final doc = ClinicalDocument(
        consultationId: const ConsultationId('c-555'),
        patientSnapshot: const PatientSnapshot(name: 'Anita Roy', age: 34, gender: 'Female', city: 'Delhi'),
        ink: const InkDocument(strokes: [
          Stroke(points: [StrokePoint(x: 10, y: 10)]),
        ]),
      );

      // 1. Initially does not exist
      final existsBefore = await docRepo.documentExists(patientId, doc.consultationId);
      expect(existsBefore.valueOrNull, isFalse);

      // 2. Save
      final saveRes = await docRepo.saveDocument(patientId, doc);
      expect(saveRes.isSuccess, isTrue);

      // 3. Exists
      final existsAfter = await docRepo.documentExists(patientId, doc.consultationId);
      expect(existsAfter.valueOrNull, isTrue);

      // 4. Read back
      final readRes = await docRepo.readDocument(patientId, doc.consultationId);
      expect(readRes.isSuccess, isTrue);
      expect(readRes.valueOrNull?.patientSnapshot.name, equals('Anita Roy'));
      expect(readRes.valueOrNull?.ink.strokeCount, equals(1));

      // 5. Delete
      final deleteRes = await docRepo.deleteDocument(patientId, doc.consultationId);
      expect(deleteRes.isSuccess, isTrue);

      final existsDeleted = await docRepo.documentExists(patientId, doc.consultationId);
      expect(existsDeleted.valueOrNull, isFalse);
    });
  });
}
