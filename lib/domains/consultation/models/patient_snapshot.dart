/// Immutable snapshot of patient information captured into a consultation.
///
/// Follows ADR-0005 and ADR-0008 Section 16:
/// Guarantees that historical prescriptions remain historically faithful
/// even if patient details are subsequently modified in the database.
class PatientSnapshot {
  final String name;
  final int age;
  final String gender;
  final String city;

  const PatientSnapshot({
    required this.name,
    required this.age,
    required this.gender,
    required this.city,
  });

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'age': age,
        'gender': gender.trim(),
        'city': city.trim(),
      };

  factory PatientSnapshot.fromJson(Map<String, dynamic> json) =>
      PatientSnapshot(
        name: (json['name'] as String?)?.trim() ?? '',
        age: (json['age'] as num?)?.toInt() ?? 0,
        gender: (json['gender'] as String?)?.trim() ?? '',
        city: (json['city'] as String?)?.trim() ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientSnapshot &&
          other.name == name &&
          other.age == age &&
          other.gender == gender &&
          other.city == city;

  @override
  int get hashCode => Object.hash(name, age, gender, city);

  @override
  String toString() => 'PatientSnapshot($name, $age Y, $gender, $city)';
}
