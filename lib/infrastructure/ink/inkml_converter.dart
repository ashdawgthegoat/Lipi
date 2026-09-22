import 'package:xml/xml.dart';
import '../../domains/consultation/models/ink_document.dart';
import '../../domains/consultation/models/stroke.dart';
import '../../domains/consultation/models/stroke_point.dart';
import '../../shared/errors/lipi_error.dart';

/// Converts between canonical Lipi [InkDocument] and standard W3C InkML XML.
///
/// Follows ADR-0005:
/// - Canonical digital ink is persisted as W3C InkML inside the durable .lipi package.
/// - Stroke coordinates, pressure (force channel F), stroke color, and stroke width
///   are preserved with exact fidelity.
class InkMLConverter {
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
}
