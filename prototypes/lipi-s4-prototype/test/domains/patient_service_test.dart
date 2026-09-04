import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi_s4_prototype/domains/patient/patient_service.dart';
import 'package:lipi_s4_prototype/infrastructure/storage/lipi_database.dart';
import 'package:lipi_s4_prototype/infrastructure/storage/vault.dart';

void main() {
  late Directory tempDir;
  late LipiVault vault;
  late LipiDatabase database;
  late PatientService patientService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_pat_test_');
    vault = LipiVault(tempDir);
    await vault.initialize();

    database = LipiDatabase();
    await database.init(vault.dbFile);

    patientService = PatientService(vault: vault, database: database);
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('createPatient stores record in SQLite and creates filesystem folder in Vault', () async {
    final patient = await patientService.createPatient(
      name: 'Ravi Kumar',
      age: 42,
      gender: 'Male',
      city: 'Pune',
    );

    expect(patient.id, isNotEmpty);
    expect(patient.name, 'Ravi Kumar');
    expect(patient.age, 42);
    expect(patient.gender, 'Male');
    expect(patient.city, 'Pune');

    // Verify SQLite record
    final fromDb = await patientService.getPatient(patient.id);
    expect(fromDb, isNotNull);
    expect(fromDb!.name, 'Ravi Kumar');
    expect(fromDb.age, 42);

    // Verify Vault filesystem folder
    final folder = vault.getPatientFolder(patient.id);
    expect(await folder.exists(), isTrue);

    final rxFolder = vault.getPatientPrescriptionsFolder(patient.id);
    expect(await rxFolder.exists(), isTrue);
  });

  test('searchPatients finds matching patients by name or city without silent inference', () async {
    await patientService.createPatient(name: 'Aarav Patel', age: 28, gender: 'Male', city: 'Mumbai');
    await patientService.createPatient(name: 'Ravi Kumar', age: 42, gender: 'Male', city: 'Pune');
    await patientService.createPatient(name: 'Sunita Sharma', age: 50, gender: 'Female', city: 'Pune');

    // Search by name
    final results1 = await patientService.searchPatients('Ravi');
    expect(results1.length, 1);
    expect(results1.first.name, 'Ravi Kumar');

    // Search by city
    final results2 = await patientService.searchPatients('Pune');
    expect(results2.length, 2);

    // Search with empty query returns all recent
    final all = await patientService.searchPatients('');
    expect(all.length, 3);
  });

  test('Age rule: Patient record age remains stable as entered value', () async {
    final patient = await patientService.createPatient(
      name: 'Ananya Roy',
      age: 24,
      gender: 'Female',
      city: 'Kolkata',
    );

    expect(patient.age, 24);

    final fetched = await patientService.getPatient(patient.id);
    expect(fetched!.age, 24);
    // Age must not be dynamically derived from date
  });
}
