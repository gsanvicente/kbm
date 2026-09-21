import '../../core/models/approval_rule.dart';
import '../../core/models/balance_operation.dart';
import '../../core/models/movement_trend_point.dart';
import '../../core/models/operation_type.dart';

abstract class BalanceOperationRepository {
  /// true solo para el repositorio fake (modo demo, sin backend real) —
  /// ahí [getWeeklyTrend] es un dato sintético determinista. La versión
  /// HTTP es false: contra Postgres es un agregado real de
  /// `balance_operations` ejecutadas. Ver
  /// docs/feature/panel-directivo/README.md, "Volumen de movimientos" —
  /// el Panel directivo usa esto para decidir si mostrar el aviso de
  /// "dato ilustrativo". Cada implementación lo declara explícitamente
  /// (sin default aquí: `implements` en Dart no hereda cuerpos, solo la
  /// forma).
  bool get producesSyntheticWeeklyTrend;

  /// Every operation (any status) across [clientIds], most recent first
  /// — the "Operaciones de saldo" history. See
  /// docs/feature/operacion-saldo-con-aprobacion/README.md.
  Future<List<BalanceOperation>> listByClients(List<String> clientIds);

  /// Volumen semanal ejecutado (Dispersión/Deducción/Transferencia) de
  /// las últimas 12 semanas para [clientIds] — solo para el Panel
  /// directivo (docs/feature/panel-directivo/README.md). Deliberadamente
  /// separado de [listByClients]: es un dato de flujo agregado, no el
  /// historial operativo, y en un backend real sería su propia
  /// consulta/reporte, no una reutilización directa del historial.
  Future<List<MovementTrendPoint>> getWeeklyTrend(List<String> clientIds);

  /// Just the pending ones — the "Aprobaciones" queue.
  Future<List<BalanceOperation>> listPendingByClients(List<String> clientIds);

  /// Evaluates approval_rules for [clientId] + [type] + [amount] and
  /// either executes immediately (writing to the ledger) or leaves the
  /// operation pending_approval. [destinationCardId] is required for
  /// [OperationType.transfer] and must belong to the same [clientId] as
  /// [cardId] — see "Destino de una transferencia" in the feature doc.
  /// A resulting status of `failed` means it ran but hit insufficient
  /// funds; the operation record is still created either way.
  Future<BalanceOperation> request({
    required String clientId,
    required String cardId,
    required OperationType type,
    required double amount,
    String? destinationCardId,
    required String requestedByEmail,
  });

  /// Attempts execution now. Ends as `executed` or `failed` (insufficient
  /// funds) — never leaves it pending. Throws if the operation isn't
  /// pending_approval.
  Future<BalanceOperation> approve({required String operationId, required String approvedByEmail});

  /// Never touches the ledger. Throws if the operation isn't
  /// pending_approval.
  Future<BalanceOperation> reject({
    required String operationId,
    required String rejectedByEmail,
    required String reason,
  });

  /// Las reglas configuradas para [clientId], una por [OperationType]
  /// como máximo. Un [OperationType] ausente de la lista usa el default
  /// fail-safe (requiere aprobación) — ver
  /// docs/business/approval-policy.md.
  Future<List<ApprovalRule>> listApprovalRules(String clientId);

  /// Crea o actualiza (upsert) la regla de [clientId] + [type]. Ver
  /// docs/feature/configuracion-de-cliente/README.md.
  Future<ApprovalRule> setApprovalRule({
    required String clientId,
    required OperationType type,
    required bool requiresApproval,
    double? minAmount,
  });

  /// Quita el override — [clientId] vuelve al default fail-safe para
  /// [type].
  Future<void> deleteApprovalRule({required String clientId, required OperationType type});
}
