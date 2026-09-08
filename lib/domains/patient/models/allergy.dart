/// Represents an allergy documented for a patient.
///
/// Follows ADR-0003. Allergy information is clinically critical
/// and must be preserved accurately.
class Allergy {
  final String allergen;
  final String? reaction;
  final String? severity; // e.g., mild, moderate, severe

  const Allergy({
    required this.allergen,
    this.reaction,
    this.severity,
  });

  Map<String, dynamic> toMap() => {
        'allergen': allergen,
        if (reaction != null) 'reaction': reaction,
        if (severity != null) 'severity': severity,
      };

  factory Allergy.fromMap(Map<String, dynamic> map) => Allergy(
        allergen: (map['allergen'] as String?)?.trim() ?? '',
        reaction: map['reaction'] as String?,
        severity: map['severity'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Allergy &&
          other.allergen == allergen &&
          other.reaction == reaction &&
          other.severity == severity;

  @override
  int get hashCode => Object.hash(allergen, reaction, severity);

  @override
  String toString() =>
      'Allergy(allergen: $allergen, reaction: $reaction, severity: $severity)';
}
