import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../app/dependencies.dart';
import '../../domains/consultation/models/clinical_document.dart';
import '../../domains/consultation/models/ink_document.dart';
import '../../domains/consultation/models/stroke.dart';
import '../../domains/consultation/models/stroke_point.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/patient/models/patient.dart';
import '../../infrastructure/documents/autosave_controller.dart';
import '../../infrastructure/documents/save_state.dart';
import '../../infrastructure/export/pdf_exporter.dart';
import '../../infrastructure/ink/inkml_converter.dart';
import '../../shared/ids/ids.dart';

class PrescriptionWorkspaceScreen extends StatefulWidget {
  final LipiDependencies dependencies;
  final DoctorProfile doctorProfile;
  final Patient patient;
  final ConsultationId consultationId;
  final bool isReopen;
  final ClinicalDocument initialDocument;

  const PrescriptionWorkspaceScreen({
    super.key,
    required this.dependencies,
    required this.doctorProfile,
    required this.patient,
    required this.consultationId,
    required this.isReopen,
    required this.initialDocument,
  });

  @override
  State<PrescriptionWorkspaceScreen> createState() => _PrescriptionWorkspaceScreenState();
}

class _PrescriptionWorkspaceScreenState extends State<PrescriptionWorkspaceScreen> {
  late ClinicalDocument _currentDocument;
  late final AutosaveController _autosaveController;

  WebViewController? _webController;
  bool _webReady = false;
  bool _isExporting = false;
  Timer? _inkSyncDebounceTimer;

  // Desktop stylus/mouse fallback stroke points
  final List<List<Offset>> _fallbackStrokes = [];
  final List<Stroke> _desktopStrokes = [];
  int _desktopRepaintVersion = 0;

  @override
  void initState() {
    super.initState();
    _currentDocument = widget.initialDocument;

    _autosaveController = AutosaveController(
      patientId: widget.patient.id,
      consultationId: widget.consultationId,
      writeCoordinator: widget.dependencies.writeCoordinator,
      debounceDuration: const Duration(milliseconds: 800),
    );

    widget.dependencies.themeService.activeThemeNotifier.addListener(_onThemeChanged);

    if (Platform.isAndroid) {
      _initWebView();
    } else {
      // Initialize desktop strokes from existing ink
      _desktopStrokes.addAll(_currentDocument.ink.strokes);
    }
  }

  @override
  void dispose() {
    widget.dependencies.themeService.activeThemeNotifier.removeListener(_onThemeChanged);
    _inkSyncDebounceTimer?.cancel();
    _autosaveController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (_webController != null && _webReady) {
      final themeJson = jsonEncode(widget.dependencies.themeService.activeTheme.toWebThemeJson());
      _webController!.runJavaScript('window.setLipiTheme($themeJson);');
    }
  }

  Future<void> _initWebView() async {
    try {
      final port = await widget.dependencies.editorServer.ensureStarted();
      final localUrl = 'http://127.0.0.1:$port/index.html';

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..addJavaScriptChannel(
          'LipiChannel',
          onMessageReceived: (JavaScriptMessage message) {
            _handleWebMessage(message.message);
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              Future.delayed(const Duration(milliseconds: 400), () {
                if (!_webReady && mounted) {
                  _injectInitialData();
                }
              });
            },
          ),
        );

      await controller.loadRequest(Uri.parse(localUrl));
      if (mounted) {
        setState(() {
          _webController = controller;
        });
      }
    } catch (e) {
      debugPrint('[Lipi][Prescription] Error initializing WebView: $e');
    }
  }

  void _handleWebMessage(String jsonString) {
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'READY') {
        if (!_webReady) {
          _webReady = true;
          _injectInitialData();
        }
      } else if (type == 'INK_CHANGED') {
        _inkSyncDebounceTimer?.cancel();
        _inkSyncDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
          _syncInkFromWebView();
        });
      }
    } catch (e) {
      debugPrint('[Lipi][Prescription] Error parsing web message: $e');
    }
  }

  Future<void> _injectInitialData() async {
    if (_webController == null) return;

    // Prepare template image if present
    String? effectiveTemplateUrl;
    if (_currentDocument.templateBytes != null) {
      widget.dependencies.editorServer.setCustomTemplate(
        _currentDocument.templateBytes!,
        'image/png',
      );
      final port = widget.dependencies.editorServer.port;
      if (port != null) {
        effectiveTemplateUrl = 'http://127.0.0.1:$port/custom_template?v=${DateTime.now().millisecondsSinceEpoch}';
      }
    }

    final excalidrawElements = InkMLConverter.inkDocumentToExcalidraw(_currentDocument.ink);

    final initPayload = {
      'page': {
        'width': _currentDocument.page.width,
        'height': _currentDocument.page.height,
        'unit': _currentDocument.page.unit,
      },
      'doctor': {
        'name': _currentDocument.doctorSnapshot?.name ?? widget.doctorProfile.name,
        'clinic': _currentDocument.doctorSnapshot?.clinic ?? widget.doctorProfile.clinicName,
        'qualifications': _currentDocument.doctorSnapshot?.qualifications ?? widget.doctorProfile.qualifications,
        'regNumber': _currentDocument.doctorSnapshot?.regNumber ?? widget.doctorProfile.regNumber,
        'templateImage': ?effectiveTemplateUrl,
      },
      'patient': {
        'name': _currentDocument.patientSnapshot.name,
        'age': _currentDocument.patientSnapshot.age,
        'gender': _currentDocument.patientSnapshot.gender,
        'city': _currentDocument.patientSnapshot.city,
      },
      'consultationId': widget.consultationId.value,
      'elements': excalidrawElements,
      'theme': widget.dependencies.themeService.activeTheme.toWebThemeJson(),
    };

    final script = 'window.initPrescription(${jsonEncode(initPayload)});';
    await _webController!.runJavaScript(script);
  }

  Future<void> _syncInkFromWebView() async {
    if (_webController == null) return;

    try {
      final result = await _webController!.runJavaScriptReturningResult(
        'window.getPrescriptionElements();',
      );

      String rawJson = result.toString();
      if (rawJson.startsWith('"') && rawJson.endsWith('"')) {
        rawJson = json.decode(rawJson) as String;
      }

      final decoded = json.decode(rawJson);
      if (decoded is List) {
        final elements = decoded.cast<Map<String, dynamic>>();
        final inkDoc = InkMLConverter.excalidrawToInkDocument(elements);
        _currentDocument = _currentDocument.copyWith(ink: inkDoc);
        _autosaveController.notifyDocumentChanged(_currentDocument);
      }
    } catch (e) {
      debugPrint('[Lipi][Prescription] Error syncing ink: $e');
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      // 1. Flush any pending ink sync and autosave
      _inkSyncDebounceTimer?.cancel();
      await _syncInkFromWebView();
      await _autosaveController.saveNow();

      // 2. Generate PDF bytes from canonical clinical document
      final pdfBytes = await PdfExporter.generatePdfBytes(
        document: _currentDocument,
      );

      if (!mounted) return;

      // 3. Open system print / share / preview sheet
      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: 'Prescription_${widget.patient.name}_${widget.consultationId.value.substring(0, 8)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleClose() async {
    _inkSyncDebounceTimer?.cancel();
    await _syncInkFromWebView();
    await _autosaveController.saveNow();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _inkSyncDebounceTimer?.cancel();
          _syncInkFromWebView().then((_) => _autosaveController.saveNow());
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Prescription — ${widget.patient.name} (${widget.patient.age} Y)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            // Reactive Autosave Status Pill
            ValueListenableBuilder<SaveState>(
              valueListenable: _autosaveController.stateNotifier,
              builder: (context, state, _) {
                return _buildSaveStatusPill(state);
              },
            ),
            const SizedBox(width: 8),

            // Deliberate PDF Export
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: _isExporting ? null : _exportPdf,
            ),

            // Done / Save & Exit Action
            TextButton.icon(
              onPressed: _handleClose,
              icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
              label: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Platform.isAndroid
            ? (_webController != null
                ? WebViewWidget(controller: _webController!)
                : const Center(child: CircularProgressIndicator()))
            : _buildDesktopStylusCanvas(),
      ),
    );
  }

  Widget _buildSaveStatusPill(SaveState state) {
    String label = 'Saved';
    Color color = Colors.greenAccent;
    IconData icon = Icons.check;

    if (state.isSaving) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    } else if (state.isDirty) {
      label = 'Unsaved changes';
      color = Colors.amberAccent;
      icon = Icons.edit;
    } else if (state.hasError) {
      label = 'Save error';
      color = Colors.redAccent;
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Interactive stylus/pointer canvas for Desktop development
  Widget _buildDesktopStylusCanvas() {
    final patient = widget.patient;
    final doctor = widget.doctorProfile;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Container(
          width: 680,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Letterhead
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1A365D), width: 2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doctor.clinicName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A365D))),
                        const SizedBox(height: 2),
                        Text(doctor.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
                        Text('${doctor.qualifications} | Reg: ${doctor.regNumber}', style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                      child: const Text('Desktop Stylus Mode', style: TextStyle(fontSize: 11, color: Color(0xFF1A365D), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // Patient Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text('Patient: ${patient.name}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Flexible(child: Text('Age/Sex: ${patient.age} Y / ${patient.gender}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Flexible(child: Text('City: ${patient.city}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Drawing Canvas
              GestureDetector(
                key: const Key('desktop_drawing_canvas'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  setState(() {
                    _desktopRepaintVersion++;
                    _fallbackStrokes.add([details.localPosition]);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _desktopRepaintVersion++;
                    if (_fallbackStrokes.isNotEmpty) {
                      _fallbackStrokes.last.add(details.localPosition);
                    }
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _desktopRepaintVersion++;
                  });
                  _commitDesktopStrokes();
                },
                child: SizedBox(
                  width: 680,
                  height: 750,
                  child: CustomPaint(
                    size: const Size(680, 750),
                    painter: _DesktopInkPainter(
                      historicalStrokes: _desktopStrokes,
                      liveStrokes: _fallbackStrokes,
                      repaintVersion: _desktopRepaintVersion,
                    ),
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text('Consultation ID: ${widget.consultationId.value.substring(0, 8)}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    const Flexible(child: Text('Doctor Signature: __________________', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _commitDesktopStrokes() {
    final newStrokes = <Stroke>[];

    // Keep existing historical
    newStrokes.addAll(_desktopStrokes);

    // Convert live fallback strokes
    for (final pts in _fallbackStrokes) {
      if (pts.isEmpty) continue;
      final strokePoints = pts
          .map((p) => StrokePoint(x: p.dx, y: p.dy, pressure: 0.5))
          .toList();
      newStrokes.add(Stroke(
        points: strokePoints,
        color: '#1A365D',
        strokeWidth: 2.0,
      ));
    }

    _currentDocument = _currentDocument.copyWith(ink: InkDocument(strokes: newStrokes));
    _autosaveController.notifyDocumentChanged(_currentDocument);
  }
}

class _DesktopInkPainter extends CustomPainter {
  final List<Stroke> historicalStrokes;
  final List<List<Offset>> liveStrokes;
  final int repaintVersion;

  _DesktopInkPainter({
    required this.historicalStrokes,
    required this.liveStrokes,
    required this.repaintVersion,
  });

  @override
  bool? hitTest(Offset position) => true;

  @override
  void paint(Canvas canvas, Size size) {
    // Ruled lines background
    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;

    for (double y = 32.0; y < size.height; y += 32.0) {
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), linePaint);
    }

    // Historical canonical strokes
    final histPaint = Paint()
      ..color = const Color(0xFF1A365D)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in historicalStrokes) {
      if (stroke.points.isEmpty) continue;
      if (stroke.points.length == 1) {
        canvas.drawCircle(
          Offset(stroke.points.first.x, stroke.points.first.y),
          stroke.strokeWidth / 2,
          histPaint..style = PaintingStyle.fill,
        );
        histPaint.style = PaintingStyle.stroke;
        continue;
      }

      final path = Path()..moveTo(stroke.points.first.x, stroke.points.first.y);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].x, stroke.points[i].y);
      }
      canvas.drawPath(path, histPaint);
    }

    // Live drawing strokes
    final livePaint = Paint()
      ..color = const Color(0xFF1A365D)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in liveStrokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.0, livePaint..style = PaintingStyle.fill);
        livePaint.style = PaintingStyle.stroke;
        continue;
      }

      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, livePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DesktopInkPainter oldDelegate) =>
      repaintVersion != oldDelegate.repaintVersion ||
      historicalStrokes.length != oldDelegate.historicalStrokes.length ||
      liveStrokes.isNotEmpty ||
      oldDelegate.liveStrokes.isNotEmpty;
}
