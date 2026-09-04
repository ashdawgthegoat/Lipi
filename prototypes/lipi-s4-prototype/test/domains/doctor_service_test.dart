import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi_s4_prototype/domains/doctor/doctor_service.dart';
import 'package:lipi_s4_prototype/domains/doctor/models/doctor_profile.dart';
import 'package:lipi_s4_prototype/infrastructure/storage/lipi_database.dart';
import 'package:lipi_s4_prototype/infrastructure/storage/vault.dart';

void main() {
  late Directory tempDir;
  late LipiVault vault;
  late LipiDatabase database;
  late DoctorService doctorService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_doc_test_');
    vault = LipiVault(tempDir);
    await vault.initialize();

    database = LipiDatabase();
    await database.init(vault.dbFile);

    doctorService = DoctorService(vault: vault, database: database);
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('DoctorService saves and retrieves doctor profile across SQLite and Vault', () async {
    final initial = await doctorService.getProfile();
    expect(initial, isNull);

    final profile = DoctorProfile(
      id: 'doc-uuid-1',
      name: 'Dr. Aarti Sharma',
      clinicName: 'City Health Clinic',
      qualifications: 'MBBS, MD',
      regNumber: 'MCI-45892',
      templateWidthMm: 180,
      templateHeightMm: 260,
    );

    await doctorService.saveProfile(profile);

    final loaded = await doctorService.getProfile();
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Dr. Aarti Sharma');
    expect(loaded.clinicName, 'City Health Clinic');
    expect(loaded.qualifications, 'MBBS, MD');
    expect(loaded.regNumber, 'MCI-45892');
    expect(loaded.templateWidthMm, 180);
    expect(loaded.templateHeightMm, 260);

    // Vault profile.json also created
    expect(await vault.doctorProfileJson.exists(), isTrue);
  });

  test('DoctorService imports and stores prescription template file in Vault', () async {
    // Create a dummy template image file
    final sampleImg = File('${tempDir.path}/sample_letterhead.png');
    await sampleImg.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]); // PNG magic bytes

    final profile = DoctorProfile(
      id: 'doc-uuid-2',
      name: 'Dr. Suresh Kumar',
      clinicName: 'Apex Clinic',
      qualifications: 'MBBS',
      regNumber: 'REG-99',
    );

    final savedProfile = await doctorService.saveProfile(profile, customTemplateFile: sampleImg);

    // Critical regression: the RETURNED profile must have templatePath set.
    // The original input profile has templatePath=null — only the returned value
    // reflects the persisted Vault path.
    expect(savedProfile.templatePath, isNotNull,
        reason: 'saveProfile must return a profile with templatePath set — '
            'the caller must use this returned value, not the original input profile');
    expect(savedProfile.templatePath, contains(vault.templatesDir.path));

    final loaded = await doctorService.getProfile();
    expect(loaded, isNotNull);
    expect(loaded!.templatePath, isNotNull);

    final templateFile = await doctorService.getTemplateFile(loaded);
    expect(templateFile, isNotNull);
    expect(await templateFile!.exists(), isTrue);
    expect(templateFile.path, contains(vault.templatesDir.path));
  });

  test('saveProfile returns profile with JPEG template path using .jpeg extension', () async {
    // Regression for wrong MIME type: extension must be preserved exactly.
    final jpegImg = File('${tempDir.path}/template.jpeg');
    await jpegImg.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic bytes

    final profile = DoctorProfile(
      id: 'doc-uuid-3',
      name: 'Dr. Meena Rao',
      clinicName: 'Rainbow Hospital',
      qualifications: 'MD',
      regNumber: 'REG-77',
    );

    final savedProfile = await doctorService.saveProfile(profile, customTemplateFile: jpegImg);
    expect(savedProfile.templatePath, isNotNull);
    // Extension must be preserved so the data URL gets the correct MIME type
    expect(savedProfile.templatePath!.endsWith('.jpeg'), isTrue,
        reason: 'JPEG template extension must be preserved — '
            'the data URL MIME type depends on file extension');
  });

  test('DoctorService with no custom template sets templatePath to null (Default Template)', () async {
    final profile = DoctorProfile(
      id: 'doc-uuid-4',
      name: 'Dr. Default User',
      clinicName: 'Default Clinic',
      qualifications: 'MBBS',
      regNumber: 'REG-00',
    );

    final savedProfile = await doctorService.saveProfile(profile, customTemplateFile: null);
    expect(savedProfile.templatePath, isNull);

    final loaded = await doctorService.getProfile();
    expect(loaded, isNotNull);
    expect(loaded!.templatePath, isNull);

    final templateFile = await doctorService.getTemplateFile(loaded);
    expect(templateFile, isNull, reason: 'Default template has no custom file');
  });

  test('DoctorService clearing custom template removes templatePath', () async {
    // First save with custom template
    final sampleImg = File('${tempDir.path}/temp_template.png');
    await sampleImg.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);

    final profile = DoctorProfile(
      id: 'doc-uuid-5',
      name: 'Dr. Toggle User',
      clinicName: 'Toggle Clinic',
      qualifications: 'MBBS',
      regNumber: 'REG-11',
    );

    final withCustom = await doctorService.saveProfile(profile, customTemplateFile: sampleImg);
    expect(withCustom.templatePath, isNotNull);

    // Then update with customTemplateFile: null to revert to default
    final updatedProfile = await doctorService.saveProfile(withCustom, customTemplateFile: null);
    expect(updatedProfile.templatePath, isNull, reason: 'Reverting to default should clear templatePath');

    final loaded = await doctorService.getProfile();
    expect(loaded!.templatePath, isNull);
    final file = await doctorService.getTemplateFile(loaded);
    expect(file, isNull);
  });
}
