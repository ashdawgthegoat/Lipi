class PatientRecord {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String city;
  final DateTime createdAt;

  PatientRecord({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.city,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'city': city,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PatientRecord.fromMap(Map<String, dynamic> map) {
    return PatientRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      age: map['age'] as int,
      gender: map['gender'] as String,
      city: map['city'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class PrescriptionSummary {
  final String consultationId;
  final String patientId;
  final String filePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasPdf;

  PrescriptionSummary({
    required this.consultationId,
    required this.patientId,
    required this.filePath,
    required this.createdAt,
    required this.updatedAt,
    this.hasPdf = false,
  });
}
