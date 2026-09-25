import '../../core/models/account_ledger.dart';
import '../../core/models/beneficiary.dart';
import '../../core/models/spei_deposit.dart';
import '../../core/models/spei_payment.dart';

/// Cuenta CLABE, Beneficiarios de Pago y pagos SPEI del propio
/// Tarjetahabiente — ver docs/adr/0021-conector-spei.md. Todo self-service
/// desde el portal: nunca se opera sobre otro Tarjetahabiente.
abstract class SpeiRepository {
  /// La CLABE de mi Cuenta Individual, o null si todavía no tengo una
  /// asignada.
  Future<String?> getClabe(String cardholderId);

  /// Saldo y movimientos de mi Cuenta Individual — disponible incluso sin
  /// ninguna tarjeta asignada, ver
  /// docs/adr/0020-cuenta-individual-tarjetahabiente.md, punto 3.
  Future<AccountLedger> getAccountLedger(String cardholderId);

  /// Mis depósitos SPEI entrantes, más reciente primero — base del
  /// comprobante propio de un depósito (ADR-0021, punto 9).
  Future<List<SpeiDeposit>> listDeposits(String cardholderId);

  /// Devuelve la CLABE existente, o la provisiona si todavía no tengo una
  /// — pensado como "Activar mi CLABE" en la UI.
  Future<String> ensureClabe(String cardholderId);

  /// Mis Beneficiarios de Pago, alfabético por alias.
  Future<List<Beneficiary>> listBeneficiaries(String cardholderId);

  /// Da de alta un Beneficiario nuevo. Lanza [ValidationException] si
  /// [clabe] no pasa el dígito verificador, su banco no está en el
  /// catálogo, o es mi propia CLABE; lanza [TooManyFailedAttemptsException]
  /// tras varios intentos fallidos seguidos en la misma sesión — mismo
  /// mecanismo que resolver el destino de una transferencia C2C.
  Future<Beneficiary> registerBeneficiary({
    required String cardholderId,
    required String alias,
    required String clabe,
  });

  /// Mi historial de pagos SPEI salientes, más reciente primero.
  Future<List<SpeiPayment>> listPayments(String cardholderId);

  /// Solicita un pago a [beneficiaryId]. Por debajo del umbral configurado
  /// para mi empresa se envía de inmediato (status `executed`); por
  /// encima queda `pendingApproval`. Lanza [ValidationException] si el
  /// Beneficiario sigue en su periodo de enfriamiento y [amount] excede
  /// el tope permitido durante ese periodo.
  Future<SpeiPayment> createPayment({
    required String cardholderId,
    required String beneficiaryId,
    required double amount,
  });
}
