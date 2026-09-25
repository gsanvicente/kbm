import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/currency_format.dart';

/// Un movimiento del estado de cuenta — mismas 5 columnas que el CSV que
/// este PDF reemplaza (ver docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md,
/// punto 6, enmendado a formato PDF a petición del negocio, 2026-09-25).
class PdfStatementRow {
  const PdfStatementRow({
    required this.date,
    required this.isCredit,
    required this.description,
    required this.amount,
    required this.balanceAfter,
  });

  final String date;
  final bool isCredit;
  final String description;
  final double amount;
  final double balanceAfter;
}

final _navy = PdfColor.fromHex('062E56');
final _blue = PdfColor.fromHex('227EA7');
final _green = PdfColor.fromHex('43AB63');
final _borderGrey = PdfColor.fromHex('E3E6EA');
final _surfaceGrey = PdfColor.fromHex('F7F8FA');

String _two(int n) => n.toString().padLeft(2, '0');
String _dateTimeLabel(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

/// La fuente base del PDF (Helvetica, ver
/// docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md, "Limitación
/// conocida") no dibuja bullets/rayas tipográficas — y "•" es
/// justamente el carácter que usa el enmascarado de CLABE en toda la
/// plataforma (`maskClabeForDisplay` en Go, `maskedClabe` en Dart), así
/// que no es un caso raro de texto libre, aparece en cada CLABE
/// enmascarada de este reporte. Se sustituye por un equivalente
/// WinAnsi-seguro antes de dibujar, nunca se cambia el dato real que
/// muestra la UI.
String sanitizeForPdf(String s) => s
    .replaceAll('•', '*')
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('’', "'")
    .replaceAll('‘', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('…', '...');

Future<pw.MemoryImage> _loadLogo() async {
  final logoData = await rootBundle.load('assets/images/kbm_logo.png');
  return pw.MemoryImage(logoData.buffer.asUint8List());
}

/// Encabezado compartido por [buildStatementPdf] y [buildReportPdf] —
/// mismo branding (logo, "KBM · Koons Balance Management", fecha de
/// generación) para que cualquier documento que salga de la plataforma
/// se vea consistente. [subtitle] es lo único que cambia: el tipo de
/// cuenta en un estado de cuenta, o el nombre del reporte en un listado.
pw.Widget _pdfHeader(pw.MemoryImage logo, String title, String subtitle, DateTime generatedAt) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Image(logo, width: 34, height: 34),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'KBM · Koons Balance Management',
                  style: pw.TextStyle(fontSize: 8.5, color: _blue, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(sanitizeForPdf(title), style: pw.TextStyle(fontSize: 17, color: _navy, fontWeight: pw.FontWeight.bold)),
                pw.Text(sanitizeForPdf(subtitle), style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('GENERADO', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
              pw.Text(_dateTimeLabel(generatedAt), style: pw.TextStyle(fontSize: 9, color: _navy)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(height: 2, color: _navy),
      pw.SizedBox(height: 14),
    ],
  );
}

pw.Widget _pdfFooter(pw.Context context) {
  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Divider(color: _borderGrey, height: 12),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Documento generado automáticamente · confidencial, uso exclusivo del destinatario.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _pdfInfoBlock(List<MapEntry<String, String>> infoFields) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _surfaceGrey,
      borderRadius: pw.BorderRadius.circular(6),
      border: pw.Border.all(color: _borderGrey),
    ),
    child: pw.Wrap(
      spacing: 28,
      runSpacing: 8,
      children: [
        for (final field in infoFields)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                field.key.toUpperCase(),
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 1),
              pw.Text(sanitizeForPdf(field.value), style: pw.TextStyle(fontSize: 10.5, color: _navy, fontWeight: pw.FontWeight.bold)),
            ],
          ),
      ],
    ),
  );
}

/// Arma el "Estado de Cuenta" con branding de la plataforma (Koons/KBM,
/// nunca del Cliente — no existe un logo por Cliente en el modelo de
/// datos, ver la decisión en el ADR) — reemplaza el CSV plano que este
/// mismo botón generaba antes. Sigue siendo enteramente client-side, sin
/// endpoint de exportación dedicado (mismo principio del ADR, solo
/// cambia el formato de salida). Código duplicado a propósito en
/// `cardholder/` — ver docs/adr/0002-*, "sin código de runtime
/// compartido entre apps".
///
/// [infoFields] son los datos de identificación del reporte (titular,
/// Cliente, CLABE/cuenta, quién lo generó...) — el negocio pidió
/// explícitamente que el PDF deje claro "de qué se trata" sin tener que
/// abrir la app.
Future<Uint8List> buildStatementPdf({
  required String accountTitle,
  required List<MapEntry<String, String>> infoFields,
  required double balance,
  required String currency,
  required String periodLabel,
  required List<PdfStatementRow> rows,
}) async {
  final doc = pw.Document();
  final logo = await _loadLogo();
  final generatedAt = DateTime.now();

  String money(double v) => formatCurrency(v, currency);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      header: (context) => _pdfHeader(logo, 'Estado de Cuenta', accountTitle, generatedAt),
      footer: _pdfFooter,
      build: (context) => [
        _pdfInfoBlock(infoFields),
        pw.SizedBox(height: 18),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SALDO ACTUAL', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.Text(money(balance), style: pw.TextStyle(fontSize: 21, color: _navy, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('PERIODO', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.Text(sanitizeForPdf(periodLabel), style: pw.TextStyle(fontSize: 10.5, color: _navy)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Text('Movimientos', style: pw.TextStyle(fontSize: 12.5, color: _navy, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (rows.isEmpty)
          pw.Text(
            'Sin movimientos en este periodo.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Fecha', 'Tipo', 'Descripción', 'Monto', 'Saldo'],
            data: [
              for (final r in rows) [r.date, r.isCredit ? 'Abono' : 'Cargo', sanitizeForPdf(r.description), money(r.amount), money(r.balanceAfter)],
            ],
            border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _borderGrey, width: 0.5)),
            headerDecoration: pw.BoxDecoration(color: _navy),
            headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerAlignments: const {3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: const {3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            oddRowDecoration: pw.BoxDecoration(color: _surfaceGrey),
            // Verde para Abono, navy para Cargo/Saldo — mismo criterio de
            // color que ya usan las listas de movimientos en Flutter.
            textStyleBuilder: (index, data, rowNum) {
              if (index != 3 || rowNum == 0) return null;
              final row = rows[rowNum - 1];
              return pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: row.isCredit ? _green : _navy,
              );
            },
          ),
      ],
    ),
  );

  return doc.save();
}

/// Arma un PDF genérico de "reporte" (tabla de columnas libres) con el
/// mismo branding que [buildStatementPdf] — usado por las pestañas de
/// "Reportes" (Pagos SPEI, Depósitos SPEI, Beneficiarios), que a
/// diferencia de un estado de cuenta no tienen un saldo/cuenta única,
/// son listados ya filtrados en pantalla. Ver
/// docs/adr/0023-estados-de-cuenta-en-pdf-con-branding.md. [rows] ya
/// vienen formateadas como texto (moneda, fechas, etc.) — este builder
/// no sabe de dominio, solo pinta columnas.
Future<Uint8List> buildReportPdf({
  required String title,
  required List<MapEntry<String, String>> infoFields,
  required List<String> columns,
  required List<List<String>> rows,
  Set<int> rightAlignedColumns = const {},
}) async {
  final doc = pw.Document();
  final logo = await _loadLogo();
  final generatedAt = DateTime.now();
  final alignments = {for (final i in rightAlignedColumns) i: pw.Alignment.centerRight};

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      header: (context) => _pdfHeader(logo, title, '${rows.length} resultado(s)', generatedAt),
      footer: _pdfFooter,
      build: (context) => [
        _pdfInfoBlock(infoFields),
        pw.SizedBox(height: 18),
        if (rows.isEmpty)
          pw.Text(
            'Sin resultados con los filtros activos.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: [for (final c in columns) sanitizeForPdf(c)],
            data: [for (final row in rows) [for (final cell in row) sanitizeForPdf(cell)]],
            border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _borderGrey, width: 0.5)),
            headerDecoration: pw.BoxDecoration(color: _navy),
            headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerAlignments: alignments,
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignments: alignments,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            oddRowDecoration: pw.BoxDecoration(color: _surfaceGrey),
          ),
      ],
    ),
  );

  return doc.save();
}
