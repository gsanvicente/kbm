import '../../core/models/cardholder_session.dart';

abstract class CardholderAuthRepository {
  /// Lanza [AuthException] (mensaje genérico) si el email/contraseña no
  /// coinciden, o si el Tarjetahabiente está inactivo — Capa 1 de
  /// enforcement, mismo criterio que
  /// docs/business/desactivacion-de-tarjetahabientes.md ya documentó para
  /// cuando se construyera este portal.
  Future<CardholderSession> login({required String email, required String password});
}
