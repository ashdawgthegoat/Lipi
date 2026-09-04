import 'package:flutter/material.dart';
import '../domains/doctor/doctor_service.dart';
import '../domains/doctor/models/doctor_profile.dart';
import '../domains/patient/patient_service.dart';
import 'screens/first_run_screen.dart';
import 'screens/main_workspace_screen.dart';

class LipiApp extends StatelessWidget {
  final DoctorService doctorService;
  final PatientService patientService;
  final DoctorProfile? initialDoctorProfile;

  const LipiApp({
    super.key,
    required this.doctorService,
    required this.patientService,
    this.initialDoctorProfile,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Lipi — Sprint 4 Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          primary: const Color(0xFF1A73E8),
          secondary: const Color(0xFF0F172A),
          surface: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: initialDoctorProfile != null
          ? MainWorkspaceScreen(
              doctorService: doctorService,
              patientService: patientService,
              doctorProfile: initialDoctorProfile!,
            )
          : FirstRunScreen(
              doctorService: doctorService,
              patientService: patientService,
            ),
    );
  }
}
