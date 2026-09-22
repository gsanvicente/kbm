import '../../core/models/cardholder_session.dart';

abstract class CardholderAuthRepository {
  /// Lanza [AuthException] (mensaje genérico) si el email/contraseña no
  /// coinciden, o si el Tarjetahabiente está inactivo — Capa 1 de
  /// enforcement, mismo criterio que
  /// docs/business/desactivacion-de-tarjetahabientes.md ya documentó para
  /// cuando se construyera este portal.
  Future<CardholderSession> login({required String email, required String password});

  /// Lanza [ActivationFailedException] (mensaje genérico) tanto si el
  /// email no existe, como si el documento no coincide, como si la
  /// cuenta ya fue activada, como si el Tarjetahabiente está inactivo,
  /// como si se agotaron los intentos — ver
  /// docs/adr/0019-cardholder-self-activation.md.
  Future<CardholderSession> activate({
    required String email,
    required String idDocumentNumber,
    required String password,
  });

  /// Limpia cualquier credencial de sesión guardada localmente (el JWT en
  /// `HttpCardholderBackend`; no-op en `FakeCardholderBackend`) — ver
  /// docs/adr/0013-jwt-session-authentication.md.
  void logout();
}
