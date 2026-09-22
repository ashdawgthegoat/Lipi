import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/models/clinical_document.dart';
import 'package:lipi/domains/consultation/models/ink_document.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/consultation/models/stroke.dart';
import 'package:lipi/domains/consultation/models/stroke_point.dart';
import 'package:lipi/infrastructure/ink/ink_engine.dart';
import 'package:lipi/infrastructure/ink/inkml_converter.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InkML Bidirectional Conversion', () {
    test('canonical InkDocument serializes to W3C InkML XML and parses back losslessly', () {
      final initialInk = InkDocument(
        strokes: [
          const Stroke(
            points: [
              StrokePoint(x: 100.0, y: 150.0, pressure: 0.3),
              StrokePoint(x: 120.0, y: 180.0, pressure: 0.6),
              StrokePoint(x: 150.0, y: 230.0, pressure: 0.9),
            ],
            color: '#1A365D',
            strokeWidth: 2.5,
          ),
        ],
      );

      // 1. InkDocument -> InkML XML
      final inkml = InkMLConverter.inkDocumentToInkML(initialInk);
      expect(inkml, contains('xmlns="http://www.w3.org/2003/InkML"'));
      expect(inkml, contains('<trace'));
      expect(inkml, contains('color="#1A365D"'));
      expect(inkml, contains('width="2.5"'));
      expect(inkml, contains('100.00 150.00 0.30, 120.00 180.00 0.60, 150.00 230.00 0.90'));

      // 2. InkML XML -> InkDocument
      final parsedBack = InkMLConverter.inkMLToInkDocument(inkml);
      expect(parsedBack.strokeCount, equals(1));
      final stroke = parsedBack.strokes.first;
      expect(stroke.color, equals('#1A365D'));
      expect(stroke.strokeWidth, equals(2.5));
      expect(stroke.points.length, equals(3));
      expect(stroke.points[0].x, closeTo(100.0, 0.01));
      expect(stroke.points[0].y, closeTo(150.0, 0.01));
      expect(stroke.points[0].pressure, closeTo(0.3, 0.01));
      expect(stroke.points[1].x, closeTo(120.0, 0.01));
      expect(stroke.points[1].y, closeTo(180.0, 0.01));
      expect(stroke.points[1].pressure, closeTo(0.6, 0.01));
      expect(stroke.points[2].x, closeTo(150.0, 0.01));
      expect(stroke.points[2].y, closeTo(230.0, 0.01));
      expect(stroke.points[2].pressure, closeTo(0.9, 0.01));
    });
  });

  group('Coordinate Space Invariance', () {
    test('Document space calculation is invariant to zoom and screen scale', () {
      // Finite A4 document: 180mm x 260mm at 96 DPI (1mm ~= 3.78px)
      const widthMm = 180.0;
      const heightMm = 260.0;

      final docPxW = (widthMm * 3.78).roundToDouble();
      final docPxH = (heightMm * 3.78).roundToDouble();

      expect(docPxW, equals(680.0));
      expect(docPxH, equals(983.0));

      // Coordinate on finite document
      const docPt = StrokePoint(x: 340.0, y: 491.5);

      // Simulating zoom factor 2.0 and scroll offset
      const zoom = 2.0;
      const scrollX = 100.0;
      const scrollY = 50.0;

      final screenX = (docPt.x + scrollX) * zoom;
      final screenY = (docPt.y + scrollY) * zoom;

      // Inverse projection to canonical document space
      final recoveredDocX = (screenX / zoom) - scrollX;
      final recoveredDocY = (screenY / zoom) - scrollY;

      expect(recoveredDocX, closeTo(docPt.x, 0.001));
      expect(recoveredDocY, closeTo(docPt.y, 0.001));
    });
  });

  group('Native InkEngine Lifecycle', () {
    test('loads document, manages stroke updates, and exports canonical ink', () async {
      final engine = InkEngine();

      final initialInk = InkDocument(
        strokes: [
          const Stroke(
            points: [
              StrokePoint(x: 50.0, y: 60.0, pressure: 0.5),
              StrokePoint(x: 70.0, y: 80.0, pressure: 0.8),
            ],
            color: '#000000',
            strokeWidth: 2.0,
          ),
        ],
      );

      final doc = ClinicalDocument(
        consultationId: ConsultationId('con-engine-test'),
        patientSnapshot: const PatientSnapshot(name: 'Devi Sharma', age: 28, gender: 'Female', city: 'Delhi'),
        ink: initialInk,
      );

      await engine.loadDocument(doc);
      expect(engine.currentDocument, equals(doc));
      expect(engine.controller.strokes.length, equals(1));

      final exported = await engine.exportCurrentInk();
      expect(exported.strokeCount, equals(1));
      expect(exported.strokes.first, equals(initialInk.strokes.first));

      await engine.dispose();
    });
  });
}
