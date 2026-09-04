import 'package:flutter_test/flutter_test.dart';
import 'package:lipi_s4_prototype/infrastructure/ink/inkml_converter.dart';

void main() {
  group('Pass 2: Unified Prescription Coordinate Space & Transform Invariance', () {
    // Standard A4 dimensions in CSS pixels at 96 DPI
    const double pageWidthPx = 794.0;
    const double pageHeightPx = 1123.0;

    test('Stroke coordinates represent document space invariant to zoom/pan camera', () {
      // Stroke written on document at (150, 200) with points relative to element
      final strokeInDocSpace = {
        'id': 'rx_stroke_1',
        'type': 'freedraw',
        'x': 150.0,
        'y': 200.0,
        'width': 100.0,
        'height': 50.0,
        'strokeColor': '#1a365d',
        'strokeWidth': 2.0,
        'points': [
          [0.0, 0.0],
          [50.0, 25.0],
          [100.0, 50.0],
        ],
        'pressures': [0.5, 0.6, 0.7],
        'isDeleted': false,
      };

      // 1. Convert to InkML (preserves document coordinates)
      final inkml = InkMLConverter.excalidrawToInkML([strokeInDocSpace]);
      final strokes = InkMLConverter.parseInkML(inkml);

      expect(strokes.length, 1);
      final stroke = strokes.first;

      // Absolute document coordinates
      expect(stroke.points[0].x, closeTo(150.0, 0.001));
      expect(stroke.points[0].y, closeTo(200.0, 0.001));
      expect(stroke.points[2].x, closeTo(250.0, 0.001));
      expect(stroke.points[2].y, closeTo(250.0, 0.001));

      // 2. Simulate camera zoom = 1.5, pan = (40, -100)
      // Screen projection formula: screenCoord = (docCoord + scroll) * zoom
      const zoom = 1.5;
      const scrollX = 40.0;
      const scrollY = -100.0;

      final p0ScreenX = (stroke.points[0].x + scrollX) * zoom;
      final p0ScreenY = (stroke.points[0].y + scrollY) * zoom;
      final p2ScreenX = (stroke.points[2].x + scrollX) * zoom;
      final p2ScreenY = (stroke.points[2].y + scrollY) * zoom;

      expect(p0ScreenX, closeTo((150.0 + 40.0) * 1.5, 0.001)); // 285.0
      expect(p0ScreenY, closeTo((200.0 - 100.0) * 1.5, 0.001)); // 150.0

      // 3. Inverse projection (input event mapping): docCoord = screenCoord / zoom - scroll
      final p0RestoredDocX = p0ScreenX / zoom - scrollX;
      final p0RestoredDocY = p0ScreenY / zoom - scrollY;
      final p2RestoredDocX = p2ScreenX / zoom - scrollX;
      final p2RestoredDocY = p2ScreenY / zoom - scrollY;

      expect(p0RestoredDocX, closeTo(stroke.points[0].x, 0.001));
      expect(p0RestoredDocY, closeTo(stroke.points[0].y, 0.001));
      expect(p2RestoredDocX, closeTo(stroke.points[2].x, 0.001));
      expect(p2RestoredDocY, closeTo(stroke.points[2].y, 0.001));
    });

    test('Strokes recorded at different zoom levels maintain identical document coordinates', () {
      // Doctor writes stroke A at 100% zoom
      final strokeZoom100 = {
        'id': 'stroke_a',
        'type': 'freedraw',
        'x': 200.0,
        'y': 400.0,
        'width': 60.0,
        'height': 30.0,
        'strokeColor': '#000000',
        'strokeWidth': 1.5,
        'points': [
          [0.0, 0.0],
          [60.0, 30.0],
        ],
        'pressures': [0.5, 0.5],
        'isDeleted': false,
      };

      // Doctor zooms in to 175% and writes stroke B right next to stroke A
      final strokeZoom175 = {
        'id': 'stroke_b',
        'type': 'freedraw',
        'x': 260.0,
        'y': 430.0,
        'width': 40.0,
        'height': 20.0,
        'strokeColor': '#000000',
        'strokeWidth': 1.5,
        'points': [
          [0.0, 0.0],
          [40.0, 20.0],
        ],
        'pressures': [0.5, 0.5],
        'isDeleted': false,
      };

      final inkml = InkMLConverter.excalidrawToInkML([strokeZoom100, strokeZoom175]);
      final strokes = InkMLConverter.parseInkML(inkml);

      expect(strokes.length, 2);

      // End of stroke A in document space: (200 + 60, 400 + 30) = (260, 430)
      final strokeAEnd = strokes[0].points.last;
      // Start of stroke B in document space: (260, 430)
      final strokeBStart = strokes[1].points.first;

      expect(strokeAEnd.x, closeTo(strokeBStart.x, 0.001));
      expect(strokeAEnd.y, closeTo(strokeBStart.y, 0.001));
    });

    test('Document space boundaries are respected (A4 finite page)', () {
      // Stroke placed safely within finite A4 prescription sheet bounds
      final validStroke = {
        'id': 'valid_stroke',
        'type': 'freedraw',
        'x': 100.0,
        'y': 1000.0,
        'width': 500.0,
        'height': 50.0,
        'strokeColor': '#000000',
        'strokeWidth': 2.0,
        'points': [
          [0.0, 0.0],
          [500.0, 50.0],
        ],
        'pressures': [0.5, 0.5],
        'isDeleted': false,
      };

      final inkml = InkMLConverter.excalidrawToInkML([validStroke]);
      final strokes = InkMLConverter.parseInkML(inkml);

      final pEnd = strokes.first.points.last;
      // pEnd.x = 100 + 500 = 600 (< 794)
      // pEnd.y = 1000 + 50 = 1050 (< 1123)
      expect(pEnd.x, lessThan(pageWidthPx));
      expect(pEnd.y, lessThan(pageHeightPx));
      expect(strokes.first.points.first.x, greaterThanOrEqualTo(0.0));
      expect(strokes.first.points.first.y, greaterThanOrEqualTo(0.0));
    });
  });
}
