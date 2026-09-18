import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente HTTP a mano hacia `backend/cmd/api` — ver
/// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md, punto
/// 7: excepción documentada y temporal a ADR-0006 (los clientes
/// normalmente se generan desde `backend/api/openapi.yaml`, no se
/// escriben a mano). Copia independiente de la de `admin/` — por
/// ADR-0002 estas dos apps no comparten código en tiempo de ejecución,
/// aunque ambas hablen con el mismo backend.
class KbmBackendClient {
  KbmBackendClient({this.baseUrl = 'http://127.0.0.1:8080', http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<dynamic> get(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'));
    return _decode(response);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final hasBody = response.bodyBytes.isNotEmpty;
    final decoded = hasBody ? jsonDecode(response.body) : null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final message = decoded is Map<String, dynamic> ? decoded['message'] as String? : null;
    throw KbmBackendException(
      statusCode: response.statusCode,
      message: message ?? 'Error de red (${response.statusCode}).',
      body: decoded is Map<String, dynamic> ? decoded : null,
    );
  }
}

/// Remapeado hacia el tipo de excepción específico que cada interfaz ya
/// prometía (AuthException, InsufficientFundsException,
/// TooManyFailedAttemptsException...) — este tipo nunca debería escapar
/// hacia la UI directamente.
class KbmBackendException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;
  const KbmBackendException({required this.statusCode, required this.message, this.body});

  @override
  String toString() => message;
}
