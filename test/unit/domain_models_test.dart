import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/models/consultation.dart';
import 'package:lipi/domains/consultation/models/consultation_status.dart';
import 'package:lipi/domains/consultation/models/doctor_snapshot.dart';
import 'package:lipi/domains/consultation/models/page_dimensions.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/doctor/models/doctor_preferences.dart';
import 'package:lipi/domains/doctor/models/doctor_profile.dart';
import 'package:lipi/domains/doctor/models/template_config.dart';
import 'package:lipi/domains/patient/models/allergy.dart';
import 'package:lipi/domains/patient/models/clinical_history.dart';
import 'package:lipi/domains/patient/models/medication_record.dart';
import 'package:lipi/domains/patient/models/patient.dart';
import 'package:lipi/domains/patient/models/patient_info.dart';
import 'package:lipi/shared/errors/lipi_error.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  group('Patient Domain Models', () {
    test('PatientInfo valid construction and serialization', () {
      const info = PatientInfo(
        name: 'Ravi Kumar',
        age: 42,
        gender: 'Male',
        city: 'Pune',
        heightCm: 175.5,
        weightKg: 78.0,
        phoneNumber: '+919876543210',
      );
      expect(() => info.validate(), returnsNormally);

      final map = info.toMap();
      final roundtrip = PatientInfo.fromMap(map);
      expect(roundtrip, equals(info));
    });

    test('PatientInfo validation fails for invalid data', () {
      expect(
        () => const PatientInfo(name: '', age: 20, gender: 'F', city: 'Delhi')
            .validate(),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => const PatientInfo(
                name: 'Test', age: -1, gender: 'F', city: 'Delhi')
            .validate(),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => const PatientInfo(
                name: 'Test', age: 20, gender: '', city: 'Delhi')
            .validate(),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => const PatientInfo(
                name: 'Test', age: 20, gender: 'F', city: '')
            .validate(),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => const PatientInfo(
                name: 'Test',
                age: 20,
                gender: 'F',
                city: 'Delhi',
                heightCm: -5)
            .validate(),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => const PatientInfo(
                name: 'Test',
                age: 20,
                gender: 'F',
                city: 'Delhi',
                weightKg: 600)
            .validate(),
        throwsA(isA<ValidationError>()),
      );
    });

    test('Patient root entity with clinical history roundtrip', () {
      final patient = Patient(
        id: const PatientId('p-12345'),
        info: const PatientInfo(
          name: 'Sunita Sharma',
          age: 38,
          gender: 'Female',
          city: 'Mumbai',
        ),
        history: const ClinicalHistory(
          previousConditions: ['Hypertension'],
          allergies: [
            Allergy(allergen: 'Penicillin', severity: 'Severe', reaction: 'Anaphylaxis'),
          ],
          medications: [
            MedicationRecord(medicationName: 'Amlodipine', dosage: '5mg', frequency: 'OD'),
          ],
        ),
      );

      expect(patient.name, equals('Sunita Sharma'));
      expect(patient.age, equals(38));
      expect(patient.history.allergies.first.allergen, equals('Penicillin'));

      final map = patient.toMap();
      final reconstructed = Patient.fromMap(map);
      expect(reconstructed.id, equals(patient.id));
      expect(reconstructed.name, equals('Sunita Sharma'));
      expect(reconstructed.history.allergies.length, equals(1));
      expect(reconstructed.history.allergies.first.allergen, equals('Penicillin'));
      expect(reconstructed.history.medications.first.medicationName, equals('Amlodipine'));
    });
  });

  group('Doctor Domain Models', () {
    test('DoctorProfile valid construction, validation and serialization', () {
      final profile = DoctorProfile(
        id: const DoctorId('d-999'),
        name: 'Dr. Aarti Sharma',
        clinicName: 'City Health Clinic',
        qualifications: 'MBBS, MD',
        regNumber: 'MCI-12345',
        templateConfig: const TemplateConfig(
          widthMm: 180.0,
          heightMm: 260.0,
          unit: 'mm',
          customTemplatePath: '/vault/doctor/templates/custom_template.png',
        ),
        preferences: const DoctorPreferences(
          defaultPenWidth: 2.0,
          defaultPenColor: '#1A365D',
        ),
      );

      expect(profile.templatePath, equals('/vault/doctor/templates/custom_template.png'));
      expect(profile.templateConfig.hasCustomTemplate, isTrue);

      final map = profile.toMap();
      final roundtrip = DoctorProfile.fromMap(map);
      expect(roundtrip.id, equals(profile.id));
      expect(roundtrip.name, equals('Dr. Aarti Sharma'));
      expect(roundtrip.templatePath, equals(profile.templatePath));
      expect(roundtrip.preferences.defaultPenColor, equals('#1A365D'));
    });

    test('DoctorProfile validation rejects empty fields', () {
      expect(
        () => DoctorProfile(
          id: const DoctorId('d-1'),
          name: '',
          clinicName: 'Clinic',
        ),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => DoctorProfile(
          id: const DoctorId('d-1'),
          name: 'Doctor',
          clinicName: '',
        ),
        throwsA(isA<ValidationError>()),
      );
    });
  });

  group('Consultation Domain Models & Snapshots', () {
    test('Consultation retains snapshots independent of future profile changes', () {
      final patientSnapshot = const PatientSnapshot(
        name: 'Ravi Kumar',
        age: 42,
        gender: 'Male',
        city: 'Pune',
      );
      final doctorSnapshot = const DoctorSnapshot(
        name: 'Dr. Aarti Sharma',
        clinic: 'Original Clinic',
        qualifications: 'MBBS',
        regNumber: 'MCI-12345',
        templateImageFile: 'templates/custom_template.png',
      );

      final consultation = Consultation(
        id: const ConsultationId('c-777'),
        patientId: const PatientId('p-12345'),
        patientSnapshot: patientSnapshot,
        doctorSnapshot: doctorSnapshot,
        pageDimensions: const PageDimensions(width: 180, height: 260),
        status: ConsultationStatus.saved,
        lipiRelativePath: 'patient/p-12345/prescriptions/consultation_c-777.lipi',
      );

      // Now suppose active doctor profile changes clinics later
      final updatedDoctorProfile = DoctorProfile(
        id: const DoctorId('d-999'),
        name: 'Dr. Aarti Sharma',
        clinicName: 'NEW Modern Hospital',
        qualifications: 'MBBS, MD, FRCS',
        regNumber: 'MCI-12345',
      );

      // Verify consultation still holds the historical snapshot
      expect(consultation.doctorSnapshot.clinic, equals('Original Clinic'));
      expect(consultation.doctorSnapshot.clinic, isNot(equals(updatedDoctorProfile.clinicName)));
      expect(consultation.doctorSnapshot.templateImageFile, equals('templates/custom_template.png'));

      final map = consultation.toMap();
      final roundtrip = Consultation.fromMap(map);
      expect(roundtrip.id, equals(consultation.id));
      expect(roundtrip.doctorSnapshot.clinic, equals('Original Clinic'));
      expect(roundtrip.patientSnapshot.name, equals('Ravi Kumar'));
      expect(roundtrip.status, equals(ConsultationStatus.saved));
    });
  });
}
