import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ink_eval/canvas_controller.dart';
import 'package:flutter_ink_eval/ink_painter.dart';
import 'package:flutter_ink_eval/svg_exporter.dart';

/// Main canvas screen with toolbar, zoom/pan, and drawing surface.
class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final _controller = CanvasController();
  final _transformController = TransformationController();

  // Track whether we're in a multi-touch gesture to block drawing.
  int _pointerCount = 0;
  bool _isPanning = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  // -- Coordinate transform helpers --

  /// Converts a screen-space position to canvas-space.
  Offset _toCanvasSpace(Offset screenPos) {
    final matrix = _transformController.value.clone()..invert();
    final result = MatrixUtils.transformPoint(matrix, screenPos);
    return result;
  }

  // -- Pointer handling --

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount > 1) {
      // Multi-touch: cancel any active stroke and let InteractiveViewer pan.
      _controller.endStroke();
      _isPanning = true;
      return;
    }
    if (_isPanning) return;

    final canvasPos = _toCanvasSpace(event.localPosition);
    final pressure = event.pressure;

    if (_controller.toolMode == ToolMode.eraser) {
      _controller.updateStroke(canvasPos, pressure);
    } else {
      _controller.startStroke(canvasPos, pressure);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isPanning || _pointerCount > 1) return;

    final canvasPos = _toCanvasSpace(event.localPosition);
    _controller.updateStroke(canvasPos, event.pressure);
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerCount--;
    if (_pointerCount < 0) _pointerCount = 0;
    if (_pointerCount == 0) {
      _isPanning = false;
    }
    _controller.endStroke();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount--;
    if (_pointerCount < 0) _pointerCount = 0;
    if (_pointerCount == 0) {
      _isPanning = false;
    }
    _controller.endStroke();
  }

  // -- Zoom helpers --

  void _zoomIn() {
    final current = _transformController.value.clone();
    final center = MediaQuery.of(context).size.center(Offset.zero);
    // Scale around center of screen.
    current.translateByDouble(center.dx, center.dy, 0, 1);
    current.scaleByDouble(1.25, 1.25, 1, 1);
    current.translateByDouble(-center.dx, -center.dy, 0, 1);
    _transformController.value = current;
  }

  void _zoomOut() {
    final current = _transformController.value.clone();
    final center = MediaQuery.of(context).size.center(Offset.zero);
    current.translateByDouble(center.dx, center.dy, 0, 1);
    current.scaleByDouble(0.8, 0.8, 1, 1);
    current.translateByDouble(-center.dx, -center.dy, 0, 1);
    _transformController.value = current;
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
  }

  // -- SVG Export --

  Future<void> _exportSvg() async {
    final svg = SvgExporter.export(_controller.strokes);

    if (_controller.strokes.isEmpty) {
      _showSnackBar('Nothing to export');
      return;
    }

    try {
      // Save to Downloads or app-accessible directory.
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/ink_eval_$timestamp.svg');
      await file.writeAsString(svg);
      _showSnackBar('Exported: ${file.path}');
    } catch (e) {
      // Fallback: copy to clipboard.
      await Clipboard.setData(ClipboardData(text: svg));
      _showSnackBar('SVG copied to clipboard (file save failed: $e)');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -- Build --

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Canvas area with pan/zoom.
          Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: InteractiveViewer(
              transformationController: _transformController,
              // panEnabled must be false — otherwise InteractiveViewer consumes
              // single-finger drags for panning, conflicting with drawing.
              // Two-finger pan still works via the scale gesture.
              panEnabled: false,
              scaleEnabled: true,
              minScale: 0.1,
              maxScale: 10.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: SizedBox(
                width: 8000,
                height: 8000,
                child: CustomPaint(
                  painter: InkPainter(
                    strokes: _controller.strokes,
                    activeStroke: _controller.activeStroke,
                  ),
                  size: const Size(8000, 8000),
                ),
              ),
            ),
          ),

          // Toolbar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildToolbar(),
          ),

          // Zoom controls.
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: _buildZoomControls(),
          ),

          // Debug info.
          Positioned(
            left: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: _buildDebugInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final isPen = _controller.toolMode == ToolMode.pen;
    final isEraser = _controller.toolMode == ToolMode.eraser;

    return Container(
      margin: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withAlpha(230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolbarButton(
            icon: Icons.edit,
            label: 'Pen',
            active: isPen,
            onTap: () => _controller.setToolMode(ToolMode.pen),
          ),
          _toolbarButton(
            icon: Icons.auto_fix_high,
            label: 'Eraser',
            active: isEraser,
            onTap: () => _controller.setToolMode(ToolMode.eraser),
          ),
          _divider(),
          _toolbarButton(
            icon: Icons.undo,
            label: 'Undo',
            enabled: _controller.canUndo,
            onTap: _controller.undo,
          ),
          _toolbarButton(
            icon: Icons.redo,
            label: 'Redo',
            enabled: _controller.canRedo,
            onTap: _controller.redo,
          ),
          _divider(),
          _toolbarButton(
            icon: Icons.save_alt,
            label: 'SVG',
            onTap: _exportSvg,
          ),
          _toolbarButton(
            icon: Icons.delete_outline,
            label: 'Clear',
            onTap: _controller.clear,
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    bool active = false,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    final color = !enabled
        ? Colors.white24
        : active
            ? const Color(0xFF00D2FF)
            : Colors.white70;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white12,
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withAlpha(200),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconButton(Icons.add, _zoomIn),
          _iconButton(Icons.remove, _zoomOut),
          _iconButton(Icons.center_focus_strong, _resetView),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white60, size: 20),
      ),
    );
  }

  Widget _buildDebugInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withAlpha(200),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        'Strokes: ${_controller.strokes.length}',
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
