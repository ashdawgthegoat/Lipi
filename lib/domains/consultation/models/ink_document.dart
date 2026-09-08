import 'stroke.dart';

/// Digital ink payload of a clinical document page.
///
/// Follows ADR-0005: Preserves exact stroke ordering, points, and vector geometry.
class InkDocument {
  final List<Stroke> strokes;

  const InkDocument({
    this.strokes = const [],
  });

  bool get isEmpty => strokes.isEmpty;
  bool get isNotEmpty => strokes.isNotEmpty;
  int get strokeCount => strokes.length;

  void validate() {
    for (final s in strokes) {
      s.validate();
    }
  }

  Map<String, dynamic> toMap() => {
        'strokes': strokes.map((s) => s.toMap()).toList(),
      };

  factory InkDocument.fromMap(Map<String, dynamic> map) => InkDocument(
        strokes: (map['strokes'] as List<dynamic>?)
                ?.map((s) => Stroke.fromMap(s as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  @override
  String toString() => 'InkDocument(${strokes.length} strokes)';
}
