import 'dart:math' as math;

import '../../core/models/approval_rule.dart';
import '../../core/models/balance_operation.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/movement_trend_point.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/operation_type.dart';
import '../../core/models/shared/insufficient_funds_exception.dart';
import '../../core/models/shared/not_found_exception.dart';
import '../ledger/ledger_repository.dart';
import '../treasury/treasury_repository.dart';
import 'balance_operation_repository.dart';

/// In-memory stand-in for balance operations — same approval_rules and
/// seed data as backend/scripts/init-db/001_seed.sql. Owns the
/// approval-evaluation and execution logic (mirrors how
/// FakeCardRepository owns the active-card-limit check): a fake
/// repository is where this iteration's business rules actually live,
/// there's no real backend yet.
class FakeBalanceOperationRepository implements BalanceOperationRepository {
  FakeBalanceOperationRepository({required this.ledgerRepository, required this.treasuryRepository});

  final LedgerRepository ledgerRepository;

  /// Backs every Dispersión (debits it) and Deducción (credits it) — see
  /// docs/business/tesoreria-cliente.md. Transferencia never touches it.
  final TreasuryRepository treasuryRepository;

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

  // --- Panel directivo: volumen semanal (dato sintético) ---------------
  //
  // Deliberadamente separado de `_operations` (arriba): nunca se mezcla
  // con el historial real que alimenta "Operaciones de saldo" o
  // "Aprobaciones". Fechas fijas (no `DateTime.now()`) para que sea
  // determinista en tests; la ventana termina cerca del "hoy" de esta
  // demo (2026-09-17) para que el Panel directivo se vea vigente — ver
  // "Visión futura" en docs/feature/panel-directivo/README.md sobre por
  // qué esto desaparece en cuanto haya backend real.
  static final List<DateTime> _trendWeeks = List.generate(
    12,
    (i) => DateTime(2026, 6, 29).add(Duration(days: i * 7)),
  );

  static final Map<String, List<(double, double, double)>> _syntheticWeeklyVolume = _generateSyntheticTrend();

  static Map<String, List<(double, double, double)>> _generateSyntheticTrend() {
    final random = math.Random(20260917); // semilla fija, ver nota arriba
    const clientIds = [
      '00000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000003',
    ];
    return {
      for (final clientId in clientIds)
        clientId: List.generate(_trendWeeks.length, (_) {
          final dispersion = 3000 + random.nextInt(5000);
          final deduccion = 1500 + random.nextInt(3000);
          final transferencia = random.nextBool() ? 500 + random.nextInt(2000) : 0;
          return (dispersion.toDouble(), deduccion.toDouble(), transferencia.toDouble());
        }),
    };
  }

  @override
  Future<List<MovementTrendPoint>> getWeeklyTrend(List<String> clientIds) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.generate(_trendWeeks.length, (i) {
      var dispersion = 0.0, deduccion = 0.0, transferencia = 0.0;
      for (final clientId in clientIds) {
        final volumes = _syntheticWeeklyVolume[clientId];
        if (volumes == null) continue;
        dispersion += volumes[i].$1;
        deduccion += volumes[i].$2;
        transferencia += volumes[i].$3;
      }
      return MovementTrendPoint(
        weekStart: _trendWeeks[i],
        dispersion: dispersion,
        deduccion: deduccion,
        transferencia: transferencia,
      );
    });
  }

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
          final concentrator = await treasuryRepository.getConcentratorAccount(op.clientId);
          if (concentrator == null) {
            throw NotFoundException('El Cliente ${op.clientId} no tiene Cuenta Concentradora');
          }
          // Debit the Concentradora first — if it doesn't have enough,
          // this throws before the card is ever touched, same
          // never-leave-it-half-done principle as Transferencia below.
          await treasuryRepository.postConcentratorEntry(
            concentratorAccountId: concentrator.id,
            type: LedgerEntryType.debit,
            amount: op.amount,
            description: 'Dispersión a tarjeta',
          );
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
          final concentrator = await treasuryRepository.getConcentratorAccount(op.clientId);
          if (concentrator == null) {
            throw NotFoundException('El Cliente ${op.clientId} no tiene Cuenta Concentradora');
          }
          // Crediting the Concentradora never fails for insufficient
          // funds (only debits can), so this is safe to do after the
          // card's own debit already succeeded.
          await treasuryRepository.postConcentratorEntry(
            concentratorAccountId: concentrator.id,
            type: LedgerEntryType.credit,
            amount: op.amount,
            description: 'Deducción devuelta a la Concentradora',
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
