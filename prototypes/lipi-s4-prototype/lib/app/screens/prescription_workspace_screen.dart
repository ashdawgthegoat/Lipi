import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../domains/doctor/doctor_service.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/patient/models/patient_record.dart';
import '../../domains/patient/patient_service.dart';
import '../../infrastructure/export/pdf_exporter.dart';
import '../../infrastructure/ink/inkml_converter.dart';
import '../../infrastructure/storage/lipi_package.dart';
import '../../infrastructure/web/local_asset_server.dart';

class PrescriptionWorkspaceScreen extends StatefulWidget {
  final DoctorService doctorService;
  final PatientService patientService;
  final DoctorProfile doctorProfile;
  final PatientRecord patient;
  final String consultationId;
  final bool isReopen;

  const PrescriptionWorkspaceScreen({
    super.key,
    required this.doctorService,
    required this.patientService,
    required this.doctorProfile,
    required this.patient,
    required this.consultationId,
    required this.isReopen,
  });

  @override
  State<PrescriptionWorkspaceScreen> createState() => _PrescriptionWorkspaceScreenState();
}

class _PrescriptionWorkspaceScreenState extends State<PrescriptionWorkspaceScreen> {
  WebViewController? _webController;
  bool _isSaving = false;
  bool _isExporting = false;
  bool _webReady = false; // guard against double-injection
  LipiPackage? _loadedPackage;
  List<Map<String, dynamic>> _elements = [];
  String _inkmlContent = '';

  // Linux desktop fallback drawing points if webview is unavailable
  final List<List<Offset>> _fallbackStrokes = [];
  List<Offset>? _currentFallbackStroke;

  @override
  void initState() {
    super.initState();
    _initWorkspace();
  }

  Future<void> _initWorkspace() async {
    // 1. If reopening, read existing .lipi file from Vault
    if (widget.isReopen) {
      final file = widget.doctorService.vault.getPrescriptionFile(
        widget.patient.id,
        widget.consultationId,
      );
      if (await file.exists()) {
        try {
          final pkg = await LipiPackage.read(file);
          _loadedPackage = pkg;
          _inkmlContent = pkg.inkmlContent;
          _elements = InkMLConverter.inkMLToExcalidraw(pkg.inkmlContent);

          // Populate fallback strokes for desktop preview
          final strokes = InkMLConverter.parseInkML(pkg.inkmlContent);
          for (final s in strokes) {
            _fallbackStrokes.add(s.points.map((p) => Offset(p.x, p.y)).toList());
          }
        } catch (e) {
          debugPrint('Error opening .lipi package: $e');
        }
      }
    }

    // 2. Setup WebView if on Android / supported platform
    if (!kIsWeb && Platform.isAndroid) {
      _setupWebViewController();
    }
  }

  Future<void> _setupWebViewController() async {
    try {
      final port = await LocalAssetServer.instance.ensureStarted();
      final localUrl = 'http://127.0.0.1:$port/index.html';
      debugPrint('[Lipi][Template] Loading web editor from $localUrl');

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
              debugPrint('[Lipi][Template] WebView onPageFinished: $url');
              // React app uses resilient handshake: sends READY every 100ms once mounted.
              // As fallback in case the channel missed early messages:
              Future.delayed(const Duration(milliseconds: 400), () {
                if (!_webReady && mounted) {
                  debugPrint('[Lipi][Template] Fallback trigger from onPageFinished');
                  _injectInitialData();
                }
              });
            },
            onWebResourceError: (error) {
              debugPrint('[Lipi][Template] WebView resource error: ${error.errorCode} ${error.description} on ${error.url}');
            },
          ),
        );

      await controller.loadRequest(Uri.parse(localUrl));
      if (mounted) {
        setState(() {
          _webController = controller;
        });
      }
    } catch (e, st) {
      debugPrint('[Lipi][Template] Error setting up WebView: $e\n$st');
    }
  }

  void _handleWebMessage(String jsonString) {
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'READY') {
        debugPrint('[Lipi][Template] Received READY handshake from WebView');
        if (!_webReady) {
          _webReady = true;
          _injectInitialData();
        }
      } else if (type == 'INITIALIZED') {
        debugPrint('[Lipi][Template] Step 6-7: WebView confirmed INITIALIZED (hasCustomTemplate=${data['hasCustomTemplate']})');
      } else if (type == 'TEMPLATE_LOADED') {
        debugPrint('[Lipi][Template] Step 8: WebView template image loaded status: ${data['status']}');
      } else if (type == 'TEMPLATE_DEBUG') {
        final msg = data['message'] as String? ?? '[Lipi][TemplateDebug] (empty)';
        debugPrint(msg);
      } else if (type == 'INK_CHANGED') {
        // Debounced or live notice from Excalidraw
      }
    } catch (e) {
      debugPrint('[Lipi][Template] Error parsing web message: $e');
    }
  }

  Future<void> _injectInitialData() async {
    if (_webController == null) return;

    // ── Template Asset Pipeline Diagnostics ─────────────────────────────────
    debugPrint('[Lipi][Template] Step 4: PrescriptionWorkspace obtaining template');
    debugPrint('[Lipi][Template] Configured doctorProfile.templatePath = ${widget.doctorProfile.templatePath}');

    String? effectiveTemplateUrl;

    if (_loadedPackage != null) {
      if (_loadedPackage!.templateImageBytes != null) {
        final rawBytes = _loadedPackage!.templateImageBytes!;
        final rawLen = rawBytes.lengthInBytes;
        debugPrint('[Lipi][Template] Step 4: Restoring historical template from .lipi package ($rawLen bytes)');

        Uint8List bytesToEncode = rawBytes;
        String mimeType = 'image/png';
        final tFile = _loadedPackage!.manifest.doctorSnapshot?.templateImageFile;
        if (tFile != null) {
          mimeType = _detectMimeType(tFile);
        }

        if (rawLen > 800 * 1024) {
          final downscaled = await _downscaleImage(rawBytes);
          if (downscaled != null) {
            bytesToEncode = downscaled;
            mimeType = 'image/png';
          }
        }

        LocalAssetServer.instance.setCustomTemplate(bytesToEncode, mimeType);
        final serverPort = LocalAssetServer.instance.port;
        final templateHttpUrl = serverPort != null
            ? 'http://127.0.0.1:$serverPort/custom_template?v=${DateTime.now().millisecondsSinceEpoch}'
            : null;
        final templateBase64 = 'data:$mimeType;base64,${base64Encode(bytesToEncode)}';
        effectiveTemplateUrl = templateHttpUrl ?? templateBase64;
        debugPrint('[Lipi][Template] Step 5: Historical template URL prepared: ${effectiveTemplateUrl.substring(0, effectiveTemplateUrl.length > 80 ? 80 : effectiveTemplateUrl.length)}...');
      } else {
        debugPrint('[Lipi][Template] Step 4: Reopened .lipi package has no custom template -> Generic default letterhead');
        effectiveTemplateUrl = null;
      }
    } else {
      // New prescription: obtain template from active doctor profile
      final templateFile = await widget.doctorService.getTemplateFile(widget.doctorProfile);

      if (templateFile == null) {
        debugPrint('[Lipi][Template] getTemplateFile() returned null -> Generic/Default template letterhead will be displayed');
      } else {
        debugPrint('[Lipi][Template] Custom template file path = ${templateFile.path}');
        final exists = await templateFile.exists();
        debugPrint('[Lipi][Template] File exists on disk = $exists');

        if (exists) {
          final rawBytes = await templateFile.readAsBytes();
          final rawLen = rawBytes.lengthInBytes;
          debugPrint('[Lipi][Template] Raw template bytes read = $rawLen');

          Uint8List bytesToEncode = rawBytes;
          String mimeType = _detectMimeType(templateFile.path);

          // Safeguard against oversized images (>800KB) causing Android IPC binder transaction overflow
          if (rawLen > 800 * 1024) {
            final downscaled = await _downscaleImage(rawBytes);
            if (downscaled != null) {
              bytesToEncode = downscaled;
              mimeType = 'image/png';
            }
          }

          LocalAssetServer.instance.setCustomTemplate(bytesToEncode, mimeType);
          final serverPort = LocalAssetServer.instance.port;
          final templateHttpUrl = serverPort != null
              ? 'http://127.0.0.1:$serverPort/custom_template?v=${DateTime.now().millisecondsSinceEpoch}'
              : null;
          final templateBase64 = 'data:$mimeType;base64,${base64Encode(bytesToEncode)}';
          effectiveTemplateUrl = templateHttpUrl ?? templateBase64;
          debugPrint('[Lipi][Template] Step 5: Template URL prepared: ${effectiveTemplateUrl.substring(0, effectiveTemplateUrl.length > 80 ? 80 : effectiveTemplateUrl.length)}...');
        }
      }
    }

    final effectivePatientName = _loadedPackage?.manifest.patientSnapshot.name ?? widget.patient.name;
    final effectivePatientAge = _loadedPackage?.manifest.patientSnapshot.age ?? widget.patient.age;
    final effectivePatientGender = _loadedPackage?.manifest.patientSnapshot.gender ?? widget.patient.gender;
    final effectivePatientCity = _loadedPackage?.manifest.patientSnapshot.city ?? widget.patient.city;

    final docSnapshot = _loadedPackage?.manifest.doctorSnapshot;
    final effectiveDoctorName = docSnapshot?.name ?? widget.doctorProfile.name;
    final effectiveClinicName = docSnapshot?.clinic ?? widget.doctorProfile.clinicName;
    final effectiveQualifications = docSnapshot?.qualifications ?? widget.doctorProfile.qualifications;
    final effectiveRegNumber = docSnapshot?.regNumber ?? widget.doctorProfile.regNumber;
    final effectivePageWidth = _loadedPackage?.manifest.page.width ?? widget.doctorProfile.templateWidthMm;
    final effectivePageHeight = _loadedPackage?.manifest.page.height ?? widget.doctorProfile.templateHeightMm;
    final effectivePageUnit = _loadedPackage?.manifest.page.unit ?? widget.doctorProfile.templateUnit;

    final initPayload = {
      'page': {
        'width': effectivePageWidth,
        'height': effectivePageHeight,
        'unit': effectivePageUnit,
      },
      'doctor': {
        'name': effectiveDoctorName,
        'clinic': effectiveClinicName,
        'qualifications': effectiveQualifications,
        'regNumber': effectiveRegNumber,
        if (effectiveTemplateUrl != null) 'templateImage': effectiveTemplateUrl,
      },
      'patient': {
        'name': effectivePatientName,
        'age': effectivePatientAge,
        'gender': effectivePatientGender,
        'city': effectivePatientCity,
      },
      'consultationId': widget.consultationId,
      'elements': _elements,
    };

    final script = 'window.initPrescription(${jsonEncode(initPayload)});';
    debugPrint('[Lipi][Template] Injecting initPrescription: has templateImage=${effectiveTemplateUrl != null}, payload script size=${script.length} chars');
    await _webController!.runJavaScript(script);
    debugPrint('[Lipi][Template] initPrescription script execution dispatched');
  }

  String _detectMimeType(String path) {
    final ext = path.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (ext.endsWith('.gif')) {
      return 'image/gif';
    } else if (ext.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/png';
  }

  Future<Uint8List?> _downscaleImage(Uint8List rawBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: 1600,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final resized = byteData.buffer.asUint8List();
        debugPrint('[Lipi][Template] Downscaled oversized image: ${rawBytes.lengthInBytes} -> ${resized.lengthInBytes} bytes');
        return resized;
      }
    } catch (e) {
      debugPrint('[Lipi][Template] Downscale skipped ($e), using original bytes');
    }
    return null;
  }

  /// Extracts latest handwriting from Excalidraw web view or fallback
  Future<List<Map<String, dynamic>>> _fetchCurrentElements() async {
    if (!_webReady && widget.isReopen && _elements.isNotEmpty) {
      return _elements;
    }

    if (_webController != null) {
      try {
        final result = await _webController!.runJavaScriptReturningResult(
          'window.getPrescriptionElements();',
        );

        String rawJson = result.toString();
        // Android WebView may return quoted JSON string e.g. "\"[{...}]\""
        if (rawJson.startsWith('"') && rawJson.endsWith('"')) {
          rawJson = json.decode(rawJson) as String;
        }

        final decoded = json.decode(rawJson);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint('Error getting elements from Excalidraw: $e');
      }
    }

    // Fallback: convert fallback strokes into Excalidraw format
    if (_fallbackStrokes.isNotEmpty) {
      final fallbackElements = <Map<String, dynamic>>[];
      for (int i = 0; i < _fallbackStrokes.length; i++) {
        final pts = _fallbackStrokes[i];
        if (pts.isEmpty) continue;
        final relPts = pts.map((p) => [p.dx - pts[0].dx, p.dy - pts[0].dy]).toList();
        final pressures = List.filled(pts.length, 0.5);
        fallbackElements.add({
          'id': 'fallback_$i',
          'type': 'freedraw',
          'x': pts[0].dx,
          'y': pts[0].dy,
          'width': 100.0,
          'height': 50.0,
          'strokeColor': '#000000',
          'strokeWidth': 1.5,
          'points': relPts,
          'pressures': pressures,
          'isDeleted': false,
        });
      }
      return fallbackElements;
    }

    return _elements;
  }

  /// Automatically saves the prescription as a .lipi package
  Future<void> _savePrescription() async {
    setState(() => _isSaving = true);
    try {
      final elements = await _fetchCurrentElements();
      _elements = elements;

      // 1. Convert elements to InkML XML subset
      final inkml = InkMLConverter.excalidrawToInkML(elements);
      _inkmlContent = inkml;

      // 2. Prepare .lipi Manifest
      final patientSnapshot = PatientSnapshot(
        name: _loadedPackage?.manifest.patientSnapshot.name ?? widget.patient.name,
        age: _loadedPackage?.manifest.patientSnapshot.age ?? widget.patient.age,
        gender: _loadedPackage?.manifest.patientSnapshot.gender ?? widget.patient.gender,
        city: _loadedPackage?.manifest.patientSnapshot.city ?? widget.patient.city,
      );

      // Handle custom template image persistence in .lipi
      Uint8List? templateBytes = _loadedPackage?.templateImageBytes;
      String? templateImageFile = _loadedPackage?.manifest.doctorSnapshot?.templateImageFile;

      if (templateBytes == null) {
        final templateFile = await widget.doctorService.getTemplateFile(widget.doctorProfile);
        if (templateFile != null && await templateFile.exists()) {
          templateBytes = await templateFile.readAsBytes();
          final ext = templateFile.path.contains('.')
              ? templateFile.path.substring(templateFile.path.lastIndexOf('.'))
              : '.png';
          templateImageFile = 'templates/custom_template$ext';
        }
      }

      final doctorSnapshot = DoctorSnapshot(
        name: widget.doctorProfile.name,
        clinic: widget.doctorProfile.clinicName,
        qualifications: widget.doctorProfile.qualifications,
        regNumber: widget.doctorProfile.regNumber,
        templateImageFile: templateImageFile,
      );

      final manifest = LipiManifest(
        consultationId: widget.consultationId,
        createdAt: _loadedPackage?.manifest.createdAt,
        page: PageDimensions(
          width: _loadedPackage?.manifest.page.width ?? widget.doctorProfile.templateWidthMm,
          height: _loadedPackage?.manifest.page.height ?? widget.doctorProfile.templateHeightMm,
          unit: _loadedPackage?.manifest.page.unit ?? widget.doctorProfile.templateUnit,
        ),
        patientSnapshot: patientSnapshot,
        doctorSnapshot: doctorSnapshot,
      );

      // 3. Write .lipi ZIP package into patient folder
      final targetFile = widget.doctorService.vault.getPrescriptionFile(
        widget.patient.id,
        widget.consultationId,
      );

      await LipiPackage.write(
        targetFile,
        manifest: manifest,
        inkmlContent: inkml,
        templateImageBytes: templateBytes,
      );

      // 4. Update Vault SQLite index
      await widget.patientService.database.upsertPrescription(
        consultationId: widget.consultationId,
        patientId: widget.patient.id,
        filePath: targetFile.path,
        updatedAt: DateTime.now(),
      );

      debugPrint('Prescription automatically saved to ${targetFile.path}');
    } catch (e) {
      debugPrint('Error saving .lipi prescription: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Deliberate PDF Export action
  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      // First ensure current state is persisted
      await _savePrescription();

      final pdfFile = widget.doctorService.vault.getPrescriptionPdfFile(
        widget.patient.id,
        widget.consultationId,
      );

      final patientSnapshot = PatientSnapshot(
        name: _loadedPackage?.manifest.patientSnapshot.name ?? widget.patient.name,
        age: _loadedPackage?.manifest.patientSnapshot.age ?? widget.patient.age,
        gender: _loadedPackage?.manifest.patientSnapshot.gender ?? widget.patient.gender,
        city: _loadedPackage?.manifest.patientSnapshot.city ?? widget.patient.city,
      );

      // Read template image if any (prefer from package if loaded, else doctor service)
      Uint8List? templateBytes = _loadedPackage?.templateImageBytes;
      String? templateImageFile = _loadedPackage?.manifest.doctorSnapshot?.templateImageFile;
      if (templateBytes == null) {
        final templateFile = await widget.doctorService.getTemplateFile(widget.doctorProfile);
        if (templateFile != null && await templateFile.exists()) {
          templateBytes = await templateFile.readAsBytes();
          final ext = templateFile.path.contains('.')
              ? templateFile.path.substring(templateFile.path.lastIndexOf('.'))
              : '.png';
          templateImageFile = 'templates/custom_template$ext';
        }
      }

      final doctorSnapshot = DoctorSnapshot(
        name: widget.doctorProfile.name,
        clinic: widget.doctorProfile.clinicName,
        qualifications: widget.doctorProfile.qualifications,
        regNumber: widget.doctorProfile.regNumber,
        templateImageFile: templateImageFile,
      );

      final manifest = LipiManifest(
        consultationId: widget.consultationId,
        createdAt: _loadedPackage?.manifest.createdAt,
        page: PageDimensions(
          width: _loadedPackage?.manifest.page.width ?? widget.doctorProfile.templateWidthMm,
          height: _loadedPackage?.manifest.page.height ?? widget.doctorProfile.templateHeightMm,
          unit: _loadedPackage?.manifest.page.unit ?? widget.doctorProfile.templateUnit,
        ),
        patientSnapshot: patientSnapshot,
        doctorSnapshot: doctorSnapshot,
      );

      final dateString = manifest.createdAt.split('T').first;

      await PdfExporter.exportToPdf(
        targetFile: pdfFile,
        manifest: manifest,
        inkmlContent: _inkmlContent,
        templateImageBytes: templateBytes,
        dateString: dateString,
      );

      if (!mounted) return;

      // Show preview/print dialog
      final pdfBytes = await pdfFile.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: 'Prescription_${widget.patient.name}_${widget.consultationId.substring(0, 8)}.pdf',
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

  @override
  Widget build(BuildContext context) {
    final patientName = _loadedPackage?.manifest.patientSnapshot.name ?? widget.patient.name;
    final patientAge = _loadedPackage?.manifest.patientSnapshot.age ?? widget.patient.age;
    final patientGender = _loadedPackage?.manifest.patientSnapshot.gender ?? widget.patient.gender;
    final patientCity = _loadedPackage?.manifest.patientSnapshot.city ?? widget.patient.city;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _savePrescription();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE2E8F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 1,
          title: Text(
            'Prescription — $patientName ($patientAge Y)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            // Auto-save status indicator
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),

            // Export PDF Action
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: _isExporting ? null : _exportPdf,
            ),

            // Forensic Template Debug Mode (Pass 1B)
            PopupMenuButton<String>(
              icon: const Icon(Icons.bug_report, color: Colors.amberAccent),
              tooltip: 'Forensic Template Debug',
              onSelected: (mode) {
                debugPrint('[Lipi][TemplateDebug] User switched debug mode to: $mode');
                _webController?.runJavaScript("window.setTemplateDebugMode('$mode');");
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'standard',
                  child: Text('Normal: Full Template + Ink'),
                ),
                PopupMenuItem(
                  value: 'testA',
                  child: Text('Test A: Plain <img> Only (Uploaded Template)'),
                ),
                PopupMenuItem(
                  value: 'testB',
                  child: Text('Test B: Synthetic Test Image (Data URL)'),
                ),
              ],
            ),

            // Done / Close Action (Auto Saves)
            TextButton.icon(
              onPressed: () async {
                await _savePrescription();
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check, color: Colors.greenAccent, size: 20),
              label: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Platform.isAndroid
            ? (_webController != null
                // Use Hybrid Composition to eliminate the SurfaceTexture
                // frame-copy latency (~11ms at 90Hz) that causes visible
                // pen-render lag with TLHC (the default rendering mode).
                ? WebViewWidget.fromPlatformCreationParams(
                    params: AndroidWebViewWidgetCreationParams(
                      controller: _webController!.platform,
                      displayWithHybridComposition: true,
                    ),
                  )
                : const Center(child: CircularProgressIndicator()))
            : _buildDesktopFallbackView(
                patientName: patientName,
                patientAge: patientAge,
                patientGender: patientGender,
                patientCity: patientCity,
              ),
      ),
    );
  }

  /// Fallback finite page view for Linux desktop development
  Widget _buildDesktopFallbackView({
    required String patientName,
    required int patientAge,
    required String patientGender,
    required String patientCity,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Container(
          width: 680,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner about Android Excalidraw target
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFEFF6FF),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Linux Desktop Preview Mode. On Android Tablet, Excalidraw WebView is rendered directly. Draw strokes below with stylus/mouse to test InkML & .lipi pipeline.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          // Simulate doctor writing a handwritten prescription
                          _fallbackStrokes.add([
                            const Offset(50, 50),
                            const Offset(80, 55),
                            const Offset(120, 52),
                            const Offset(180, 58),
                          ]);
                          _fallbackStrokes.add([
                            const Offset(50, 100),
                            const Offset(110, 105),
                            const Offset(160, 98),
                            const Offset(220, 102),
                          ]);
                          _fallbackStrokes.add([
                            const Offset(50, 150),
                            const Offset(90, 152),
                            const Offset(150, 148),
                            const Offset(200, 155),
                          ]);
                        });
                      },
                      icon: const Icon(Icons.draw, size: 16),
                      label: const Text('Add Test Strokes', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              // Doctor Letterhead Header
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.doctorProfile.clinicName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A365D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.doctorProfile.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    Text(
                      '${widget.doctorProfile.qualifications} • Reg: ${widget.doctorProfile.regNumber}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 2, color: Color(0xFF1A365D), height: 2),

              // Patient Info Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Patient: $patientName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Age/Sex: $patientAge Y / $patientGender', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('City: $patientCity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              const Divider(thickness: 1, color: Color(0xFFE2E8F0), height: 1),

              // Rx Sign
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 12, 28, 4),
                child: Text(
                  '℞',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'serif',
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),

              // Interactive Handwriting Canvas (Fallback)
              Container(
                height: 520,
                width: double.infinity,
                color: Colors.white,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _currentFallbackStroke = [details.localPosition];
                      _fallbackStrokes.add(_currentFallbackStroke!);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _currentFallbackStroke?.add(details.localPosition);
                    });
                  },
                  onPanEnd: (_) {
                    _currentFallbackStroke = null;
                  },
                  child: CustomPaint(
                    size: const Size(double.infinity, 520),
                    painter: _FallbackStrokePainter(_fallbackStrokes),
                  ),
                ),
              ),

              // Footer
              const Divider(thickness: 1, color: Color(0xFFE2E8F0), height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Consultation ID: ${widget.consultationId}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const Text(
                      'Doctor Signature: __________________',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackStrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _FallbackStrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FallbackStrokePainter oldDelegate) => true;
}
