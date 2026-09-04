import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app/app.dart';
import 'domains/doctor/doctor_service.dart';
import 'domains/patient/patient_service.dart';
import 'infrastructure/storage/lipi_database.dart';
import 'infrastructure/storage/vault.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Determine Vault directory
  final appDocDir = await getApplicationDocumentsDirectory();
  final vaultDir = Directory(p.join(appDocDir.path, 'LipiVault'));

  // Initialize Vault filesystem structure
  final vault = LipiVault(vaultDir);
  await vault.initialize();

  // Initialize Vault-level SQLite database
  final database = LipiDatabase();
  await database.init(vault.dbFile);

  // Initialize Domain Services
  final doctorService = DoctorService(vault: vault, database: database);
  final patientService = PatientService(vault: vault, database: database);

  // Check for existing Doctor Profile
  final doctorProfile = await doctorService.getProfile();

  runApp(LipiApp(
    doctorService: doctorService,
    patientService: patientService,
    initialDoctorProfile: doctorProfile,
  ));
}
