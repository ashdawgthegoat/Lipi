import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import '../../shared/errors/lipi_error.dart';

typedef PdfRasterizer = Future<Uint8List> Function(
  Uint8List pdfBytes, {
  int pageIndex,
  double dpi,
});

/// Result of processing an imported template asset (image or PDF).
class TemplateProcessingResult {
  /// Raster image bytes (PNG/JPEG) used for canvas rendering, PDF export, and .lipi package.
  final Uint8List imageBytes;

  /// Original PDF bytes if the source template was a PDF document.
  final Uint8List? originalPdfBytes;

  /// Normalized extension for storage (e.g. '.png', '.jpg').
  final String extension;

  /// Number of pages detected in the original source file.
  final int pageCount;

  /// True if the source template was a PDF document.
  final bool isPdf;

  /// Warning or advisory note (e.g. for multi-page PDFs in single-page MVP).
  final String? warningMessage;

  const TemplateProcessingResult({
    required this.imageBytes,
    this.originalPdfBytes,
    required this.extension,
    required this.pageCount,
    required this.isPdf,
    this.warningMessage,
  });
}

/// Service that safely processes and normalizes prescription letterhead templates.
///
/// Supports:
/// - PDF documents (.pdf) -> rasterized to crisp 200 DPI PNG with original preserved.
/// - Image documents (.png, .jpg, .jpeg, .webp) -> validated and stored directly.
class TemplateProcessor {
  static const Set<String> supportedExtensions = {
    '.pdf',
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
  };

  /// Pluggable rasterizer for testing or custom renderers.
  static PdfRasterizer? testRasterizer;

  /// Inspects raw PDF bytes and estimates the page count without heavy rendering.
  static int countPdfPages(Uint8List bytes) {
    try {
      final str = latin1.decode(bytes, allowInvalid: true);
      final matches = RegExp(r'/Type\s*/Page\b').allMatches(str);
      return matches.isEmpty ? 1 : matches.length;
    } catch (_) {
      return 1;
    }
  }

  /// Processes a template file or raw bytes into a [TemplateProcessingResult].
  static Future<TemplateProcessingResult> process({
    File? file,
    Uint8List? bytes,
    String? filename,
  }) async {
    Uint8List fileBytes;
    String ext;

    if (file != null) {
      if (!await file.exists()) {
        throw const ValidationError('Selected template file does not exist.');
      }
      fileBytes = await file.readAsBytes();
      ext = p.extension(file.path).toLowerCase();
    } else if (bytes != null && bytes.isNotEmpty) {
      fileBytes = bytes;
      ext = filename != null ? p.extension(filename).toLowerCase() : '.png';
      if (ext.isEmpty) ext = '.png';
    } else {
      throw const ValidationError('No template data provided.');
    }

    if (fileBytes.isEmpty) {
      throw const ValidationError('Template file is empty (0 bytes).');
    }

    if (!supportedExtensions.contains(ext)) {
      throw ValidationError(
        'Unsupported template file extension "$ext". Supported formats: PDF, PNG, JPG, WEBP.',
      );
    }

    if (ext == '.pdf') {
      final pageCount = countPdfPages(fileBytes);
      String? warning;
      if (pageCount > 1) {
        warning =
            'Multi-page PDF detected ($pageCount pages). Lipi MVP uses Page 1 as the primary prescription letterhead.';
      }

      Uint8List pngBytes;
      if (testRasterizer != null) {
        pngBytes = await testRasterizer!(fileBytes, pageIndex: 0, dpi: 200);
      } else {
        try {
          final rasterStream = Printing.raster(fileBytes, pages: [0], dpi: 200);
          final rasters = await rasterStream.toList();
          if (rasters.isEmpty) {
            throw const ValidationError('PDF contains no renderable pages.');
          }
          pngBytes = await rasters.first.toPng();
        } catch (e) {
          if (e is ValidationError) rethrow;
          throw StorageError('Failed to rasterize PDF template: $e', e);
        }
      }

      return TemplateProcessingResult(
        imageBytes: pngBytes,
        originalPdfBytes: fileBytes,
        extension: '.png',
        pageCount: pageCount,
        isPdf: true,
        warningMessage: warning,
      );
    } else {
      // Direct image template
      return TemplateProcessingResult(
        imageBytes: fileBytes,
        extension: ext,
        pageCount: 1,
        isPdf: false,
      );
    }
  }
}
