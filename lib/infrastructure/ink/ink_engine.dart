import 'dart:convert';
import '../../domains/consultation/models/clinical_document.dart';
import '../../domains/consultation/models/ink_document.dart';
import '../../shared/errors/lipi_error.dart';
import 'editor_bridge.dart';
import 'editor_runtime_server.dart';
import 'inkml_converter.dart';

/// Facade and boundary managing the handwriting editor lifecycle.
///
/// Follows ADR-0008 Section 11 & 13:
/// Clinical document <-> InkEngine <-> Excalidraw Adapter <-> WebView
class InkEngine {
  final EditorRuntimeServer server;
  final EditorBridge bridge;

  ClinicalDocument? _currentDocument;

  InkEngine({
    EditorRuntimeServer? server,
    EditorBridge? bridge,
  })  : server = server ?? EditorRuntimeServer.instance,
        bridge = bridge ?? EditorBridge();

  bool get isEditorReady => bridge.isEditorReady;
  ClinicalDocument? get currentDocument => _currentDocument;

  /// Starts the local loopback server if not already running.
  Future<int> ensureServerRunning() async {
    return await server.ensureStarted();
  }

  /// Binds the given [document] to the editor and dispatches initialization.
  Future<void> loadDocument(ClinicalDocument document) async {
    _currentDocument = document;

    // 1. If document has custom template bytes, prepare server endpoint / base64
    String? templateUrl;
    if (document.templateBytes != null && document.templateBytes!.isNotEmpty) {
      server.setCustomTemplate(document.templateBytes, 'image/png');
      final port = server.port;
      if (port != null) {
        templateUrl = 'http://127.0.0.1:$port/custom_template?v=${DateTime.now().millisecondsSinceEpoch}';
      } else {
        templateUrl = 'data:image/png;base64,${base64Encode(document.templateBytes!)}';
      }
    }

    // 2. Convert canonical ink strokes to Excalidraw elements
    final excalidrawElements = InkMLConverter.inkDocumentToExcalidraw(document.ink);

    // 3. Prepare initialization payload
    final payload = {
      'page': {
        'width': document.page.width,
        'height': document.page.height,
        'unit': document.page.unit,
      },
      'doctor': {
        'name': document.doctorSnapshot?.name ?? '',
        'clinic': document.doctorSnapshot?.clinic ?? '',
        'qualifications': document.doctorSnapshot?.qualifications ?? '',
        'regNumber': document.doctorSnapshot?.regNumber ?? '',
        'templateImage': ?templateUrl,
      },
      'patient': {
        'name': document.patientSnapshot.name,
        'age': document.patientSnapshot.age,
        'gender': document.patientSnapshot.gender,
        'city': document.patientSnapshot.city,
      },
      'consultationId': document.consultationId.value,
      'date': document.createdAt.toIso8601String().split('T').first,
      'elements': excalidrawElements,
    };

    // 4. Dispatch via bridge
    await bridge.initPrescription(payload);
  }

  /// Extracts the latest digital ink from the editor and returns canonical [InkDocument].
  Future<InkDocument> exportCurrentInk() async {
    try {
      final elements = await bridge.fetchElements();
      return InkMLConverter.excalidrawToInkDocument(elements);
    } catch (e, st) {
      if (e is LipiError) rethrow;
      throw EditorError('Failed to extract digital ink from editor', e, st);
    }
  }

  /// Shuts down the engine and local server.
  Future<void> dispose() async {
    await server.stop();
  }
}
