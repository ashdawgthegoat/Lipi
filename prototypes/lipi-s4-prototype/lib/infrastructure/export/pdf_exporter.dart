import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../ink/inkml_converter.dart';
import '../storage/lipi_package.dart';

class PdfExporter {
  /// Converts a document coordinate (in editor pixels at 96 DPI)
  /// to its corresponding point on the PDF page (in PDF points, origin bottom-left).
  static PdfPoint documentPointToPdfPoint({
    required double docX,
    required double docY,
    required PageDimensions page,
  }) {
    final pdfWidth = page.width * PdfPageFormat.mm;
    final pdfHeight = page.height * PdfPageFormat.mm;
    final pxWidth = (page.width * 3.78).roundToDouble();
    final pxHeight = (page.height * 3.78).roundToDouble();

    final scaleX = pdfWidth / pxWidth;
    final scaleY = pdfHeight / pxHeight;

    final pdfX = docX * scaleX;
    final pdfY = pdfHeight - (docY * scaleY);
    return PdfPoint(pdfX, pdfY);
  }

  /// Generates a PDF from a .lipi package and saves it to the target file.
  /// Uses the canonical document coordinate system ensuring zero displacement.
  static Future<File> exportToPdf({
    required File targetFile,
    required LipiManifest manifest,
    required String inkmlContent,
    Uint8List? templateImageBytes,
    String? dateString,
  }) async {
    final pdf = pw.Document();

    final widthMm = manifest.page.width;
    final heightMm = manifest.page.height;

    // Standard PDF page size in points (72 points / inch, zero margins)
    final pdfWidth = widthMm * PdfPageFormat.mm;
    final pdfHeight = heightMm * PdfPageFormat.mm;

    final pageFormat = PdfPageFormat(
      pdfWidth,
      pdfHeight,
      marginBottom: 0,
      marginLeft: 0,
      marginRight: 0,
      marginTop: 0,
    );

    // Document Space (Editor px at 96 DPI: 1mm = 3.78 px)
    final pxWidth = (widthMm * 3.78).roundToDouble();
    final pxHeight = (heightMm * 3.78).roundToDouble();

    final scaleX = pdfWidth / pxWidth;
    final scaleY = pdfHeight / pxHeight;

    final strokes = InkMLConverter.parseInkML(inkmlContent);
    final doctor = manifest.doctorSnapshot;
    final patient = manifest.patientSnapshot;
    final effectiveDate = dateString ?? manifest.createdAt.split('T').first;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // ── Layer 0: Template Background (Edge-to-Edge) ───────────────
              if (templateImageBytes != null)
                // Custom Template: Full-page letterhead image
                pw.Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: pw.Image(
                    pw.MemoryImage(templateImageBytes),
                    fit: pw.BoxFit.fill,
                  ),
                )
              else
                // Default Template: Exact vector replica of editor letterhead layout
                pw.Positioned.fill(
                  child: _buildDefaultTemplateLayout(
                    pdfWidth: pdfWidth,
                    pdfHeight: pdfHeight,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    doctor: doctor,
                    patient: patient,
                    consultationId: manifest.consultationId,
                    dateString: effectiveDate,
                  ),
                ),

              // ── Layer 1: Handwritten Digital Ink Vector Layer ─────────────
              pw.Positioned.fill(
                child: pw.CustomPaint(
                  size: PdfPoint(pdfWidth, pdfHeight),
                  painter: (canvas, size) {
                    for (final stroke in strokes) {
                      if (stroke.points.isEmpty) continue;

                      final color = stroke.color.startsWith('#')
                          ? PdfColor.fromHex(stroke.color)
                          : PdfColors.black;
                      canvas.setColor(color);
                      canvas.setLineWidth(stroke.strokeWidth * scaleX);
                      canvas.setLineCap(PdfLineCap.round);
                      canvas.setLineJoin(PdfLineJoin.round);

                      if (stroke.points.length == 1) {
                        // Single point tap/dot
                        final pt = stroke.points.first;
                        final cx = pt.x * scaleX;
                        final cy = size.y - (pt.y * scaleY);
                        final r = (stroke.strokeWidth * scaleX) / 2;
                        canvas.drawEllipse(cx, cy, r, r);
                        canvas.fillPath();
                        continue;
                      }

                      final first = stroke.points.first;
                      // Invert Y because PDF canvas origin is bottom-left
                      final startX = first.x * scaleX;
                      final startY = size.y - (first.y * scaleY);

                      canvas.moveTo(startX, startY);
                      for (int i = 1; i < stroke.points.length; i++) {
                        final pt = stroke.points[i];
                        final curX = pt.x * scaleX;
                        final curY = size.y - (pt.y * scaleY);
                        canvas.lineTo(curX, curY);
                      }
                      canvas.strokePath();
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );

    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    final bytes = await pdf.save();
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile;
  }

  /// Builds the default clinic letterhead layout with exact matching geometry.
  static pw.Widget _buildDefaultTemplateLayout({
    required double pdfWidth,
    required double pdfHeight,
    required double scaleX,
    required double scaleY,
    required DoctorSnapshot? doctor,
    required PatientSnapshot patient,
    required String consultationId,
    required String dateString,
  }) {
    final headerH = 88.0 * scaleY;
    final patientBarH = 34.0 * scaleY;
    final rxH = 34.0 * scaleY;
    final footerH = 40.0 * scaleY;
    final bodyH = pdfHeight - headerH - patientBarH - rxH - footerH;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // 1. Header (88px in editor)
        pw.Container(
          height: headerH,
          width: pdfWidth,
          padding: pw.EdgeInsets.symmetric(
            horizontal: 24.0 * scaleX,
            vertical: 10.0 * scaleY,
          ),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border(
              bottom: pw.BorderSide(
                color: PdfColor.fromHex('#1a365d'),
                width: 2.0 * scaleY,
              ),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                doctor?.clinic.isNotEmpty == true ? doctor!.clinic : 'Medical Clinic',
                style: pw.TextStyle(
                  fontSize: 18.0 * scaleY,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1a365d'),
                ),
              ),
              pw.SizedBox(height: 2.0 * scaleY),
              pw.Text(
                doctor?.name.isNotEmpty == true ? doctor!.name : 'Doctor',
                style: pw.TextStyle(
                  fontSize: 14.0 * scaleY,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#2d3748'),
                ),
              ),
              pw.SizedBox(height: 2.0 * scaleY),
              pw.Text(
                '${doctor?.qualifications ?? ""}${doctor?.regNumber.isNotEmpty == true ? " | Reg: ${doctor!.regNumber}" : ""}',
                style: pw.TextStyle(
                  fontSize: 11.0 * scaleY,
                  color: PdfColor.fromHex('#718096'),
                ),
              ),
            ],
          ),
        ),

        // 2. Patient Info Bar (34px in editor)
        pw.Container(
          height: patientBarH,
          width: pdfWidth,
          padding: pw.EdgeInsets.symmetric(horizontal: 24.0 * scaleX),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#f8fafc'),
            border: pw.Border(
              bottom: pw.BorderSide(
                color: PdfColor.fromHex('#e2e8f0'),
                width: 1.0 * scaleY,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _fieldSpan('Patient:', patient.name, scaleY),
              _fieldSpan('Age/Sex:', '${patient.age} Y / ${patient.gender}', scaleY),
              _fieldSpan('City:', patient.city, scaleY),
              _fieldSpan('Date:', dateString, scaleY),
            ],
          ),
        ),

        // 3. Rx Banner (34px in editor)
        pw.Container(
          height: rxH,
          width: pdfWidth,
          padding: pw.EdgeInsets.symmetric(horizontal: 24.0 * scaleX),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'Rx',
            style: pw.TextStyle(
              fontSize: 20.0 * scaleY,
              fontWeight: pw.FontWeight.bold,
              fontStyle: pw.FontStyle.italic,
              color: PdfColor.fromHex('#1e293b'),
            ),
          ),
        ),

        // 4. Default Template Body with Ruled Lines (Every 32px in editor)
        pw.Container(
          height: bodyH,
          width: pdfWidth,
          child: pw.CustomPaint(
            size: PdfPoint(pdfWidth, bodyH),
            painter: (canvas, size) {
              canvas.setColor(PdfColor.fromHex('#e2e8f0'));
              canvas.setLineWidth(0.8 * scaleY);
              // In editor, lines start at body top (y=0) and repeat every 32px
              // In PDF canvas, size.y is top of body, so y = size.y - 32 * scaleY, etc.
              final step = 32.0 * scaleY;
              for (double yOffset = step; yOffset < size.y; yOffset += step) {
                final pdfY = size.y - yOffset;
                canvas.moveTo(24.0 * scaleX, pdfY);
                canvas.lineTo(size.x - (24.0 * scaleX), pdfY);
              }
              canvas.strokePath();
            },
          ),
        ),

        // 5. Footer (40px in editor)
        pw.Container(
          height: footerH,
          width: pdfWidth,
          padding: pw.EdgeInsets.symmetric(horizontal: 24.0 * scaleX),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border(
              top: pw.BorderSide(
                color: PdfColor.fromHex('#cbd5e1'),
                width: 1.0 * scaleY,
                style: pw.BorderStyle.dashed,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Consultation ID: $consultationId',
                style: pw.TextStyle(
                  fontSize: 10.0 * scaleY,
                  color: PdfColor.fromHex('#94a3b8'),
                ),
              ),
              pw.Text(
                'Doctor Signature: __________________',
                style: pw.TextStyle(
                  fontSize: 10.0 * scaleY,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#64748b'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _fieldSpan(String label, String value, double scale) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label ',
            style: pw.TextStyle(
              fontSize: 10.5 * scale,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#64748b'),
            ),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(
              fontSize: 10.5 * scale,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#0f172a'),
            ),
          ),
        ],
      ),
    );
  }
}
