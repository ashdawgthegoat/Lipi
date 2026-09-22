import 'dart:io';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../domains/consultation/models/clinical_document.dart';
import '../../domains/consultation/models/doctor_snapshot.dart';
import '../../domains/consultation/models/patient_snapshot.dart';
import '../../domains/consultation/models/stroke.dart';
import '../../infrastructure/themes/theme_model.dart';
import 'native_ink_controller.dart';
import 'stroke_model_ext.dart';

/// Fully native Flutter prescription ink canvas.
///
/// Direct GPU rendering through [CustomPaint], zero WebView / JavaScript overhead,
/// 90 Hz stylus response, robust palm rejection, and continuous zoom/pan.
class NativeInkCanvas extends StatefulWidget {
  final NativeInkController controller;
  final ClinicalDocument document;
  final String dateString;
  final bool isDesktopMode;

  const NativeInkCanvas({
    super.key,
    required this.controller,
    required this.document,
    required this.dateString,
    this.isDesktopMode = false,
  });

  @override
  State<NativeInkCanvas> createState() => _NativeInkCanvasState();
}

class _NativeInkCanvasState extends State<NativeInkCanvas> {
  final TransformationController _transformController = TransformationController();

  // Multi-touch tracking for finger pan and pinch-to-zoom
  final Map<int, Offset> _activeTouches = {};
  Offset? _lastPanPosition;
  double _lastPinchDistance = 0.0;
  Offset _lastPinchCenter = Offset.zero;

  // Track active stylus pointer ID
  int? _activeStylusPointer;
  int? _activeTestTouchPointer;
  bool _wasInvertedStylus = false;

  bool _hasInitializedTransform = false;

  // Zoom bounds
  static const double minZoom = 0.35;
  static const double maxZoom = 4.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerStateChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onControllerStateChanged() {
    if (mounted) setState(() {});
  }

  // --- Document Geometry ---

  double get _docWidth => (widget.document.page.width * 3.78).roundToDouble();
  double get _docHeight => (widget.document.page.height * 3.78).roundToDouble();

  void _initializeTransform(Size viewportSize) {
    if (_hasInitializedTransform || viewportSize.width <= 0 || viewportSize.height <= 0) return;

    final margin = 20.0;
    final availableW = viewportSize.width - margin * 2;
    final availableH = viewportSize.height - margin * 2;

    final scaleX = availableW / _docWidth;
    final scaleY = availableH / _docHeight;
    final fitZoom = min(scaleX, scaleY).clamp(0.4, 1.0);

    final initialScrollX = max(0.0, (viewportSize.width - _docWidth * fitZoom) / 2);
    final initialScrollY = 16.0;

    final matrix = Matrix4.identity()
      ..translateByDouble(initialScrollX, initialScrollY, 0.0, 1.0)
      ..scaleByDouble(fitZoom, fitZoom, 1.0, 1.0);

    _transformController.value = matrix;
    _hasInitializedTransform = true;
  }

  Offset _toDocumentSpace(Offset screenPos) {
    final inverted = Matrix4.tryInvert(_transformController.value) ?? Matrix4.identity();
    return MatrixUtils.transformPoint(inverted, screenPos);
  }

  double get _currentZoom => _transformController.value.getMaxScaleOnAxis();

  // --- Zoom Helpers ---

  void _zoomAround(double scaleFactor, Offset focalPoint) {
    final currentScale = _currentZoom;
    final targetScale = (currentScale * scaleFactor).clamp(minZoom, maxZoom);
    final effectiveFactor = targetScale / currentScale;

    if ((effectiveFactor - 1.0).abs() < 0.001) return;

    final matrix = _transformController.value.clone();
    matrix.translateByDouble(focalPoint.dx, focalPoint.dy, 0.0, 1.0);
    matrix.scaleByDouble(effectiveFactor, effectiveFactor, 1.0, 1.0);
    matrix.translateByDouble(-focalPoint.dx, -focalPoint.dy, 0.0, 1.0);

    setState(() {
      _transformController.value = matrix;
    });
  }

  void _zoomIn() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final center = renderBox != null
        ? renderBox.size.center(Offset.zero)
        : const Offset(400, 400);
    _zoomAround(1.25, center);
  }

  void _zoomOut() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final center = renderBox != null
        ? renderBox.size.center(Offset.zero)
        : const Offset(400, 400);
    _zoomAround(0.8, center);
  }

  void _resetZoom() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _hasInitializedTransform = false;
      _initializeTransform(renderBox.size);
      setState(() {});
    }
  }

  // --- Pointer & Gesture Routing ---

  void _onPointerDown(PointerDownEvent event) {
    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;

    final isMousePen = !Platform.isAndroid &&
        event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton != 0);

    // 1. Stylus writing or Desktop Primary Mouse inking
    if (isStylus || isMousePen) {
      widget.controller.setStylusActive(true);
      _activeStylusPointer = event.pointer;
      _wasInvertedStylus = event.kind == PointerDeviceKind.invertedStylus;

      final docPos = _toDocumentSpace(event.localPosition);

      if (widget.controller.toolMode == InkToolMode.eraser || _wasInvertedStylus) {
        widget.controller.startErasing(docPos);
      } else {
        widget.controller.startStroke(docPos, event.pressure);
      }
      return;
    }

    // 2. Touch Navigation (Finger Pan & Pinch-Zoom)
    if (event.kind == PointerDeviceKind.touch) {
      // PALM REJECTION: ignore all touch contacts while a stylus is on the glass
      if (widget.controller.isStylusActive) {
        return;
      }

      // Special case for widget test harness (tester.drag generates touch events on desktop)
      if (!Platform.isAndroid && widget.isDesktopMode && widget.controller.toolMode == InkToolMode.pen) {
        final docPos = _toDocumentSpace(event.localPosition);
        widget.controller.startStroke(docPos, event.pressure);
        _activeTestTouchPointer = event.pointer;
        return;
      }

      _activeTouches[event.pointer] = event.localPosition;

      if (_activeTouches.length == 1) {
        _lastPanPosition = event.localPosition;
      } else if (_activeTouches.length == 2) {
        final pts = _activeTouches.values.toList();
        _lastPinchDistance = (pts[0] - pts[1]).distance;
        _lastPinchCenter = Offset((pts[0].dx + pts[1].dx) / 2, (pts[0].dy + pts[1].dy) / 2);
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    // 1. Stylus or Primary Mouse inking
    if (event.pointer == _activeStylusPointer) {
      final docPos = _toDocumentSpace(event.localPosition);
      if (widget.controller.toolMode == InkToolMode.eraser || _wasInvertedStylus) {
        widget.controller.updateErasing(docPos);
      } else {
        widget.controller.updateStroke(docPos, event.pressure);
      }
      return;
    }

    // 2. Widget test drag simulation
    if (event.pointer == _activeTestTouchPointer) {
      final docPos = _toDocumentSpace(event.localPosition);
      widget.controller.updateStroke(docPos, event.pressure);
      return;
    }

    // 3. Touch Navigation
    if (event.kind == PointerDeviceKind.touch) {
      if (widget.controller.isStylusActive) return;

      if (_activeTouches.containsKey(event.pointer)) {
        _activeTouches[event.pointer] = event.localPosition;

        if (_activeTouches.length == 1 && _lastPanPosition != null) {
          // Single-finger pan
          final delta = event.localPosition - _lastPanPosition!;
          _lastPanPosition = event.localPosition;

          final matrix = _transformController.value.clone();
          matrix.translateByDouble(delta.dx, delta.dy, 0.0, 1.0);
          setState(() {
            _transformController.value = matrix;
          });
        } else if (_activeTouches.length == 2) {
          // Two-finger pinch zoom + pan
          final pts = _activeTouches.values.toList();
          final newDist = (pts[0] - pts[1]).distance;
          final newCenter = Offset((pts[0].dx + pts[1].dx) / 2, (pts[0].dy + pts[1].dy) / 2);

          if (_lastPinchDistance > 0 && newDist > 0) {
            final scaleFactor = newDist / _lastPinchDistance;
            final panDelta = newCenter - _lastPinchCenter;

            final currentScale = _currentZoom;
            final targetScale = (currentScale * scaleFactor).clamp(minZoom, maxZoom);
            final effectiveFactor = targetScale / currentScale;

            final matrix = _transformController.value.clone();
            matrix.translateByDouble(panDelta.dx, panDelta.dy, 0.0, 1.0);
            matrix.translateByDouble(newCenter.dx, newCenter.dy, 0.0, 1.0);
            matrix.scaleByDouble(effectiveFactor, effectiveFactor, 1.0, 1.0);
            matrix.translateByDouble(-newCenter.dx, -newCenter.dy, 0.0, 1.0);

            _lastPinchDistance = newDist;
            _lastPinchCenter = newCenter;

            setState(() {
              _transformController.value = matrix;
            });
          }
        }
      }
      return;
    }

    // 4. Mouse Hover cursor update for eraser
    if (event.kind == PointerDeviceKind.mouse && widget.controller.toolMode == InkToolMode.eraser) {
      final docPos = _toDocumentSpace(event.localPosition);
      widget.controller.updateEraserCursor(docPos);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _activeStylusPointer) {
      if (widget.controller.toolMode == InkToolMode.eraser || _wasInvertedStylus) {
        widget.controller.endErasing();
      } else {
        widget.controller.endStroke();
      }
      _activeStylusPointer = null;
      _wasInvertedStylus = false;
      widget.controller.setStylusActive(false);
      return;
    }

    if (event.pointer == _activeTestTouchPointer) {
      widget.controller.endStroke();
      _activeTestTouchPointer = null;
      return;
    }

    if (event.kind == PointerDeviceKind.touch) {
      _activeTouches.remove(event.pointer);
      if (_activeTouches.length == 1) {
        _lastPanPosition = _activeTouches.values.first;
      } else {
        _lastPanPosition = null;
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activeStylusPointer) {
      if (widget.controller.toolMode == InkToolMode.eraser || _wasInvertedStylus) {
        widget.controller.endErasing();
      } else {
        widget.controller.endStroke();
      }
      _activeStylusPointer = null;
      _wasInvertedStylus = false;
      widget.controller.setStylusActive(false);
      return;
    }

    if (event.pointer == _activeTestTouchPointer) {
      widget.controller.endStroke();
      _activeTestTouchPointer = null;
      return;
    }

    _activeTouches.remove(event.pointer);
    if (_activeTouches.isEmpty) {
      _lastPanPosition = null;
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final zoomFactor = event.scrollDelta.dy < 0 ? 1.1 : 0.9;
      _zoomAround(zoomFactor, event.localPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LipiExtendedColors>();
    final isRetro = ext?.isRetro ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        _initializeTransform(viewportSize);

        return Stack(
          children: [
            // ── Interactive Viewport ─────────────────────────────────────────
            Positioned.fill(
              child: Listener(
                key: const Key('desktop_drawing_canvas'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                onPointerSignal: _onPointerSignal,
                child: Container(
                  color: ext?.paperBg == null
                      ? theme.scaffoldBackgroundColor
                      : theme.scaffoldBackgroundColor,
                  child: Transform(
                    transform: _transformController.value,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: _docWidth,
                        height: _docHeight,
                        child: _buildPrescriptionSheet(theme, isRetro),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Floating Zoom Widget ─────────────────────────────────────────
            Positioned(
              right: 16,
              top: 16,
              child: _buildFloatingZoomWidget(theme, isRetro),
            ),

            // ── Floating Toolbar ─────────────────────────────────────────────
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildFloatingToolbar(theme, isRetro),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrescriptionSheet(ThemeData theme, bool isRetro) {
    final doc = widget.document;
    final doctor = doc.doctorSnapshot;
    final patient = doc.patientSnapshot;

    return Container(
      width: _docWidth,
      height: _docHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isRetro ? 0 : 4),
        border: Border.all(
          color: isRetro ? const Color(0xFF808080) : const Color(0xFFCBD5E1),
          width: isRetro ? 2 : 1,
        ),
        boxShadow: isRetro
            ? null
            : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Layer 0: Template Background
            Positioned.fill(
              child: doc.templateBytes != null && doc.templateBytes!.isNotEmpty
                  ? Image.memory(
                      doc.templateBytes!,
                      fit: BoxFit.fill,
                    )
                  : _buildDefaultTemplateLayout(doctor, patient),
            ),

            // Layer 1: Digital Ink Surface
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(_docWidth, _docHeight),
                  painter: _NativeInkCustomPainter(
                    controller: widget.controller,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultTemplateLayout(DoctorSnapshot? doctor, PatientSnapshot patient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header (88px)
        Container(
          height: 88,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFF1A365D), width: 2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    doctor?.clinic.isNotEmpty == true ? doctor!.clinic : 'Medical Clinic',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A365D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor?.name.isNotEmpty == true ? doctor!.name : 'Doctor',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${doctor?.qualifications ?? ""}${doctor?.regNumber.isNotEmpty == true ? " • Reg: ${doctor!.regNumber}" : ""}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
                  ),
                ],
              ),
              if (widget.isDesktopMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Desktop Stylus Mode',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1A365D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. Patient Info Bar (34px)
        Container(
          height: 34,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: const Color(0xFFF8FAFC),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _fieldSpan('Patient:', patient.name),
              _fieldSpan('Age/Sex:', '${patient.age} Y / ${patient.gender}'),
              _fieldSpan('City:', patient.city),
              _fieldSpan('Date:', widget.dateString),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // 3. Rx Banner (34px)
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.centerLeft,
          child: const Text(
            'Rx',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: Color(0xFF1E293B),
            ),
          ),
        ),

        // 4. Ruled Lines Body (Every 32px)
        Expanded(
          child: CustomPaint(
            painter: _RuledLinesPainter(),
            size: Size.infinite,
          ),
        ),

        // 5. Footer (40px)
        Container(
          height: 40,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFCBD5E1), style: BorderStyle.solid),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Consultation ID: ${widget.document.consultationId.value}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Doctor Signature: __________________',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fieldSpan(String label, String value) {
    return Flexible(
      child: RichText(
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingZoomWidget(ThemeData theme, bool isRetro) {
    final zoomPct = (_currentZoom * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: isRetro ? const Color(0xFFC0C0C0) : theme.cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(isRetro ? 0 : 8),
        border: Border.all(
          color: isRetro ? Colors.white : Colors.black12,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 20),
            tooltip: 'Zoom In',
            onPressed: _zoomIn,
          ),
          InkWell(
            onTap: _resetZoom,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '$zoomPct%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 20),
            tooltip: 'Zoom Out',
            onPressed: _zoomOut,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingToolbar(ThemeData theme, bool isRetro) {
    final ctrl = widget.controller;
    final isPen = ctrl.toolMode == InkToolMode.pen;
    final isEraser = ctrl.toolMode == InkToolMode.eraser;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isRetro ? const Color(0xFFC0C0C0) : theme.cardColor.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(isRetro ? 0 : 16),
          border: Border.all(
            color: isRetro ? Colors.white : Colors.black12,
            width: isRetro ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            // Pen Tool Button
            ChoiceChip(
              avatar: const Icon(Icons.edit, size: 16),
              label: const Text('Pen'),
              selected: isPen,
              onSelected: (_) => ctrl.setToolMode(InkToolMode.pen),
            ),

            // Eraser Tool Button
            ChoiceChip(
              avatar: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('Eraser'),
              selected: isEraser,
              onSelected: (_) => ctrl.setToolMode(InkToolMode.eraser),
            ),

            // Contextual Size Slider
            SizedBox(
              width: 140,
              child: Row(
                children: [
                  Text(
                    isEraser
                        ? '${ctrl.eraserRadius.round()}px'
                        : '${ctrl.strokeWidth.toStringAsFixed(1)}px',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Expanded(
                    child: Slider(
                      value: isEraser ? ctrl.eraserRadius : ctrl.strokeWidth,
                      min: isEraser ? 6.0 : 1.0,
                      max: isEraser ? 60.0 : 8.0,
                      divisions: isEraser ? 27 : 14,
                      onChanged: (v) {
                        if (isEraser) {
                          ctrl.setEraserRadius(v);
                        } else {
                          ctrl.setStrokeWidth(v);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Pen Color Palette
            if (isPen) ...[
              _colorDot('#1A365D'),
              _colorDot('#000000'),
              _colorDot('#C53030'),
              _colorDot('#2E7D32'),
            ],

            const SizedBox(width: 4),

            // Undo / Redo / Clear
            IconButton(
              icon: const Icon(Icons.undo, size: 18),
              tooltip: 'Undo',
              onPressed: ctrl.canUndo ? ctrl.undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo, size: 18),
              tooltip: 'Redo',
              onPressed: ctrl.canRedo ? ctrl.redo : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Clear All',
              onPressed: ctrl.strokes.isNotEmpty ? ctrl.clear : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(String hex) {
    final col = NativeStrokeRenderer.parseHexColor(hex);
    final isSelected = widget.controller.strokeColor.toLowerCase() == hex.toLowerCase();

    return GestureDetector(
      onTap: () => widget.controller.setStrokeColor(hex),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: col,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? const [BoxShadow(color: Colors.black26, blurRadius: 4)]
              : null,
        ),
      ),
    );
  }
}

/// Custom painter for ruled lines on default prescription template.
class _RuledLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;

    for (double y = 32.0; y < size.height; y += 32.0) {
      canvas.drawLine(Offset(24.0, y), Offset(size.width - 24.0, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// High-performance custom painter listening directly to [NativeInkController].
class _NativeInkCustomPainter extends CustomPainter {
  final NativeInkController controller;

  _NativeInkCustomPainter({
    required this.controller,
  }) : super(repaint: controller.activeStrokeRepaintNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paint all completed canonical strokes using cached Paths
    for (final stroke in controller.strokes) {
      if (stroke.points.isEmpty) continue;
      final path = controller.getPathForStroke(stroke);
      final paint = Paint()
        ..color = NativeStrokeRenderer.parseHexColor(stroke.color)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.drawPath(path, paint);
    }

    // 2. Paint active in-progress stroke
    if (controller.isDrawingStroke && controller.activePoints.isNotEmpty) {
      final activeStroke = Stroke(
        points: controller.activePoints,
        color: controller.strokeColor,
        strokeWidth: controller.strokeWidth,
      );
      final path = NativeStrokeRenderer.getStrokePath(activeStroke);
      final paint = Paint()
        ..color = NativeStrokeRenderer.parseHexColor(activeStroke.color)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.drawPath(path, paint);
    }

    // 3. Paint circular eraser cursor if active
    final eraserPos = controller.eraserCursorNotifier.value;
    if (eraserPos != null && controller.toolMode == InkToolMode.eraser) {
      final cursorPaint = Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(eraserPos, controller.eraserRadius, cursorPaint);

      final ringPaint = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(eraserPos, controller.eraserRadius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NativeInkCustomPainter oldDelegate) => true;
}
