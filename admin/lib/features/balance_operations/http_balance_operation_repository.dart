import '../../core/http/kbm_backend_client.dart';
import '../../core/models/balance_operation.dart';
import '../../core/models/movement_trend_point.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/operation_type.dart';
import '../../core/models/shared/client_inactive_exception.dart';
import '../../core/models/shared/not_found_exception.dart';
import 'balance_operation_repository.dart';

/// Implementación real de `BalanceOperationRepository` contra el backend
/// compartido — ver
/// docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md.
/// Reemplaza a `FakeBalanceOperationRepository`; el volumen semanal ahora
/// es un agregado real de `balance_operations` ejecutadas, no un dato
/// sintético — ver docs/feature/panel-directivo/README.md, "Visión futura".
class HttpBalanceOperationRepository implements BalanceOperationRepository {
  HttpBalanceOperationRepository({required this.client});

  final KbmBackendClient client;

  OperationStatus _statusFromJson(String v) {
    switch (v) {
      case 'pending_approval':
        return OperationStatus.pendingApproval;
      case 'approved':
        return OperationStatus.approved;
      case 'executed':
        return OperationStatus.executed;
      case 'rejected':
        return OperationStatus.rejected;
      case 'failed':
        return OperationStatus.failed;
      default:
        return OperationStatus.pendingApproval;
    }
  }

  BalanceOperation _fromJson(Map<String, dynamic> json) => BalanceOperation(
        id: json['id'] as String,
        clientId: json['clientId'] as String,
        cardId: json['cardId'] as String,
        type: OperationType.values.byName(json['type'] as String),
        amount: (json['amount'] as num).toDouble(),
        destinationCardId: json['destinationCardId'] as String?,
        status: _statusFromJson(json['status'] as String),
        requestedByEmail: json['requestedByEmail'] as String,
        resolvedByEmail: json['resolvedByEmail'] as String?,
        resolutionNotes: json['resolutionNotes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  @override
  Future<List<BalanceOperation>> listByClients(List<String> clientIds) async {
    if (clientIds.isEmpty) return [];
    final json = await client.get('/v1/balance-operations?client_ids=${clientIds.join(',')}') as List<dynamic>;
    return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<MovementTrendPoint>> getWeeklyTrend(List<String> clientIds) async {
    if (clientIds.isEmpty) return [];
    final json = await client.get('/v1/balance-operations/weekly-trend?client_ids=${clientIds.join(',')}') as List<dynamic>;
    return json
        .map((e) => e as Map<String, dynamic>)
        .map((e) => MovementTrendPoint(
              weekStart: DateTime.parse(e['weekStart'] as String),
              dispersion: (e['dispersion'] as num).toDouble(),
              deduccion: (e['deduccion'] as num).toDouble(),
              transferencia: (e['transferencia'] as num).toDouble(),
            ))
        .toList();
  }

  @override
  Future<List<BalanceOperation>> listPendingByClients(List<String> clientIds) async {
    if (clientIds.isEmpty) return [];
    final json = await client.get('/v1/balance-operations/pending?client_ids=${clientIds.join(',')}') as List<dynamic>;
    return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<BalanceOperation> request({
    required String clientId,
    required String cardId,
    required OperationType type,
    required double amount,
    String? destinationCardId,
    required String requestedByEmail,
  }) async {
    try {
      final json = await client.post('/v1/balance-operations', {
        'clientId': clientId,
        'cardId': cardId,
        'type': type.name,
        'amount': amount,
        'destinationCardId': destinationCardId,
        'requestedByEmail': requestedByEmail,
      }) as Map<String, dynamic>;
      return _fromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 403) throw const ClientInactiveException();
      rethrow;
    }
  }

  @override
  Future<BalanceOperation> approve({required String operationId, required String approvedByEmail}) async {
    try {
      final json = await client.post('/v1/balance-operations/$operationId/approve', {
        'approvedByEmail': approvedByEmail,
      }) as Map<String, dynamic>;
      return _fromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 403) throw const ClientInactiveException();
      if (e.statusCode == 404) throw NotFoundException('Operación $operationId no encontrada');
      if (e.statusCode == 409) throw StateError('Esta operación ya fue resuelta.');
      rethrow;
    }
  }

  @override
  Future<BalanceOperation> reject({
    required String operationId,
    required String rejectedByEmail,
    required String reason,
  }) async {
    try {
      final json = await client.post('/v1/balance-operations/$operationId/reject', {
        'rejectedByEmail': rejectedByEmail,
        'reason': reason,
      }) as Map<String, dynamic>;
      return _fromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 403) throw const ClientInactiveException();
      if (e.statusCode == 404) throw NotFoundException('Operación $operationId no encontrada');
      if (e.statusCode == 409) throw StateError('Esta operación ya fue resuelta.');
      rethrow;
    }
  }
}
