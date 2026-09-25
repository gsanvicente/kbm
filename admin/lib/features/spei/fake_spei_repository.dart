import '../../core/models/account_ledger.dart';
import '../../core/models/beneficiary_directory_entry.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/shared/not_found_exception.dart';
import '../../core/models/spei_deposit.dart';
import '../../core/models/spei_payment.dart';
import 'spei_repository.dart';

/// In-memory stand-in para la cola de aprobación SPEI — un par de pagos
/// sembrados para poder ver/ejercer la pestaña sin backend real. El alta
/// real (registrar Beneficiario, solicitar un pago) vive 100% en
/// `cardholder/`; este fake nunca la simula, solo el lado de
/// aprobar/rechazar que sí le corresponde a `admin/`. Ver
/// docs/adr/0021-conector-spei.md.
class FakeSpeiRepository implements SpeiRepository {
  final List<SpeiPayment> _payments = [
    SpeiPayment(
      id: 'spei-op-1',
      clientId: '00000000-0000-0000-0000-000000000002',
      accountId: 'acct-demo-1',
      beneficiaryId: 'ben-demo-1',
      beneficiaryAlias: 'Casero',
      beneficiaryClabe: '072180000118359719',
      requestedByFullName: 'Juan Perez',
      amount: 3500.00,
      status: OperationStatus.pendingApproval,
      createdAt: DateTime(2026, 9, 20),
    ),
  ];

  @override
  Future<List<SpeiPayment>> listPendingByClients(List<String> clientIds) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _payments.where((p) => clientIds.contains(p.clientId) && !p.status.isResolved).toList();
  }

  @override
  Future<SpeiPayment> approve({required String paymentId, required String approvedByEmail}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) throw NotFoundException('Pago $paymentId no encontrado');
    if (_payments[index].status.isResolved) throw StateError('Este pago ya fue resuelto.');
    // Sin Cuenta Individual real que debitar en este fake — siempre
    // "ejecuta" de inmediato, nunca simula fondos insuficientes.
    final updated = _payments[index].copyWith(status: OperationStatus.executed, resolvedByEmail: approvedByEmail);
    _payments[index] = updated;
    return updated;
  }

  @override
  Future<SpeiPayment> reject({
    required String paymentId,
    required String rejectedByEmail,
    required String reason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) throw NotFoundException('Pago $paymentId no encontrado');
    if (_payments[index].status.isResolved) throw StateError('Este pago ya fue resuelto.');
    final updated = _payments[index].copyWith(
      status: OperationStatus.rejected,
      resolvedByEmail: rejectedByEmail,
      resolutionNotes: reason,
    );
    _payments[index] = updated;
    return updated;
  }

  @override
  Future<List<SpeiPayment>> listAllByClients(List<String> clientIds) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // La CLABE va enmascarada aquí — mismo criterio que el backend real
    // (dto.FromSPEIPaymentForReport): este es el reporte histórico
    // agregado de staff, no la cola de aprobaciones (que sí necesita la
    // CLABE real para verificar contra el banco).
    return _payments
        .where((p) => clientIds.contains(p.clientId))
        .map((p) => SpeiPayment(
              id: p.id,
              clientId: p.clientId,
              accountId: p.accountId,
              beneficiaryId: p.beneficiaryId,
              beneficiaryAlias: p.beneficiaryAlias,
              beneficiaryClabe: _maskClabe(p.beneficiaryClabe),
              requestedByFullName: p.requestedByFullName,
              amount: p.amount,
              status: p.status,
              resolvedByEmail: p.resolvedByEmail,
              resolutionNotes: p.resolutionNotes,
              createdAt: p.createdAt,
            ))
        .toList();
  }

  String _maskClabe(String clabe) => clabe.length < 4 ? '••••' : '••••${clabe.substring(clabe.length - 4)}';

  final List<SpeiDeposit> _deposits = [
    SpeiDeposit(
      id: 'spei-dep-1',
      clientId: '00000000-0000-0000-0000-000000000002',
      accountId: 'acct-demo-1',
      amount: 1500.00,
      providerReference: 'SIM-DEMO-1',
      createdAt: DateTime(2026, 9, 18),
      cardholderFullName: 'Juan Perez',
    ),
  ];

  @override
  Future<List<SpeiDeposit>> listDepositsByClients(List<String> clientIds) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _deposits.where((d) => clientIds.contains(d.clientId)).toList();
  }

  final List<BeneficiaryDirectoryEntry> _beneficiaries = [
    BeneficiaryDirectoryEntry(
      id: 'ben-demo-1',
      alias: 'Casero',
      maskedClabe: '••••9719',
      bankName: 'Banorte',
      coolingUntil: DateTime(2026, 9, 19),
      isCooling: false,
      createdAt: DateTime(2026, 9, 18),
      clientId: '00000000-0000-0000-0000-000000000002',
      cardholderId: '20000000-0000-0000-0000-000000000001',
      cardholderFullName: 'Juan Perez',
      paymentCount: 0,
      totalAmountPaid: 0,
      sharedByMultipleCardholders: false,
    ),
  ];

  @override
  Future<List<BeneficiaryDirectoryEntry>> listBeneficiaryDirectory(List<String> clientIds) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _beneficiaries.where((b) => clientIds.contains(b.clientId)).toList();
  }

  @override
  Future<String> revealClabe(String beneficiaryId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final entry = _beneficiaries.firstWhere(
      (b) => b.id == beneficiaryId,
      orElse: () => throw NotFoundException('Beneficiario $beneficiaryId no encontrado'),
    );
    // El fake nunca guardó la CLABE completa (solo sembró la
    // enmascarada) — se sintetiza una consistente con la máscara, solo
    // para que la UI tenga algo real que mostrar en modo demo.
    return '072180000118359719'.substring(0, 14) + entry.maskedClabe.replaceAll('•', '');
  }

  @override
  Future<AccountLedger> getAccountLedger(String cardholderId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    // Sin Cuenta Individual real en este fake — ver el doc de la clase.
    return const AccountLedger(balance: 0, currency: 'MXN', entries: []);
  }
}
