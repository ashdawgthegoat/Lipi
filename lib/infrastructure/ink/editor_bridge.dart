import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../shared/errors/lipi_error.dart';

typedef OnEditorReady = void Function();
typedef OnEditorInitialized = void Function(bool hasTemplateImage);
typedef OnInkChanged = void Function();
typedef OnTemplateDebug = void Function(String message);

/// Bidirectional bridge between Flutter and Excalidraw editor inside the WebView.
///
/// Follows ADR-0008 Section 13 & 15:
/// Excalidraw-specific structures terminate at this boundary. Flutter exchanges
/// structured Lipi commands rather than raw arbitrary editor state.
class EditorBridge {
  WebViewController? _controller;
  bool _isEditorReady = false;

  OnEditorReady? onReady;
  OnEditorInitialized? onInitialized;
  OnInkChanged? onInkChanged;
  OnTemplateDebug? onTemplateDebug;

  bool get isEditorReady => _isEditorReady;

  void attachController(WebViewController controller) {
    _controller = controller;
  }

  /// Handles incoming JSON messages received over JavaScriptChannel 'LipiChannel'.
  void handleIncomingMessage(String messageJson) {
    try {
      final data = jsonDecode(messageJson) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'READY':
          _isEditorReady = true;
          onReady?.call();
          break;
        case 'INITIALIZED':
          final hasTemplate = data['hasTemplateImage'] as bool? ?? false;
          onInitialized?.call(hasTemplate);
          break;
        case 'INK_CHANGED':
          onInkChanged?.call();
          break;
        case 'TEMPLATE_DEBUG':
          final msg = data['message'] as String? ?? '';
          onTemplateDebug?.call(msg);
          break;
      }
    } catch (e) {
      debugPrint('[Lipi][EditorBridge] Failed to parse message: $e');
    }
  }

  /// Injects prescription metadata, letterhead template, and existing elements into editor.
  Future<void> initPrescription(Map<String, dynamic> payload) async {
    if (_controller == null) {
      throw const EditorError('WebViewController is not attached to EditorBridge');
    }
    final script = 'window.initPrescription(${jsonEncode(payload)});';
    await _controller!.runJavaScript(script);
  }

  /// Retrieves the current freedraw elements from the Excalidraw canvas.
  Future<List<Map<String, dynamic>>> fetchElements() async {
    if (_controller == null) {
      throw const EditorError('WebViewController is not attached to EditorBridge');
    }
    try {
      final result = await _controller!.runJavaScriptReturningResult(
        'window.getPrescriptionElements();',
      );

      String rawJson = result.toString();
      if (rawJson.startsWith('"') && rawJson.endsWith('"')) {
        rawJson = jsonDecode(rawJson) as String;
      }

      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e, st) {
      throw EditorError('Failed to fetch prescription elements from Excalidraw', e, st);
    }
  }

  /// Sets forensic debug mode in the editor.
  Future<void> setDebugMode(String mode) async {
    if (_controller != null) {
      await _controller!.runJavaScript("window.setTemplateDebugMode('$mode');");
    }
  }
}
