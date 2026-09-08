/// Represents a medication previously or currently taken by a patient.
///
/// Follows ADR-0003: Patient Medication History.
class MedicationRecord {
  final String medicationName;
  final String? dosage;
  final String? frequency;
  final String? notes;

  const MedicationRecord({
    required this.medicationName,
    this.dosage,
    this.frequency,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'medication_name': medicationName,
        if (dosage != null) 'dosage': dosage,
        if (frequency != null) 'frequency': frequency,
        if (notes != null) 'notes': notes,
      };

  factory MedicationRecord.fromMap(Map<String, dynamic> map) =>
      MedicationRecord(
        medicationName: (map['medication_name'] as String?)?.trim() ?? '',
        dosage: map['dosage'] as String?,
        frequency: map['frequency'] as String?,
        notes: map['notes'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationRecord &&
          other.medicationName == medicationName &&
          other.dosage == dosage &&
          other.frequency == frequency &&
          other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(medicationName, dosage, frequency, notes);

  @override
  String toString() =>
      'MedicationRecord(name: $medicationName, dosage: $dosage, frequency: $frequency)';
}
