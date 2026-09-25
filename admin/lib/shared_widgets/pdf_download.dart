/// Descargar un PDF ya generado (bytes) — solo funciona compilado para
/// web (usa `dart:html` tras bambalinas); en cualquier otra plataforma
/// lanza `UnsupportedError` con un mensaje claro. Mismo patrón que
/// `csv_download.dart`, que este archivo reemplaza como mecanismo de
/// descarga de "estado de cuenta" (ver
/// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md, punto 6,
/// enmendado a PDF).
library;

export 'pdf_download_stub.dart' if (dart.library.html) 'pdf_download_web.dart';
