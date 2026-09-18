import '../../core/models/approval_rule.dart';
import '../../core/models/balance_operation.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/operation_type.dart';
import '../../core/models/shared/insufficient_funds_exception.dart';
import '../../core/models/shared/not_found_exception.dart';
import '../ledger/ledger_repository.dart';
import 'balance_operation_repository.dart';

/// In-memory stand-in for balance operations — same approval_rules and
/// seed data as backend/scripts/init-db/001_seed.sql. Owns the
/// approval-evaluation and execution logic (mirrors how
/// FakeCardRepository owns the active-card-limit check): a fake
/// repository is where this iteration's business rules actually live,
/// there's no real backend yet.
class FakeBalanceOperationRepository implements BalanceOperationRepository {
  FakeBalanceOperationRepository({required this.ledgerRepository});

  final LedgerRepository ledgerRepository;

  static const _rules = [
    ApprovalRule(
      clientId: '00000000-0000-0000-0000-000000000002',
      operationType: OperationType.transfer,
      requiresApproval: true,
      minAmount: 500.00,
    ),
    ApprovalRule(
      clientId: '00000000-0000-0000-0000-000000000002',
      operationType: OperationType.load,
      requiresApproval: false,
    ),
    ApprovalRule(
      clientId: '00000000-0000-0000-0000-000000000003',
      operationType: OperationType.transfer,
      requiresApproval: true,
      minAmount: 500.00,
    ),
    ApprovalRule(
      clientId: '00000000-0000-0000-0000-000000000003',
      operationType: OperationType.load,
      requiresApproval: false,
    ),
    // Deliberately no rule for 'debit' anywhere — exercises the
    // fail-safe default below. See docs/business/approval-policy.md.
  ];

  final List<BalanceOperation> _operations = [
    BalanceOperation(
      id: '80000000-0000-0000-0000-000000000001',
      clientId: '00000000-0000-0000-0000-000000000002',
      cardId: '40000000-0000-0000-0000-000000000001',
      type: OperationType.debit,
      amount: 200.00,
      status: OperationStatus.pendingApproval,
      requestedByEmail: 'operador.subA@koons.test',
      createdAt: DateTime(2026, 1, 21, 11, 0),
      updatedAt: DateTime(2026, 1, 21, 11, 0),
    ),
  ];

  bool _needsApproval({required String clientId, required OperationType type, required double amount}) {
    ApprovalRule? rule;
    for (final r in _rules) {
      if (r.clientId == clientId && r.operationType == type) {
        rule = r;
        break;
      }
    }
    // No rule configured => requires approval by default (fail-safe).
    if (rule == null) return true;
    if (!rule.requiresApproval) return false;
    return rule.minAmount == null || amount > rule.minAmount!;
  }

  Future<BalanceOperation> _tryExecute(BalanceOperation op) async {
    try {
      final sourceAccount = await ledgerRepository.getByCard(op.cardId);
      if (sourceAccount == null) throw NotFoundException('La tarjeta ${op.cardId} no tiene cuenta de saldo');

      switch (op.type) {
        case OperationType.load:
          await ledgerRepository.postEntry(
            ledgerAccountId: sourceAccount.id,
            type: LedgerEntryType.credit,
            amount: op.amount,
            description: 'Carga de fondos',
          );
        case OperationType.debit:
          await ledgerRepository.postEntry(
            ledgerAccountId: sourceAccount.id,
            type: LedgerEntryType.debit,
            amount: op.amount,
            description: 'Débito',
          );
        case OperationType.transfer:
          final destinationAccount = await ledgerRepository.getByCard(op.destinationCardId!);
          if (destinationAccount == null) {
            throw NotFoundException('La tarjeta destino ${op.destinationCardId} no tiene cuenta de saldo');
          }
          // Debit the source first — if funds are insufficient this
          // throws before the destination is ever touched, so a failed
          // transfer never partially applies.
          await ledgerRepository.postEntry(
            ledgerAccountId: sourceAccount.id,
            type: LedgerEntryType.debit,
            amount: op.amount,
            description: 'Transferencia enviada',
          );
          await ledgerRepository.postEntry(
            ledgerAccountId: destinationAccount.id,
            type: LedgerEntryType.credit,
            amount: op.amount,
            description: 'Transferencia recibida',
          );
      }
      return op.copyWith(status: OperationStatus.executed, updatedAt: DateTime.now());
    } on InsufficientFundsException catch (e) {
      return op.copyWith(status: OperationStatus.failed, resolutionNotes: e.message, updatedAt: DateTime.now());
    }
  }

  @override
  Future<List<BalanceOperation>> listByClients(List<String> clientIds) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final results = _operations.where((op) => clientIds.contains(op.clientId)).toList();
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<List<BalanceOperation>> listPendingByClients(List<String> clientIds) async {
    final all = await listByClients(clientIds);
    return all.where((op) => op.status == OperationStatus.pendingApproval).toList();
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
    assert(
      (type == OperationType.transfer) == (destinationCardId != null),
      'destinationCardId is required for transfer and only for transfer',
    );
    await Future.delayed(const Duration(milliseconds: 250));

    final now = DateTime.now();
    var op = BalanceOperation(
      id: 'op-${now.microsecondsSinceEpoch}',
      clientId: clientId,
      cardId: cardId,
      type: type,
      amount: amount,
      destinationCardId: destinationCardId,
      status: OperationStatus.pendingApproval,
      requestedByEmail: requestedByEmail,
      createdAt: now,
      updatedAt: now,
    );

    if (!_needsApproval(clientId: clientId, type: type, amount: amount)) {
      op = await _tryExecute(op);
    }
    _operations.add(op);
    return op;
  }

  @override
  Future<BalanceOperation> approve({required String operationId, required String approvedByEmail}) async {
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index == -1) throw NotFoundException('Operación $operationId no encontrada');
    if (_operations[index].status != OperationStatus.pendingApproval) {
      throw StateError('Esta operación ya fue resuelta.');
    }

    final executed = await _tryExecute(_operations[index]);
    final resolved = executed.copyWith(resolvedByEmail: approvedByEmail, updatedAt: DateTime.now());
    _operations[index] = resolved;
    return resolved;
  }

  @override
  Future<BalanceOperation> reject({
    required String operationId,
    required String rejectedByEmail,
    required String reason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index == -1) throw NotFoundException('Operación $operationId no encontrada');
    if (_operations[index].status != OperationStatus.pendingApproval) {
      throw StateError('Esta operación ya fue resuelta.');
    }

    final rejected = _operations[index].copyWith(
      status: OperationStatus.rejected,
      resolvedByEmail: rejectedByEmail,
      resolutionNotes: reason,
      updatedAt: DateTime.now(),
    );
    _operations[index] = rejected;
    return rejected;
  }
}
