import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart' hide StrokePoint;
import '../../domains/consultation/models/stroke.dart';

/// Utilities for rendering Lipi canonical [Stroke]s using [perfect_freehand]
/// and performing deterministic hit-testing for eraser operations.
class NativeStrokeRenderer {
  /// Converts a canonical Lipi [Stroke] into a filled Flutter [Path].
  ///
  /// For single-point strokes (e.g. dots on 'i's or decimal points),
  /// generates a circular dot path.
  /// For multi-point strokes, calculates smooth polygonal outline vectors
  /// using [getStroke] and constructs a closed path.
  static Path getStrokePath(Stroke stroke) {
    if (stroke.points.isEmpty) return Path();

    if (stroke.points.length == 1) {
      final pt = stroke.points.first;
      final pressure = (pt.pressure <= 0.0 || pt.pressure > 1.0) ? 0.5 : pt.pressure;
      final radius = (stroke.strokeWidth * pressure).clamp(0.8, stroke.strokeWidth);
      return Path()..addOval(Rect.fromCircle(center: Offset(pt.x, pt.y), radius: radius));
    }

    final pointVectors = stroke.points
        .map((p) => PointVector(p.x, p.y, p.pressure.clamp(0.05, 1.0)))
        .toList();

    // perfect_freehand size parameter represents stroke diameter
    final outline = getStroke(
      pointVectors,
      options: StrokeOptions(
        size: stroke.strokeWidth * 2.0,
        thinning: 0.5,
        smoothing: 0.45,
        streamline: 0.4,
        simulatePressure: false,
        start: StrokeEndOptions.start(taperEnabled: true, cap: true),
        end: StrokeEndOptions.end(taperEnabled: true, cap: true),
      ),
    );

    if (outline.isEmpty) {
      // Fallback if outline generation yielded nothing
      final fallbackPath = Path();
      fallbackPath.moveTo(stroke.points.first.x, stroke.points.first.y);
      for (int i = 1; i < stroke.points.length; i++) {
        fallbackPath.lineTo(stroke.points[i].x, stroke.points[i].y);
      }
      return fallbackPath;
    }

    final path = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (int i = 1; i < outline.length; i++) {
      path.lineTo(outline[i].dx, outline[i].dy);
    }
    path.close();
    return path;
  }

  /// Parses a hex color string (e.g. '#1A365D', '#000000', '1A365D') into a Flutter [Color].
  static Color parseHexColor(String hex, [Color fallback = const Color(0xFF1A365D)]) {
    try {
      var clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      final val = int.tryParse(clean, radix: 16);
      return val != null ? Color(val) : fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Calculates the axis-aligned bounding box of a [Stroke] with optional padding.
  static Rect computeBoundingBox(Stroke stroke, [double padding = 0.0]) {
    if (stroke.points.isEmpty) return Rect.zero;
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in stroke.points) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  /// Tests whether any portion of [stroke] falls within [radius] of [center].
  ///
  /// Employs a two-tier check:
  /// 1. Fast rejection via stroke axis-aligned bounding box.
  /// 2. Point-to-line-segment distance calculation for all segments.
  static bool strokeIntersectsCircle(Stroke stroke, Offset center, double radius) {
    if (stroke.points.isEmpty) return false;

    final totalPad = stroke.strokeWidth + radius;
    final bbox = computeBoundingBox(stroke, totalPad);
    if (!bbox.contains(center)) {
      return false;
    }

    final radiusSq = radius * radius;

    // Single-point dot check
    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      final dx = p.x - center.dx;
      final dy = p.y - center.dy;
      return (dx * dx + dy * dy) <= radiusSq;
    }

    // Line segments check
    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p1 = stroke.points[i];
      final p2 = stroke.points[i + 1];
      final distSq = _distToSegmentSquared(
        center,
        Offset(p1.x, p1.y),
        Offset(p2.x, p2.y),
      );
      if (distSq <= radiusSq) {
        return true;
      }
    }

    return false;
  }

  /// Square of Euclidean distance from point [p] to segment [v]-[w].
  static double _distToSegmentSquared(Offset p, Offset v, Offset w) {
    final l2 = (v.dx - w.dx) * (v.dx - w.dx) + (v.dy - w.dy) * (v.dy - w.dy);
    if (l2 == 0.0) {
      final dx = p.dx - v.dx;
      final dy = p.dy - v.dy;
      return dx * dx + dy * dy;
    }
    final t = ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2;
    final clampedT = t.clamp(0.0, 1.0);
    final projX = v.dx + clampedT * (w.dx - v.dx);
    final projY = v.dy + clampedT * (w.dy - v.dy);
    final dx = p.dx - projX;
    final dy = p.dy - projY;
    return dx * dx + dy * dy;
  }
}
