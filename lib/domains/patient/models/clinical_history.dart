import 'allergy.dart';
import 'medication_record.dart';

/// Represents longitudinal background clinical information for a patient.
///
/// Follows ADR-0003:
/// - Previous medical conditions
/// - Previous symptoms
/// - Medication history
/// - Allergy information
class ClinicalHistory {
  final List<String> previousConditions;
  final List<String> previousSymptoms;
  final List<MedicationRecord> medications;
  final List<Allergy> allergies;
  final String? clinicalNotes;

  const ClinicalHistory({
    this.previousConditions = const [],
    this.previousSymptoms = const [],
    this.medications = const [],
    this.allergies = const [],
    this.clinicalNotes,
  });

  Map<String, dynamic> toMap() => {
        'previous_conditions': previousConditions,
        'previous_symptoms': previousSymptoms,
        'medications': medications.map((m) => m.toMap()).toList(),
        'allergies': allergies.map((a) => a.toMap()).toList(),
        if (clinicalNotes != null) 'clinical_notes': clinicalNotes,
      };

  factory ClinicalHistory.fromMap(Map<String, dynamic> map) => ClinicalHistory(
        previousConditions: (map['previous_conditions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        previousSymptoms: (map['previous_symptoms'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        medications: (map['medications'] as List<dynamic>?)
                ?.map((m) => MedicationRecord.fromMap(m as Map<String, dynamic>))
                .toList() ??
            const [],
        allergies: (map['allergies'] as List<dynamic>?)
                ?.map((a) => Allergy.fromMap(a as Map<String, dynamic>))
                .toList() ??
            const [],
        clinicalNotes: map['clinical_notes'] as String?,
      );

  ClinicalHistory copyWith({
    List<String>? previousConditions,
    List<String>? previousSymptoms,
    List<MedicationRecord>? medications,
    List<Allergy>? allergies,
    String? clinicalNotes,
  }) =>
      ClinicalHistory(
        previousConditions: previousConditions ?? this.previousConditions,
        previousSymptoms: previousSymptoms ?? this.previousSymptoms,
        medications: medications ?? this.medications,
        allergies: allergies ?? this.allergies,
        clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      );
}
