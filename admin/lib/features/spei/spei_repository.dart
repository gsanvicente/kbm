import '../../core/models/account_ledger.dart';
import '../../core/models/beneficiary_directory_entry.dart';
import '../../core/models/spei_deposit.dart';
import '../../core/models/spei_payment.dart';

/// Cola de aprobación de pagos SPEI, reportes de staff (historial de
/// pagos/depósitos/Beneficiarios), y estado de cuenta de una Cuenta
/// Individual — ver docs/adr/0021-conector-spei.md y
/// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md. El alta
/// de Beneficiarios y la solicitud de un pago siguen viviendo 100% en
/// `cardholder/`; todo lo de aquí es lectura (más aprobar/rechazar y
/// revelar una CLABE, las únicas dos acciones de staff sobre este
/// dominio).
abstract class SpeiRepository {
  /// Los pagos SPEI `pending_approval` dentro del alcance de
  /// [clientIds].
  Future<List<SpeiPayment>> listPendingByClients(List<String> clientIds);

  /// Despacha el pago al proveedor SPEI (hoy, el simulador) y lo deja
  /// `executed` o `failed` (fondos insuficientes). Lanza si el pago no
  /// estaba `pending_approval`.
  Future<SpeiPayment> approve({required String paymentId, required String approvedByEmail});

  /// Nunca toca el ledger. Lanza si el pago no estaba `pending_approval`.
  Future<SpeiPayment> reject({
    required String paymentId,
    required String rejectedByEmail,
    required String reason,
  });

  /// Historial completo (cualquier estatus) para el reporte "Pagos
  /// SPEI" — ver docs/feature/reportes-admin/README.md.
  Future<List<SpeiPayment>> listAllByClients(List<String> clientIds);

  /// Reporte de depósitos SPEI cross-cliente.
  Future<List<SpeiDeposit>> listDepositsByClients(List<String> clientIds);

  /// El directorio agregado de Beneficiarios de Pago dentro del alcance
  /// de [clientIds] — ver ADR-0022, puntos 2 y 3.
  Future<List<BeneficiaryDirectoryEntry>> listBeneficiaryDirectory(List<String> clientIds);

  /// Revela la CLABE completa de un Beneficiario del directorio (que la
  /// muestra enmascarada por default) — gate de rol en la UI
  /// (`canManageCardholders`), y queda auditada del lado del backend.
  Future<String> revealClabe(String beneficiaryId);

  /// Saldo y movimientos de la Cuenta Individual de [cardholderId], sin
  /// depender de que tenga ninguna tarjeta asignada — ver ADR-0020 punto
  /// 3 y ADR-0022 punto 6.
  Future<AccountLedger> getAccountLedger(String cardholderId);
}
