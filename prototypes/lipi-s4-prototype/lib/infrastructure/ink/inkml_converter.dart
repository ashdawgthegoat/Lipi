import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

class InkPoint {
  final double x;
  final double y;
  final double pressure;

  const InkPoint(this.x, this.y, [this.pressure = 0.5]);
}

class InkStroke {
  final List<InkPoint> points;
  final String color;
  final double strokeWidth;

  const InkStroke({
    required this.points,
    this.color = '#000000',
    this.strokeWidth = 1.0,
  });
}

class InkMLConverter {
  static const _uuid = Uuid();

  /// Converts a list of Excalidraw scene elements to an InkML XML string.
  static String excalidrawToInkML(List<dynamic> elements) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('ink', attributes: {'xmlns': 'http://www.w3.org/2003/InkML'}, nest: () {
      builder.element('definitions', nest: () {
        builder.element('context', attributes: {'xml:id': 'ctx0'}, nest: () {
          builder.element('inkSource', attributes: {'xml:id': 'source0'}, nest: () {
            builder.element('traceFormat', nest: () {
              builder.element('channel', attributes: {'name': 'X', 'type': 'decimal'});
              builder.element('channel', attributes: {'name': 'Y', 'type': 'decimal'});
              builder.element('channel', attributes: {'name': 'F', 'type': 'decimal'});
            });
          });
        });
      });

      for (final el in elements) {
        if (el is! Map<String, dynamic>) continue;
        if (el['type'] != 'freedraw') continue;
        if (el['isDeleted'] == true) continue;

        final double originX = (el['x'] as num?)?.toDouble() ?? 0.0;
        final double originY = (el['y'] as num?)?.toDouble() ?? 0.0;
        final strokeColor = (el['strokeColor'] as String?) ?? '#000000';
        final strokeWidth = (el['strokeWidth'] as num?)?.toDouble() ?? 1.0;

        final pointsList = el['points'] as List<dynamic>? ?? [];
        final pressuresList = el['pressures'] as List<dynamic>? ?? [];

        if (pointsList.isEmpty) continue;

        final coordsBuffer = StringBuffer();
        for (int i = 0; i < pointsList.length; i++) {
          final pt = pointsList[i] as List<dynamic>;
          final double dx = (pt[0] as num).toDouble();
          final double dy = (pt[1] as num).toDouble();
          final double absX = originX + dx;
          final double absY = originY + dy;
          final double p = (i < pressuresList.length && pressuresList[i] is num)
              ? (pressuresList[i] as num).toDouble()
              : 0.5;

          if (i > 0) coordsBuffer.write(', ');
          coordsBuffer.write('${absX.toStringAsFixed(2)} ${absY.toStringAsFixed(2)} ${p.toStringAsFixed(2)}');
        }

        builder.element('trace', attributes: {
          'contextRef': '#ctx0',
          'color': strokeColor,
          'width': strokeWidth.toStringAsFixed(1),
        }, nest: coordsBuffer.toString());
      }
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Parses an InkML XML string into a list of [InkStroke]s for rendering.
  static List<InkStroke> parseInkML(String inkmlXml) {
    if (inkmlXml.trim().isEmpty) return [];

    try {
      final document = XmlDocument.parse(inkmlXml);
      final traceElements = document.findAllElements('trace');
      final strokes = <InkStroke>[];

      for (final trace in traceElements) {
        final color = trace.getAttribute('color') ?? '#000000';
        final width = double.tryParse(trace.getAttribute('width') ?? '') ?? 1.0;
        final text = trace.innerText.trim();
        if (text.isEmpty) continue;

        final points = <InkPoint>[];
        final parts = text.split(',');
        for (final part in parts) {
          final tokens = part.trim().split(RegExp(r'\s+'));
          if (tokens.length >= 2) {
            final x = double.tryParse(tokens[0]) ?? 0.0;
            final y = double.tryParse(tokens[1]) ?? 0.0;
            final f = (tokens.length >= 3) ? (double.tryParse(tokens[2]) ?? 0.5) : 0.5;
            points.add(InkPoint(x, y, f));
          }
        }

        if (points.isNotEmpty) {
          strokes.add(InkStroke(
            points: points,
            color: color,
            strokeWidth: width,
          ));
        }
      }

      return strokes;
    } catch (e) {
      return [];
    }
  }

  /// Converts an InkML XML string back into Excalidraw freedraw element objects.
  static List<Map<String, dynamic>> inkMLToExcalidraw(String inkmlXml) {
    final strokes = parseInkML(inkmlXml);
    final elements = <Map<String, dynamic>>[];

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;

      for (final pt in stroke.points) {
        minX = min(minX, pt.x);
        minY = min(minY, pt.y);
        maxX = max(maxX, pt.x);
        maxY = max(maxY, pt.y);
      }

      final width = max(1.0, maxX - minX);
      final height = max(1.0, maxY - minY);

      final relativePoints = <List<double>>[];
      final pressures = <double>[];

      for (final pt in stroke.points) {
        relativePoints.add([pt.x - minX, pt.y - minY]);
        pressures.add(pt.pressure);
      }

      final element = {
        'id': 'ink_${_uuid.v4().substring(0, 8)}',
        'type': 'freedraw',
        'x': minX,
        'y': minY,
        'width': width,
        'height': height,
        'angle': 0,
        'strokeColor': stroke.color,
        'backgroundColor': 'transparent',
        'fillStyle': 'solid',
        'strokeWidth': stroke.strokeWidth,
        'strokeStyle': 'solid',
        'roughness': 0,
        'opacity': 100,
        'groupIds': [],
        'frameId': null,
        'roundness': null,
        'seed': 12345,
        'version': 1,
        'versionNonce': 1,
        'isDeleted': false,
        'points': relativePoints,
        'pressures': pressures,
        'simulatePressure': false,
      };

      elements.add(element);
    }

    return elements;
  }
}
