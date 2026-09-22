import '../../domains/consultation/models/clinical_document.dart';
import '../../domains/consultation/models/ink_document.dart';
import 'native_ink_controller.dart';

/// Primary native digital ink engine for Lipi.
///
/// Owns the [NativeInkController] and provides document-level loading,
/// export, and lifecycle management without external web views or bridges.
class NativeInkEngine {
  final NativeInkController controller;
  ClinicalDocument? _currentDocument;

  NativeInkEngine({NativeInkController? controller})
      : controller = controller ?? NativeInkController();

  ClinicalDocument? get currentDocument => _currentDocument;

  /// Loads [document] into the native ink engine.
  Future<void> loadDocument(ClinicalDocument document) async {
    _currentDocument = document;
    controller.loadDocument(document);
  }

  /// Exports current canonical ink from the native ink engine.
  Future<InkDocument> exportCurrentInk() async {
    final ink = controller.exportCurrentInk();
    if (_currentDocument != null) {
      _currentDocument = _currentDocument!.copyWith(ink: ink);
    }
    return ink;
  }

  /// Disposes resources used by the engine.
  Future<void> dispose() async {
    controller.dispose();
  }
}
