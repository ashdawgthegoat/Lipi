import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/models/stroke_point.dart';
import 'package:lipi/infrastructure/ink/editor_bridge.dart';
import 'package:lipi/infrastructure/ink/editor_runtime_server.dart';
import 'package:lipi/infrastructure/ink/inkml_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('InkML and Excalidraw Element Conversion', () {
    test('Excalidraw freedraw element converts to canonical InkDocument and back', () {
      final rawExcalidrawElements = [
        {
          'id': 'test-1',
          'type': 'freedraw',
          'x': 100.0,
          'y': 150.0,
          'strokeColor': '#1A365D',
          'strokeWidth': 2.5,
          'points': [
            [0.0, 0.0],
            [20.0, 30.0],
            [50.0, 80.0],
          ],
          'pressures': [0.3, 0.6, 0.9],
        }
      ];

      // 1. Excalidraw -> InkDocument
      final inkDoc = InkMLConverter.excalidrawToInkDocument(rawExcalidrawElements);
      expect(inkDoc.strokeCount, equals(1));
      final stroke = inkDoc.strokes.first;
      expect(stroke.color, equals('#1A365D'));
      expect(stroke.strokeWidth, equals(2.5));
      expect(stroke.points.length, equals(3));
      // Verify absolute coordinates: origin + delta
      expect(stroke.points[0].x, equals(100.0));
      expect(stroke.points[0].y, equals(150.0));
      expect(stroke.points[0].pressure, closeTo(0.3, 0.01));
      expect(stroke.points[2].x, equals(150.0));
      expect(stroke.points[2].y, equals(230.0));
      expect(stroke.points[2].pressure, closeTo(0.9, 0.01));

      // 2. InkDocument -> InkML XML
      final inkml = InkMLConverter.inkDocumentToInkML(inkDoc);
      expect(inkml, contains('trace'));
      expect(inkml, contains('#1A365D'));

      // 3. InkML XML -> InkDocument
      final parsedBack = InkMLConverter.inkMLToInkDocument(inkml);
      expect(parsedBack.strokeCount, equals(1));
      expect(parsedBack.strokes.first.points.length, equals(3));
      expect(parsedBack.strokes.first.points[2].x, closeTo(150.0, 0.01));
      expect(parsedBack.strokes.first.points[2].y, closeTo(230.0, 0.01));

      // 4. InkDocument -> Excalidraw elements
      final reGeneratedElements = InkMLConverter.inkDocumentToExcalidraw(parsedBack);
      expect(reGeneratedElements.length, equals(1));
      final el = reGeneratedElements.first;
      expect(el['type'], equals('freedraw'));
      expect(el['strokeColor'], equals('#1A365D'));
      expect((el['points'] as List).length, equals(3));
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

  group('EditorBridge Message Handling', () {
    test('Dispatches onReady, onInitialized, onInkChanged callbacks', () {
      final bridge = EditorBridge();
      bool readyCalled = false;
      bool initializedCalled = false;
      bool hasTemplate = false;
      bool inkChangedCalled = false;

      bridge.onReady = () => readyCalled = true;
      bridge.onInitialized = (tmpl) {
        initializedCalled = true;
        hasTemplate = tmpl;
      };
      bridge.onInkChanged = () => inkChangedCalled = true;

      bridge.handleIncomingMessage(jsonEncode({'type': 'READY'}));
      expect(readyCalled, isTrue);
      expect(bridge.isEditorReady, isTrue);

      bridge.handleIncomingMessage(
        jsonEncode({'type': 'INITIALIZED', 'hasTemplateImage': true}),
      );
      expect(initializedCalled, isTrue);
      expect(hasTemplate, isTrue);

      bridge.handleIncomingMessage(jsonEncode({'type': 'INK_CHANGED'}));
      expect(inkChangedCalled, isTrue);
    });
  });

  group('EditorRuntimeServer Loopback Tests', () {
    final server = EditorRuntimeServer.instance;

    tearDownAll(() async {
      await server.stop();
    });

    test('Starts on loopback IPv4 and serves custom_template', () async {
      final port = await server.ensureStarted();
      expect(port, greaterThan(0));
      expect(server.isRunning, isTrue);

      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      server.setCustomTemplate(testBytes, 'image/png');

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/custom_template'));
      final response = await request.close();

      expect(response.statusCode, equals(200));
      expect(response.headers.value('content-type'), equals('image/png'));
      final received = await response.fold<List<int>>([], (acc, b) => acc..addAll(b));
      expect(Uint8List.fromList(received), equals(testBytes));
      client.close();
    });
  });
}
