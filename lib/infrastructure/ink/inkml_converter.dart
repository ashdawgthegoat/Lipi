import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import '../../domains/consultation/models/ink_document.dart';
import '../../domains/consultation/models/stroke.dart';
import '../../domains/consultation/models/stroke_point.dart';
import '../../shared/errors/lipi_error.dart';

/// Converts between canonical Lipi [InkDocument], W3C InkML XML, and Excalidraw elements.
///
/// Follows ADR-0005:
/// - Canonical ink is stored as W3C InkML inside the .lipi package.
/// - Excalidraw freedraw strokes are translated strictly through this boundary.
class InkMLConverter {
  static const _uuid = Uuid();

  /// Converts an [InkDocument] to a W3C InkML XML string.
  static String inkDocumentToInkML(InkDocument inkDoc) {
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

      for (final stroke in inkDoc.strokes) {
        if (stroke.points.isEmpty) continue;

        final coordsBuffer = StringBuffer();
        for (int i = 0; i < stroke.points.length; i++) {
          final pt = stroke.points[i];
          if (i > 0) coordsBuffer.write(', ');
          coordsBuffer.write(
            '${pt.x.toStringAsFixed(2)} ${pt.y.toStringAsFixed(2)} ${pt.pressure.toStringAsFixed(2)}',
          );
        }

        builder.element('trace', attributes: {
          'contextRef': '#ctx0',
          'color': stroke.color,
          'width': stroke.strokeWidth.toStringAsFixed(1),
        }, nest: coordsBuffer.toString());
      }
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Parses a W3C InkML XML string into an [InkDocument].
  static InkDocument inkMLToInkDocument(String inkmlXml) {
    if (inkmlXml.trim().isEmpty) return const InkDocument();

    try {
      final document = XmlDocument.parse(inkmlXml);
      final traceElements = document.findAllElements('trace');
      final strokes = <Stroke>[];

      for (final trace in traceElements) {
        final color = trace.getAttribute('color') ?? '#000000';
        final width = double.tryParse(trace.getAttribute('width') ?? '') ?? 1.0;
        final text = trace.innerText.trim();
        if (text.isEmpty) continue;

        final points = <StrokePoint>[];
        final parts = text.split(',');
        for (final part in parts) {
          final tokens = part.trim().split(RegExp(r'\s+'));
          if (tokens.length >= 2) {
            final x = double.tryParse(tokens[0]);
            final y = double.tryParse(tokens[1]);
            final f = tokens.length >= 3 ? double.tryParse(tokens[2]) : 0.5;
            if (x != null && y != null) {
              points.add(StrokePoint(x: x, y: y, pressure: (f ?? 0.5).clamp(0.0, 1.0)));
            }
          }
        }

        if (points.isNotEmpty) {
          strokes.add(Stroke(
            points: points,
            color: color,
            strokeWidth: width > 0 ? width : 1.0,
          ));
        }
      }

      return InkDocument(strokes: strokes);
    } catch (e, st) {
      throw DocumentError('Malformed InkML XML content', e, st);
    }
  }

  /// Converts Excalidraw scene elements to an [InkDocument].
  static InkDocument excalidrawToInkDocument(List<dynamic> elements) {
    final strokes = <Stroke>[];

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

      final points = <StrokePoint>[];
      for (int i = 0; i < pointsList.length; i++) {
        final pt = pointsList[i] as List<dynamic>;
        final double dx = (pt[0] as num).toDouble();
        final double dy = (pt[1] as num).toDouble();
        final double absX = originX + dx;
        final double absY = originY + dy;
        final double p = (i < pressuresList.length && pressuresList[i] is num)
            ? (pressuresList[i] as num).toDouble()
            : 0.5;

        points.add(StrokePoint(x: absX, y: absY, pressure: p.clamp(0.0, 1.0)));
      }

      strokes.add(Stroke(
        points: points,
        color: strokeColor,
        strokeWidth: strokeWidth > 0 ? strokeWidth : 1.0,
      ));
    }

    return InkDocument(strokes: strokes);
  }

  /// Converts an [InkDocument] into Excalidraw freedraw element dictionaries.
  static List<Map<String, dynamic>> inkDocumentToExcalidraw(InkDocument inkDoc) {
    final elements = <Map<String, dynamic>>[];

    for (final stroke in inkDoc.strokes) {
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

      elements.add({
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
      });
    }

    return elements;
  }
}
