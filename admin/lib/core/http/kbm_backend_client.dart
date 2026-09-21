import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente HTTP a mano hacia `backend/cmd/api` — ver
/// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md, punto
/// 7: excepción documentada y temporal a ADR-0006 (los clientes
/// normalmente se generan desde `backend/api/openapi.yaml`, no se
/// escriben a mano). Un solo cliente compartido entre
/// `HttpCardRepository` y `HttpLedgerRepository`, igual que un cliente
/// generado real se compartiría entre los repositorios que lo usan.
class KbmBackendClient {
  KbmBackendClient({this.baseUrl = 'http://127.0.0.1:8080', http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Token de sesión de staff emitido por `POST /v1/staff-sessions` — ver
  /// docs/adr/0013-jwt-session-authentication.md. Vive solo en memoria,
  /// nunca se persiste a disco; se pierde (y exige re-login) en cada
  /// recarga de la app, igual que hoy exige re-login `AuthController`.
  String? accessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Future<dynamic> get(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return _decode(response);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _client.delete(Uri.parse('$baseUrl$path'), headers: _headers);
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

/// Cada repositorio HTTP remapea esto al tipo de excepción específico que
/// su interfaz ya prometía (NotFoundException, InsufficientFundsException,
/// CardLimitExceededException...) — este tipo nunca debería escapar hacia
/// la UI directamente.
class KbmBackendException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;
  const KbmBackendException({required this.statusCode, required this.message, this.body});

  @override
  String toString() => message;
}
