import 'dart:typed_data';

// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Descarga [bytes] (un PDF ya generado) como [filename] en el
/// navegador — Blob + un <a download> sintético, sin backend
/// involucrado.
void downloadPdf(String filename, Uint8List bytes) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
