import '../../core/models/payment_card.dart';

/// Lo mínimo que se le muestra al Tarjetahabiente para confirmar un
/// destino antes de enviar — nunca el objeto `Cardholder` completo, solo
/// lo que la confirmación necesita. Ver
/// docs/feature/transferencia-c2c-tarjetahabiente/README.md, "Flujo
/// principal".
class ResolvedTransferDestination {
  final PaymentCard card;
  final String cardholderName;
  const ResolvedTransferDestination({required this.card, required this.cardholderName});
}

abstract class TransferRepository {
  /// Resuelve a qué tarjeta pertenece [pan] (número completo) dentro del
  /// mismo Cliente que [originCardId], y que pertenezca a **otro**
  /// Tarjetahabiente distinto del dueño de la tarjeta origen — ver "Por
  /// qué es una entidad de negocio distinta" en el README de la feature.
  /// `null` es la respuesta genérica para cualquier motivo de no-match
  /// (formato inválido, no pertenece al Cliente, es tu propia tarjeta) —
  /// nunca se distingue el motivo, ver "Seguridad" en el mismo doc.
  ///
  /// Lanza [TooManyFailedAttemptsException] al superar el límite de
  /// intentos fallidos de la sesión de [cardholderId].
  Future<ResolvedTransferDestination?> resolveDestination({
    required String cardholderId,
    required String originCardId,
    required String pan,
  });

  /// Ejecuta la transferencia ya confirmada — débito inmediato en origen,
  /// crédito inmediato en destino, sin pasar por `approval_rules` ni
  /// tocar ninguna Cuenta Concentradora. Lanza
  /// [InsufficientFundsException] si el saldo de origen no alcanza, sin
  /// tocar ningún saldo.
  Future<void> transfer({
    required String originCardId,
    required String destinationCardId,
    required double amount,
  });

  /// Reinicia el contador de intentos fallidos de [cardholderId] — se
  /// llama al iniciar sesión, nunca dentro de la misma sesión.
  void resetFailedAttempts(String cardholderId);
}
