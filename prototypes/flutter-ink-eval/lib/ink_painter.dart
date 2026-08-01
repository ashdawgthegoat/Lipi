import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_ink_eval/stroke.dart';

/// Custom painter that renders strokes using perfect_freehand outlines.
///
/// Each stroke is drawn as a filled polygon path. This gives high-quality
/// pressure-sensitive rendering with minimal overhead.
class InkPainter extends CustomPainter {
  InkPainter({
    required this.strokes,
    this.activeStroke,
  });

  final List<Stroke> strokes;
  final Stroke? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed strokes.
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw stroke currently being drawn.
    if (activeStroke != null) {
      _drawStroke(canvas, activeStroke!);
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    final outline = stroke.outline;
    if (outline.length < 2) return;

    final path = ui.Path();
    path.moveTo(outline.first.dx, outline.first.dy);
    for (int i = 1; i < outline.length; i++) {
      path.lineTo(outline[i].dx, outline[i].dy);
    }
    path.close();

    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(InkPainter oldDelegate) => true;
}
