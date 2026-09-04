import 'package:flutter_test/flutter_test.dart';
import 'package:lipi_s4_prototype/infrastructure/ink/inkml_converter.dart';

void main() {
  group('InkMLConverter', () {
    test('converts Excalidraw freedraw element to InkML and parses back', () {
      final excalidrawElements = [
        {
          'id': 'el_1',
          'type': 'freedraw',
          'x': 100.0,
          'y': 200.0,
          'width': 50.0,
          'height': 30.0,
          'strokeColor': '#1a365d',
          'strokeWidth': 2.0,
          'points': [
            [0.0, 0.0],
            [10.0, 5.0],
            [30.0, 20.0],
            [50.0, 30.0],
          ],
          'pressures': [0.4, 0.6, 0.8, 0.5],
          'isDeleted': false,
        },
        {
          'id': 'el_2',
          'type': 'freedraw',
          'x': 50.0,
          'y': 350.0,
          'width': 80.0,
          'height': 10.0,
          'strokeColor': '#000000',
          'strokeWidth': 1.0,
          'points': [
            [0.0, 0.0],
            [40.0, 5.0],
            [80.0, 10.0],
          ],
          'pressures': [0.5, 0.5, 0.5],
          'isDeleted': false,
        },
      ];

      // 1. Convert to InkML XML
      final inkml = InkMLConverter.excalidrawToInkML(excalidrawElements);
      expect(inkml, contains('<ink xmlns="http://www.w3.org/2003/InkML">'));
      expect(inkml, contains('<trace'));
      expect(inkml, contains('color="#1a365d"'));
      expect(inkml, contains('color="#000000"'));

      // 2. Parse InkML to InkStrokes for rendering
      final strokes = InkMLConverter.parseInkML(inkml);
      expect(strokes.length, 2);

      // Stroke 1 verification
      expect(strokes[0].color, '#1a365d');
      expect(strokes[0].strokeWidth, 2.0);
      expect(strokes[0].points.length, 4);
      // Verify absolute coordinates: x=100, y=200
      expect(strokes[0].points[0].x, closeTo(100.0, 0.01));
      expect(strokes[0].points[0].y, closeTo(200.0, 0.01));
      expect(strokes[0].points[0].pressure, closeTo(0.4, 0.01));
      expect(strokes[0].points[3].x, closeTo(150.0, 0.01));
      expect(strokes[0].points[3].y, closeTo(230.0, 0.01));
      expect(strokes[0].points[3].pressure, closeTo(0.5, 0.01));

      // Stroke 2 verification (stroke order preserved!)
      expect(strokes[1].color, '#000000');
      expect(strokes[1].strokeWidth, 1.0);
      expect(strokes[1].points.length, 3);
      expect(strokes[1].points[0].x, closeTo(50.0, 0.01));
      expect(strokes[1].points[0].y, closeTo(350.0, 0.01));

      // 3. Convert InkML back to Excalidraw elements for reopening
      final restoredElements = InkMLConverter.inkMLToExcalidraw(inkml);
      expect(restoredElements.length, 2);

      final r1 = restoredElements[0];
      expect(r1['type'], 'freedraw');
      expect(r1['x'], closeTo(100.0, 0.01));
      expect(r1['y'], closeTo(200.0, 0.01));
      expect(r1['width'], closeTo(50.0, 0.01));
      expect(r1['height'], closeTo(30.0, 0.01));
      expect(r1['strokeColor'], '#1a365d');
      expect(r1['strokeWidth'], 2.0);

      final r1Points = r1['points'] as List<List<double>>;
      expect(r1Points[0], [0.0, 0.0]);
      expect(r1Points[3][0], closeTo(50.0, 0.01));
      expect(r1Points[3][1], closeTo(30.0, 0.01));

      final r1Pressures = r1['pressures'] as List<double>;
      expect(r1Pressures[0], closeTo(0.4, 0.01));
      expect(r1Pressures[2], closeTo(0.8, 0.01));
    });

    test('ignores deleted Excalidraw elements', () {
      final elements = [
        {
          'id': 'active_el',
          'type': 'freedraw',
          'x': 10.0,
          'y': 10.0,
          'points': [[0.0, 0.0], [5.0, 5.0]],
          'pressures': [0.5, 0.5],
          'isDeleted': false,
        },
        {
          'id': 'deleted_el',
          'type': 'freedraw',
          'x': 100.0,
          'y': 100.0,
          'points': [[0.0, 0.0], [10.0, 10.0]],
          'pressures': [0.5, 0.5],
          'isDeleted': true,
        },
      ];

      final inkml = InkMLConverter.excalidrawToInkML(elements);
      final strokes = InkMLConverter.parseInkML(inkml);
      expect(strokes.length, 1);
    });
  });
}
