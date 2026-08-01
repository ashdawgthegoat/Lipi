import 'dart:ui';
import 'package:flutter_ink_eval/stroke.dart';

/// Exports a list of strokes to SVG format.
class SvgExporter {
  /// Generates an SVG string from the given strokes.
  ///
  /// [canvasSize] defines the viewport. Strokes are rendered in their
  /// original canvas coordinates.
  static String export(List<Stroke> strokes, {Size canvasSize = const Size(4000, 4000)}) {
    if (strokes.isEmpty) return _emptySvg(canvasSize);

    // Calculate bounding box of all strokes with padding.
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final stroke in strokes) {
      final bb = stroke.boundingBox;
      if (bb.left < minX) minX = bb.left;
      if (bb.top < minY) minY = bb.top;
      if (bb.right > maxX) maxX = bb.right;
      if (bb.bottom > maxY) maxY = bb.bottom;
    }

    const pad = 40.0;
    minX -= pad;
    minY -= pad;
    maxX += pad;
    maxY += pad;

    final width = maxX - minX;
    final height = maxY - minY;

    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="${minX.toStringAsFixed(1)} ${minY.toStringAsFixed(1)} '
        '${width.toStringAsFixed(1)} ${height.toStringAsFixed(1)}" '
        'width="${width.toStringAsFixed(0)}" height="${height.toStringAsFixed(0)}">');
    buf.writeln('  <rect x="${minX.toStringAsFixed(1)}" y="${minY.toStringAsFixed(1)}" '
        'width="${width.toStringAsFixed(1)}" height="${height.toStringAsFixed(1)}" '
        'fill="#1A1A2E"/>');

    for (final stroke in strokes) {
      final outline = stroke.outline;
      if (outline.length < 2) continue;

      final pathData = _outlineToPath(outline);
      final colorHex = _colorToHex(stroke.color);
      buf.writeln('  <path d="$pathData" fill="$colorHex" stroke="none"/>');
    }

    buf.writeln('</svg>');
    return buf.toString();
  }

  static String _outlineToPath(List<Offset> points) {
    final buf = StringBuffer();
    buf.write('M ${points.first.dx.toStringAsFixed(2)} ${points.first.dy.toStringAsFixed(2)}');
    for (int i = 1; i < points.length; i++) {
      buf.write(' L ${points[i].dx.toStringAsFixed(2)} ${points[i].dy.toStringAsFixed(2)}');
    }
    buf.write(' Z');
    return buf.toString();
  }

  static String _colorToHex(Color c) {
    return '#${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';
  }

  static String _emptySvg(Size size) {
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="${size.width.toInt()}" height="${size.height.toInt()}" '
        'viewBox="0 0 ${size.width.toInt()} ${size.height.toInt()}">\n'
        '  <rect width="100%" height="100%" fill="#1A1A2E"/>\n'
        '</svg>';
  }
}
