import '../../core/models/collector_deposit.dart';
import '../../core/models/concentrator_account.dart';
import '../../core/models/concentrator_entry.dart';
import '../../core/models/ledger_entry_type.dart';

/// Cada Cliente tiene su propia Cuenta Concentradora y Cuenta Colectora,
/// independientes entre sí y de las de otros Clientes — ver
/// docs/business/tesoreria-cliente.md.
abstract class TreasuryRepository {
  /// null solo si el Cliente todavía no tiene una — en esta iteración
  /// todo Cliente semilla ya tiene una (ver 001_seed.sql); un Cliente
  /// creado desde el wizard la obtiene de inmediato vía
  /// [createConcentratorAccount], nunca queda en null.
  Future<ConcentratorAccount?> getConcentratorAccount(String clientId);

  /// Se llama una sola vez, al crear un Cliente nuevo — nace con saldo
  /// cero. La Cuenta Colectora no necesita una creación equivalente: es
  /// solo una lista de depósitos por clientId, que empieza vacía sin
  /// ningún paso adicional. Ver docs/business/tesoreria-cliente.md,
  /// "Alcance: una Concentradora y una Colectora por Cliente" — todo
  /// Cliente (incluidas subsidiarias) tiene la suya.
  Future<ConcentratorAccount> createConcentratorAccount(String clientId);

  /// Movimientos de la Concentradora, más reciente primero.
  Future<List<ConcentratorEntry>> listConcentratorEntries(String concentratorAccountId);

  /// Escribe un movimiento y recalcula el saldo cacheado — misma regla
  /// append-only que LedgerRepository.postEntry. Llamado únicamente por
  /// BalanceOperationRepository (Dispersión/Deducción) y por
  /// [reconcileDeposit], nunca directo desde la UI. Lanza
  /// [InsufficientFundsException] si un débito dejaría el saldo negativo.
  Future<ConcentratorEntry> postConcentratorEntry({
    required String concentratorAccountId,
    required LedgerEntryType type,
    required double amount,
    String? description,
  });

  /// Depósitos de la Colectora de un Cliente (cualquier estado), más
  /// reciente primero.
  Future<List<CollectorDeposit>> listCollectorDeposits(String clientId);

  /// Deja el depósito en `pending` — nunca mueve el saldo de la
  /// Concentradora por sí solo. Ver "El flujo de fondeo: dos pasos, no
  /// uno" en docs/business/tesoreria-cliente.md.
  Future<CollectorDeposit> registerDeposit({
    required String clientId,
    required double amount,
    required String reference,
    required String registeredByEmail,
  });

  /// Mueve un depósito `pending` a `reconciled` y acredita la
  /// Concentradora del mismo Cliente por ese monto. Throws si el depósito
  /// ya fue conciliado.
  Future<CollectorDeposit> reconcileDeposit({
    required String depositId,
    required String reconciledByEmail,
  });
}
