import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/models/clinical_document.dart';
import 'package:lipi/domains/consultation/models/doctor_snapshot.dart';
import 'package:lipi/domains/consultation/models/ink_document.dart';
import 'package:lipi/domains/consultation/models/page_dimensions.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/consultation/models/stroke.dart';
import 'package:lipi/domains/consultation/models/stroke_point.dart';
import 'package:lipi/shared/errors/lipi_error.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  group('Canonical Digital Ink Model', () {
    test('StrokePoint validates finite coordinates and pressure range', () {
      const valid = StrokePoint(x: 100.5, y: 200.25, pressure: 0.75);
      expect(() => valid.validate(), returnsNormally);

      expect(
        () => const StrokePoint(x: double.nan, y: 10.0).validate(),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => const StrokePoint(x: 10.0, y: double.infinity).validate(),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => const StrokePoint(x: 10.0, y: 20.0, pressure: 1.5).validate(),
        throwsA(isA<ValidationError>()),
      );
    });

    test('Stroke preserves point ordering and attributes', () {
      final stroke = Stroke(
        points: const [
          StrokePoint(x: 10, y: 10, pressure: 0.2),
          StrokePoint(x: 20, y: 25, pressure: 0.4),
          StrokePoint(x: 35, y: 50, pressure: 0.8),
        ],
        color: '#1A365D',
        strokeWidth: 2.5,
      );
      expect(() => stroke.validate(), returnsNormally);
      expect(stroke.points.length, equals(3));
      expect(stroke.points[0].x, equals(10));
      expect(stroke.points[2].x, equals(35));
      expect(stroke.color, equals('#1A365D'));
      expect(stroke.strokeWidth, equals(2.5));
    });

    test('Stroke rejects empty points or non-positive width', () {
      expect(
        () => const Stroke(points: []).validate(),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => const Stroke(
          points: [StrokePoint(x: 1, y: 1)],
          strokeWidth: 0,
        ).validate(),
        throwsA(isA<ValidationError>()),
      );
    });

    test('InkDocument preserves exact stroke sequence', () {
      final s1 = const Stroke(points: [StrokePoint(x: 0, y: 0)], color: '#000');
      final s2 = const Stroke(points: [StrokePoint(x: 10, y: 10)], color: '#FFF');
      final doc = InkDocument(strokes: [s1, s2]);

      expect(doc.strokeCount, equals(2));
      expect(doc.strokes[0].color, equals('#000'));
      expect(doc.strokes[1].color, equals('#FFF'));
    });
  });

  group('Canonical ClinicalDocument Model', () {
    test('Valid ClinicalDocument construction and snapshot preservation', () {
      final dummyPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      final doc = ClinicalDocument(
        consultationId: const ConsultationId('cons-999'),
        page: const PageDimensions(width: 180, height: 260, unit: 'mm'),
        patientSnapshot: const PatientSnapshot(
          name: 'Sunita Sharma',
          age: 38,
          gender: 'Female',
          city: 'Pune',
        ),
        doctorSnapshot: const DoctorSnapshot(
          name: 'Dr. Aarti Sharma',
          clinic: 'City Clinic',
          qualifications: 'MBBS, MD',
          regNumber: 'REG-12345',
          templateImageFile: 'templates/custom_template.png',
        ),
        ink: InkDocument(strokes: [
          const Stroke(points: [StrokePoint(x: 50, y: 50, pressure: 0.5)]),
        ]),
        templateBytes: dummyPng,
      );

      expect(doc.format, equals('lipi'));
      expect(doc.version, equals(1));
      expect(doc.consultationId.value, equals('cons-999'));
      expect(doc.hasCustomTemplate, isTrue);
      expect(doc.ink.strokeCount, equals(1));
    });

    test('ClinicalDocument rejects invalid format or empty patient name', () {
      expect(
        () => ClinicalDocument(
          format: 'invalid_format',
          consultationId: const ConsultationId('c-1'),
          patientSnapshot: const PatientSnapshot(name: 'A', age: 20, gender: 'M', city: 'C'),
        ),
        throwsA(isA<ValidationError>()),
      );

      expect(
        () => ClinicalDocument(
          version: 2,
          consultationId: const ConsultationId('c-1'),
          patientSnapshot: const PatientSnapshot(name: 'A', age: 20, gender: 'M', city: 'C'),
        ),
        throwsA(isA<ValidationError>()),
      );

      expect(
        () => ClinicalDocument(
          consultationId: const ConsultationId('c-1'),
          patientSnapshot: const PatientSnapshot(name: '', age: 20, gender: 'M', city: 'C'),
        ),
        throwsA(isA<ValidationError>()),
      );
    });
  });
}
