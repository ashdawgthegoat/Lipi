import '../../../shared/errors/lipi_error.dart';

/// Patient identifying and baseline physical information.
///
/// Follows ADR-0003:
/// Minimum patient information: Name, Age, Gender, Height, Weight, City.
class PatientInfo {
  final String name;
  final int age;
  final String gender;
  final String city;
  final double? heightCm;
  final double? weightKg;
  final String? phoneNumber;

  const PatientInfo({
    required this.name,
    required this.age,
    required this.gender,
    required this.city,
    this.heightCm,
    this.weightKg,
    this.phoneNumber,
  });

  /// Validates domain invariants for patient data.
  /// Throws [ValidationError] if invariants are violated.
  void validate() {
    if (name.trim().isEmpty) {
      throw const ValidationError('Patient name cannot be empty');
    }
    if (age < 0 || age > 150) {
      throw ValidationError('Invalid patient age: $age');
    }
    if (gender.trim().isEmpty) {
      throw const ValidationError('Patient gender cannot be empty');
    }
    if (city.trim().isEmpty) {
      throw const ValidationError('Patient city cannot be empty');
    }
    if (heightCm != null && (heightCm! <= 0 || heightCm! > 300)) {
      throw ValidationError('Invalid patient height: $heightCm cm');
    }
    if (weightKg != null && (weightKg! <= 0 || weightKg! > 500)) {
      throw ValidationError('Invalid patient weight: $weightKg kg');
    }
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'age': age,
        'gender': gender.trim(),
        'city': city.trim(),
        if (heightCm != null) 'height_cm': heightCm,
        if (weightKg != null) 'weight_kg': weightKg,
        if (phoneNumber != null) 'phone_number': phoneNumber?.trim(),
      };

  factory PatientInfo.fromMap(Map<String, dynamic> map) => PatientInfo(
        name: (map['name'] as String?)?.trim() ?? '',
        age: (map['age'] as num?)?.toInt() ?? 0,
        gender: (map['gender'] as String?)?.trim() ?? 'Other',
        city: (map['city'] as String?)?.trim() ?? '',
        heightCm: (map['height_cm'] as num?)?.toDouble(),
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        phoneNumber: map['phone_number'] as String?,
      );

  PatientInfo copyWith({
    String? name,
    int? age,
    String? gender,
    String? city,
    double? heightCm,
    double? weightKg,
    String? phoneNumber,
  }) =>
      PatientInfo(
        name: name ?? this.name,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        city: city ?? this.city,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        phoneNumber: phoneNumber ?? this.phoneNumber,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientInfo &&
          other.name == name &&
          other.age == age &&
          other.gender == gender &&
          other.city == city &&
          other.heightCm == heightCm &&
          other.weightKg == weightKg &&
          other.phoneNumber == phoneNumber;

  @override
  int get hashCode => Object.hash(
        name,
        age,
        gender,
        city,
        heightCm,
        weightKg,
        phoneNumber,
      );

  @override
  String toString() =>
      'PatientInfo(name: $name, age: $age, gender: $gender, city: $city)';
}
