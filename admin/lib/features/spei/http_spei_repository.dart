import '../../core/http/kbm_backend_client.dart';
import '../../core/models/account_ledger.dart';
import '../../core/models/beneficiary_directory_entry.dart';
import '../../core/models/ledger_entry.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/operation_status.dart';
import '../../core/models/shared/not_found_exception.dart';
import '../../core/models/spei_deposit.dart';
import '../../core/models/spei_payment.dart';
import 'spei_repository.dart';

/// Implementación real de `SpeiRepository` contra el backend compartido —
/// ver docs/adr/0021-conector-spei.md.
class HttpSpeiRepository implements SpeiRepository {
  HttpSpeiRepository({required this.client});

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

  SpeiPayment _fromJson(Map<String, dynamic> json) => SpeiPayment(
        id: json['id'] as String,
        clientId: json['clientId'] as String,
        accountId: json['accountId'] as String,
        beneficiaryId: json['beneficiaryId'] as String,
        beneficiaryAlias: json['beneficiaryAlias'] as String? ?? '',
        beneficiaryClabe: json['beneficiaryClabe'] as String? ?? '',
        requestedByFullName: json['requestedByFullName'] as String? ?? '—',
        amount: (json['amount'] as num).toDouble(),
        status: _statusFromJson(json['status'] as String),
        resolvedByEmail: json['resolvedByEmail'] as String?,
        resolutionNotes: json['resolutionNotes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  Future<List<SpeiPayment>> listPendingByClients(List<String> clientIds) async {
    if (clientIds.isEmpty) return [];
    final json = await client.get('/v1/spei-payments/pending?client_ids=${clientIds.join(',')}') as List<dynamic>;
    return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<SpeiPayment> approve({required String paymentId, required String approvedByEmail}) async {
    try {
      final json = await client.post('/v1/spei-payments/$paymentId/approve', {
        'approvedByEmail': approvedByEmail,
      }) as Map<String, dynamic>;
      return _fromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) throw NotFoundException('Pago $paymentId no encontrado');
      if (e.statusCode == 409) throw StateError('Este pago ya fue resuelto.');
      rethrow;
    }
  }

  @override
  Future<SpeiPayment> reject({
    required String paymentId,
    required String rejectedByEmail,
    required String reason,
  }) async {
    try {
      final json = await client.post('/v1/spei-payments/$paymentId/reject', {
        'rejectedByEmail': rejectedByEmail,
        'reason': reason,
      }) as Map<String, dynamic>;
      return _fromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) throw NotFoundException('Pago $paymentId no encontrado');
      if (e.statusCode == 409) throw StateError('Este pago ya fue resuelto.');
      rethrow;
    }
  }

  @override
  Future<List<SpeiPayment>> listAllByClients(List<String> clientIds) async {
    if (clientIds.isEmpty) return [];
    final json = await client.get('/v1/spei-payments?client_ids=${clientIds.join(',')}') as List<dynamic>;
    return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<SpeiDeposit>> listDepositsByClients(List<String> clientIds) async {
    if (clientIds.isEmpty) return [];
    final json = await client.get('/v1/spei-deposits?client_ids=${clientIds.join(',')}') as List<dynamic>;
    return json.map((e) {
      final map = e as Map<String, dynamic>;
      return SpeiDeposit(
        id: map['id'] as String,
        clientId: map['clientId'] as String,
        accountId: map['accountId'] as String,
        amount: (map['amount'] as num).toDouble(),
        providerReference: map['providerReference'] as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        cardholderFullName: map['cardholderFullName'] as String? ?? '—',
      );
    }).toList();
  }

  @override
  Future<List<BeneficiaryDirectoryEntry>> listBeneficiaryDirectory(List<String> clientIds) async {
    if (clientIds.isEmpty) return [];
    final json = await client.get('/v1/spei-beneficiaries?client_ids=${clientIds.join(',')}') as List<dynamic>;
    return json.map((e) {
      final map = e as Map<String, dynamic>;
      return BeneficiaryDirectoryEntry(
        id: map['id'] as String,
        alias: map['alias'] as String,
        maskedClabe: map['maskedClabe'] as String,
        bankName: map['bankName'] as String,
        coolingUntil: DateTime.parse(map['coolingUntil'] as String),
        isCooling: map['isCooling'] as bool,
        createdAt: DateTime.parse(map['createdAt'] as String),
        clientId: map['clientId'] as String,
        cardholderId: map['cardholderId'] as String,
        cardholderFullName: map['cardholderFullName'] as String,
        paymentCount: map['paymentCount'] as int,
        totalAmountPaid: (map['totalAmountPaid'] as num).toDouble(),
        sharedByMultipleCardholders: map['sharedByMultipleCardholders'] as bool,
      );
    }).toList();
  }

  @override
  Future<String> revealClabe(String beneficiaryId) async {
    final json = await client.post('/v1/spei-beneficiaries/$beneficiaryId/reveal') as Map<String, dynamic>;
    return json['clabe'] as String;
  }

  @override
  Future<AccountLedger> getAccountLedger(String cardholderId) async {
    final json = await client.get('/v1/cardholders/$cardholderId/account/ledger') as Map<String, dynamic>;
    final entries = (json['entries'] as List<dynamic>).map((e) {
      final map = e as Map<String, dynamic>;
      return LedgerEntry(
        id: map['id'] as String,
        ledgerAccountId: '',
        type: (map['type'] as String) == 'credit' ? LedgerEntryType.credit : LedgerEntryType.debit,
        amount: (map['amount'] as num).toDouble(),
        balanceAfter: (map['balanceAfter'] as num).toDouble(),
        description: map['description'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
    }).toList();
    return AccountLedger(
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String,
      entries: entries,
    );
  }
}
