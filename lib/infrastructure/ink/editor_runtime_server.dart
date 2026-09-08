import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Embedded HTTP loopback server that serves offline Excalidraw editor assets
/// from Flutter's rootBundle to the WebView over http://127.0.0.1:`<ephemeral-port>`.
///
/// Follows ADR-0008 Section 12: Resolves Android WebView CORS restrictions
/// on ES modules and stylesheets without requiring an external internet connection.
class EditorRuntimeServer {
  static final EditorRuntimeServer instance = EditorRuntimeServer._();
  EditorRuntimeServer._();

  HttpServer? _server;
  int? _port;
  Uint8List? _customTemplateBytes;
  String? _customTemplateMime;

  int? get port => _port;
  String? get baseUrl => _port != null ? 'http://127.0.0.1:$_port' : null;
  bool get isRunning => _server != null && _port != null;

  void setCustomTemplate(Uint8List? bytes, [String? mime]) {
    _customTemplateBytes = bytes;
    _customTemplateMime = mime ?? 'image/png';
  }

  Future<int> ensureStarted() async {
    if (_server != null && _port != null) {
      return _port!;
    }

    final handler = const Pipeline().addHandler(_handleRequest);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      0, // Bind to random available ephemeral port
    );
    _port = _server!.port;
    debugPrint('[Lipi][EditorRuntimeServer] Started on http://127.0.0.1:$_port');
    return _port!;
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _port = null;
      debugPrint('[Lipi][EditorRuntimeServer] Stopped');
    }
  }

  Future<Response> _handleRequest(Request request) async {
    var path = request.url.path;

    // 1. Dynamic custom template endpoint
    if (path == 'custom_template' && _customTemplateBytes != null) {
      return Response.ok(
        _customTemplateBytes!,
        headers: {
          'Content-Type': _customTemplateMime ?? 'image/png',
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'no-cache',
        },
      );
    }

    // 2. Default to index.html
    if (path.isEmpty || path == '/') {
      path = 'index.html';
    }

    final assetKey = 'assets/web/$path';
    try {
      final byteData = await rootBundle.load(assetKey);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      final mime = _mimeTypeFor(path);

      return Response.ok(
        bytes,
        headers: {
          'Content-Type': mime,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
          'Cache-Control': 'no-cache',
        },
      );
    } catch (e) {
      return Response.notFound('Asset not found: $path');
    }
  }

  String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.html')) return 'text/html; charset=utf-8';
    if (lower.endsWith('.js') || lower.endsWith('.mjs')) return 'application/javascript; charset=utf-8';
    if (lower.endsWith('.css')) return 'text/css; charset=utf-8';
    if (lower.endsWith('.json')) return 'application/json; charset=utf-8';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.woff2')) return 'font/woff2';
    if (lower.endsWith('.woff')) return 'font/woff';
    if (lower.endsWith('.ttf')) return 'font/ttf';
    if (lower.endsWith('.wasm')) return 'application/wasm';
    return 'application/octet-stream';
  }
}
