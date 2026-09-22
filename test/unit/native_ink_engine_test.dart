import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/models/clinical_document.dart';
import 'package:lipi/domains/consultation/models/ink_document.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/consultation/models/stroke.dart';
import 'package:lipi/domains/consultation/models/stroke_point.dart';
import 'package:lipi/infrastructure/ink/inkml_converter.dart';
import 'package:lipi/infrastructure/ink/native_ink_controller.dart';
import 'package:lipi/infrastructure/ink/native_ink_engine.dart';
import 'package:lipi/infrastructure/ink/stroke_model_ext.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  group('NativeInkController Stroke Drawing Lifecycle', () {
    test('creates and commits canonical strokes with exact points and pressure', () {
      final controller = NativeInkController(
        initialStrokeWidth: 2.5,
        initialStrokeColor: '#1A365D',
      );

      expect(controller.strokes, isEmpty);
      expect(controller.isDrawingStroke, isFalse);

      // Start drawing
      controller.startStroke(const Offset(100.0, 150.0), 0.35);
      expect(controller.isDrawingStroke, isTrue);
      expect(controller.activePoints.length, equals(1));
      expect(controller.activePoints.first.x, equals(100.0));
      expect(controller.activePoints.first.y, equals(150.0));
      expect(controller.activePoints.first.pressure, closeTo(0.35, 0.001));

      // Move pointer
      controller.updateStroke(const Offset(120.0, 180.0), 0.70);
      controller.updateStroke(const Offset(150.0, 220.0), 0.95);
      expect(controller.activePoints.length, equals(3));

      // End stroke -> commits to canonical strokes
      controller.endStroke();
      expect(controller.isDrawingStroke, isFalse);
      expect(controller.activePoints, isEmpty);
      expect(controller.strokes.length, equals(1));

      final stroke = controller.strokes.first;
      expect(stroke.color, equals('#1A365D'));
      expect(stroke.strokeWidth, equals(2.5));
      expect(stroke.points.length, equals(3));
      expect(stroke.points[0].x, equals(100.0));
      expect(stroke.points[0].y, equals(150.0));
      expect(stroke.points[0].pressure, closeTo(0.35, 0.001));
      expect(stroke.points[1].x, equals(120.0));
      expect(stroke.points[1].y, equals(180.0));
      expect(stroke.points[1].pressure, closeTo(0.70, 0.001));
      expect(stroke.points[2].x, equals(150.0));
      expect(stroke.points[2].y, equals(220.0));
      expect(stroke.points[2].pressure, closeTo(0.95, 0.001));
    });

    test('generates valid rendering Path for single-point dots and multi-point strokes', () {
      final dotStroke = const Stroke(
        points: [StrokePoint(x: 50.0, y: 50.0, pressure: 0.6)],
        color: '#000000',
        strokeWidth: 2.0,
      );

      final dotPath = NativeStrokeRenderer.getStrokePath(dotStroke);
      expect(dotPath.getBounds().isEmpty, isFalse);
      expect(dotPath.getBounds().contains(const Offset(50.0, 50.0)), isTrue);

      final lineStroke = const Stroke(
        points: [
          StrokePoint(x: 10.0, y: 10.0, pressure: 0.5),
          StrokePoint(x: 50.0, y: 50.0, pressure: 0.8),
          StrokePoint(x: 90.0, y: 90.0, pressure: 0.4),
        ],
        color: '#1A365D',
        strokeWidth: 3.0,
      );

      final linePath = NativeStrokeRenderer.getStrokePath(lineStroke);
      expect(linePath.getBounds().isEmpty, isFalse);
      expect(linePath.getBounds().width, greaterThan(50.0));
    });
  });

  group('Native Stroke-Level Undo / Redo', () {
    test('undo removes stroke and redo restores stroke', () {
      final controller = NativeInkController();

      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);

      // Draw stroke 1
      controller.startStroke(const Offset(10, 10), 0.5);
      controller.updateStroke(const Offset(20, 20), 0.5);
      controller.endStroke();

      expect(controller.strokes.length, equals(1));
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);

      // Draw stroke 2
      controller.startStroke(const Offset(30, 30), 0.5);
      controller.updateStroke(const Offset(40, 40), 0.5);
      controller.endStroke();

      expect(controller.strokes.length, equals(2));

      // Undo stroke 2
      controller.undo();
      expect(controller.strokes.length, equals(1));
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isTrue);

      // Undo stroke 1
      controller.undo();
      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);

      // Redo stroke 1
      controller.redo();
      expect(controller.strokes.length, equals(1));

      // Redo stroke 2
      controller.redo();
      expect(controller.strokes.length, equals(2));
      expect(controller.canRedo, isFalse);
    });

    test('new edit after undo invalidates redo branch', () {
      final controller = NativeInkController();

      controller.startStroke(const Offset(10, 10), 0.5);
      controller.endStroke();
      controller.startStroke(const Offset(20, 20), 0.5);
      controller.endStroke();

      expect(controller.strokes.length, equals(2));

      // Undo stroke 2 -> redo is available
      controller.undo();
      expect(controller.canRedo, isTrue);

      // Draw brand new stroke -> redo branch MUST be cleared
      controller.startStroke(const Offset(99, 99), 0.5);
      controller.endStroke();

      expect(controller.strokes.length, equals(2));
      expect(controller.canRedo, isFalse);
    });
  });

  group('Eraser Hit-Testing and History', () {
    test('strokeIntersectsCircle accurately identifies stroke intersection', () {
      final stroke = const Stroke(
        points: [
          StrokePoint(x: 100.0, y: 100.0),
          StrokePoint(x: 200.0, y: 100.0),
        ],
        strokeWidth: 2.0,
      );

      // Hit directly on line
      expect(
        NativeStrokeRenderer.strokeIntersectsCircle(stroke, const Offset(150.0, 100.0), 10.0),
        isTrue,
      );

      // Hit near endpoint
      expect(
        NativeStrokeRenderer.strokeIntersectsCircle(stroke, const Offset(95.0, 100.0), 10.0),
        isTrue,
      );

      // Miss far away
      expect(
        NativeStrokeRenderer.strokeIntersectsCircle(stroke, const Offset(150.0, 200.0), 10.0),
        isFalse,
      );
    });

    test('erasing multiple strokes in one gesture forms a single reversible undo unit', () {
      final controller = NativeInkController(initialEraserRadius: 15.0);

      // Draw 3 horizontal strokes
      // Stroke 0 at y=100
      controller.startStroke(const Offset(50, 100), 0.5);
      controller.updateStroke(const Offset(150, 100), 0.5);
      controller.endStroke();

      // Stroke 1 at y=150
      controller.startStroke(const Offset(50, 150), 0.5);
      controller.updateStroke(const Offset(150, 150), 0.5);
      controller.endStroke();

      // Stroke 2 at y=200
      controller.startStroke(const Offset(50, 200), 0.5);
      controller.updateStroke(const Offset(150, 200), 0.5);
      controller.endStroke();

      expect(controller.strokes.length, equals(3));

      // Switch to eraser and drag vertically through Stroke 0 and Stroke 1
      controller.setToolMode(InkToolMode.eraser);
      controller.startErasing(const Offset(100, 100)); // hits Stroke 0
      controller.updateErasing(const Offset(100, 150)); // hits Stroke 1
      controller.endErasing();

      // 2 strokes erased; only Stroke 2 remains
      expect(controller.strokes.length, equals(1));
      expect(controller.strokes.first.points.first.y, equals(200));

      // Single undo restores both erased strokes in original sequence!
      controller.undo();
      expect(controller.strokes.length, equals(3));
      expect(controller.strokes[0].points.first.y, equals(100));
      expect(controller.strokes[1].points.first.y, equals(150));
      expect(controller.strokes[2].points.first.y, equals(200));

      // Redo removes them again
      controller.redo();
      expect(controller.strokes.length, equals(1));
    });
  });

  group('Clear All and Reversibility', () {
    test('clear wipes canvas and undo restores all strokes', () {
      final controller = NativeInkController();
      controller.startStroke(const Offset(10, 10), 0.5);
      controller.endStroke();
      controller.startStroke(const Offset(20, 20), 0.5);
      controller.endStroke();

      expect(controller.strokes.length, equals(2));

      controller.clear();
      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.strokes.length, equals(2));

      controller.redo();
      expect(controller.strokes, isEmpty);
    });
  });

  group('Document Round-Trip and NativeInkEngine Facade', () {
    test('loadDocument and exportCurrentInk preserve full vector fidelity', () async {
      final engine = NativeInkEngine();

      final initialInk = InkDocument(strokes: [
        const Stroke(
          points: [
            StrokePoint(x: 120.5, y: 240.5, pressure: 0.42),
            StrokePoint(x: 145.0, y: 290.0, pressure: 0.88),
          ],
          color: '#1A365D',
          strokeWidth: 2.5,
        ),
      ]);

      final doc = ClinicalDocument(
        consultationId: ConsultationId('con-facade-1'),
        patientSnapshot: const PatientSnapshot(name: 'Asha Patel', age: 34, gender: 'Female', city: 'Mumbai'),
        ink: initialInk,
      );

      await engine.loadDocument(doc);
      expect(engine.controller.strokes.length, equals(1));

      final exportedInk = await engine.exportCurrentInk();
      expect(exportedInk.strokes.length, equals(1));
      expect(exportedInk.strokes.first, equals(initialInk.strokes.first));

      // InkML roundtrip verification
      final xml = InkMLConverter.inkDocumentToInkML(exportedInk);
      final parsed = InkMLConverter.inkMLToInkDocument(xml);
      expect(parsed.strokeCount, equals(1));
      expect(parsed.strokes.first.points[0].x, closeTo(120.5, 0.01));
      expect(parsed.strokes.first.points[0].pressure, closeTo(0.42, 0.01));

      await engine.dispose();
    });

    test('document space coordinates are invariant to zoom and scale factors', () {
      const docWidthMm = 180.0;
      const docHeightMm = 260.0;
      final pxWidth = (docWidthMm * 3.78).roundToDouble();
      final pxHeight = (docHeightMm * 3.78).roundToDouble();

      expect(pxWidth, equals(680.0));
      expect(pxHeight, equals(983.0));

      // Canonical coordinate
      const targetPoint = StrokePoint(x: 250.0, y: 400.0, pressure: 0.7);

      // Transform matrix with 1.75x zoom and translation offset (80, 50)
      final matrix = Matrix4.identity()
        ..translateByDouble(80.0, 50.0, 0.0, 1.0)
        ..scaleByDouble(1.75, 1.75, 1.0, 1.0);

      // Project to screen space
      final screenPoint = MatrixUtils.transformPoint(matrix, Offset(targetPoint.x, targetPoint.y));

      // Invert back to document space
      final inverted = Matrix4.tryInvert(matrix)!;
      final docPoint = MatrixUtils.transformPoint(inverted, screenPoint);

      expect(docPoint.dx, closeTo(targetPoint.x, 0.0001));
      expect(docPoint.dy, closeTo(targetPoint.y, 0.0001));
    });
  });
}
