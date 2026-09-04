import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi_s4_prototype/infrastructure/storage/lipi_package.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_pkg_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LipiManifest', () {
    test('serializes and deserializes correctly', () {
      final manifest = LipiManifest(
        consultationId: 'c-test-1234',
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
          regNumber: 'MCI-12345',
        ),
        ink: 'ink/page-001.inkml',
      );

      final json = manifest.toJson();
      expect(json['format'], 'lipi');
      expect(json['version'], 1);
      expect(json['consultation_id'], 'c-test-1234');
      expect(json['page']['width'], 180.0);
      expect(json['page']['height'], 260.0);
      expect(json['page']['unit'], 'mm');
      expect(json['patient_snapshot']['name'], 'Ravi Kumar');
      expect(json['patient_snapshot']['age'], 42);
      expect(json['patient_snapshot']['gender'], 'Male');
      expect(json['patient_snapshot']['city'], 'Pune');
      expect(json['doctor_snapshot']['name'], 'Dr. Aarti Sharma');
      expect(json['ink'], 'ink/page-001.inkml');

      // Does not include patient_id in manifest (per ADR/spec)
      expect(json.containsKey('patient_id'), isFalse);

      final restored = LipiManifest.fromJson(json);
      expect(restored.consultationId, 'c-test-1234');
      expect(restored.page.width, 180.0);
      expect(restored.page.height, 260.0);
      expect(restored.page.unit, 'mm');
      expect(restored.patientSnapshot.name, 'Ravi Kumar');
      expect(restored.patientSnapshot.age, 42);
      expect(restored.patientSnapshot.gender, 'Male');
      expect(restored.patientSnapshot.city, 'Pune');
      expect(restored.doctorSnapshot?.clinic, 'City Health Clinic');
      expect(restored.ink, 'ink/page-001.inkml');
    });
  });

  group('LipiPackage', () {
    test('creates and reads .lipi ZIP archive preserving all contents', () async {
      final targetFile = File('${tempDir.path}/consultation_c-test-1234.lipi');

      final manifest = LipiManifest(
        consultationId: 'c-test-1234',
        page: const PageDimensions(width: 180, height: 260, unit: 'mm'),
        patientSnapshot: const PatientSnapshot(
          name: 'Priya Patel',
          age: 35,
          gender: 'Female',
          city: 'Ahmedabad',
        ),
        doctorSnapshot: const DoctorSnapshot(
          name: 'Dr. Aarti Sharma',
          clinic: 'City Health Clinic',
          qualifications: 'MBBS, MD',
          regNumber: 'MCI-12345',
        ),
      );

      const sampleInkml = '''<?xml version="1.0" encoding="UTF-8"?>
<ink xmlns="http://www.w3.org/2003/InkML">
  <trace contextRef="#ctx0" color="#000000" width="1.5">
    100.00 150.00 0.60, 105.00 155.00 0.70
  </trace>
</ink>''';

      // 1. Write package
      await LipiPackage.write(
        targetFile,
        manifest: manifest,
        inkmlContent: sampleInkml,
      );

      expect(await targetFile.exists(), isTrue);
      expect(await targetFile.length(), greaterThan(0));

      // 2. Read package back
      final loaded = await LipiPackage.read(targetFile);

      expect(loaded.manifest.consultationId, 'c-test-1234');
      expect(loaded.manifest.page.width, 180.0);
      expect(loaded.manifest.page.height, 260.0);
      expect(loaded.manifest.patientSnapshot.name, 'Priya Patel');
      expect(loaded.manifest.patientSnapshot.age, 35);
      expect(loaded.manifest.patientSnapshot.gender, 'Female');
      expect(loaded.manifest.patientSnapshot.city, 'Ahmedabad');
      expect(loaded.manifest.doctorSnapshot?.name, 'Dr. Aarti Sharma');
      expect(loaded.inkmlContent, sampleInkml);
    });

    test('reopen round trip preserves exact consultation identity and page structure', () async {
      final targetFile = File('${tempDir.path}/prescription_roundtrip.lipi');

      final manifest = LipiManifest(
        consultationId: 'consultation-roundtrip-uuid-999',
        page: const PageDimensions(width: 210, height: 297, unit: 'mm'),
        patientSnapshot: const PatientSnapshot(
          name: 'Suresh Raina',
          age: 50,
          gender: 'Male',
          city: 'Delhi',
        ),
      );

      const inkml = '<ink><trace>10 20 0.5, 30 40 0.5</trace></ink>';

      await LipiPackage.write(targetFile, manifest: manifest, inkmlContent: inkml);
      final reopened = await LipiPackage.read(targetFile);

      expect(reopened.manifest.consultationId, 'consultation-roundtrip-uuid-999');
      expect(reopened.manifest.page.width, 210);
      expect(reopened.manifest.page.height, 297);
      expect(reopened.manifest.patientSnapshot.name, 'Suresh Raina');
      expect(reopened.manifest.patientSnapshot.age, 50);
      expect(reopened.manifest.patientSnapshot.city, 'Delhi');
      expect(reopened.inkmlContent, inkml);
    });
  });
}
