import '../../core/http/kbm_backend_client.dart';
import '../../core/models/collector_deposit.dart';
import '../../core/models/collector_deposit_status.dart';
import '../../core/models/concentrator_account.dart';
import '../../core/models/concentrator_entry.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/treasury_statement.dart';
import 'treasury_repository.dart';

/// Implementación real de `TreasuryRepository` contra el backend
/// compartido — ver
/// docs/adr/0012-full-postgres-migration-clients-treasury-staff-approvals.md.
/// Reemplaza a `FakeTreasuryRepository`.
class HttpTreasuryRepository implements TreasuryRepository {
  HttpTreasuryRepository({required this.client});

  final KbmBackendClient client;

  ConcentratorAccount _accountFromJson(Map<String, dynamic> json) => ConcentratorAccount(
        id: json['id'] as String,
        clientId: json['clientId'] as String,
        currency: json['currency'] as String,
        balance: (json['balance'] as num).toDouble(),
      );

  ConcentratorEntry _entryFromJson(Map<String, dynamic> json) => ConcentratorEntry(
        id: json['id'] as String,
        concentratorAccountId: json['concentratorAccountId'] as String,
        type: (json['type'] as String) == 'credit' ? LedgerEntryType.credit : LedgerEntryType.debit,
        amount: (json['amount'] as num).toDouble(),
        balanceAfter: (json['balanceAfter'] as num).toDouble(),
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  CollectorDeposit _depositFromJson(Map<String, dynamic> json) => CollectorDeposit(
        id: json['id'] as String,
        clientId: json['clientId'] as String,
        amount: (json['amount'] as num).toDouble(),
        reference: json['reference'] as String,
        status: (json['status'] as String) == 'reconciled' ? CollectorDepositStatus.reconciled : CollectorDepositStatus.pending,
        registeredByEmail: json['registeredByEmail'] as String,
        reconciledByEmail: json['reconciledByEmail'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        reconciledAt: json['reconciledAt'] != null ? DateTime.parse(json['reconciledAt'] as String) : null,
      );

  @override
  Future<ConcentratorAccount?> getConcentratorAccount(String clientId) async {
    try {
      final json = await client.get('/v1/clients/$clientId/treasury/concentrator') as Map<String, dynamic>;
      return _accountFromJson(json);
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<ConcentratorAccount> createConcentratorAccount(String clientId) async {
    final json = await client.post('/v1/clients/$clientId/treasury/concentrator') as Map<String, dynamic>;
    return _accountFromJson(json);
  }

  @override
  Future<List<ConcentratorEntry>> listConcentratorEntries(String concentratorAccountId) async {
    final json = await client.get('/v1/concentrator-accounts/$concentratorAccountId/entries') as List<dynamic>;
    return json.map((e) => _entryFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ConcentratorEntry> postConcentratorEntry({
    required String concentratorAccountId,
    required LedgerEntryType type,
    required double amount,
    String? description,
  }) async {
    final json = await client.post('/v1/concentrator-accounts/$concentratorAccountId/entries', {
      'type': type == LedgerEntryType.credit ? 'credit' : 'debit',
      'amount': amount,
      'description': description ?? '',
    }) as Map<String, dynamic>;
    return _entryFromJson(json);
  }

  @override
  Future<List<CollectorDeposit>> listCollectorDeposits(String clientId) async {
    final json = await client.get('/v1/clients/$clientId/treasury/collector-deposits') as List<dynamic>;
    return json.map((e) => _depositFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<CollectorDeposit> registerDeposit({
    required String clientId,
    required double amount,
    required String reference,
    required String registeredByEmail,
  }) async {
    final json = await client.post('/v1/clients/$clientId/treasury/collector-deposits', {
      'amount': amount,
      'reference': reference,
      'registeredByEmail': registeredByEmail,
    }) as Map<String, dynamic>;
    return _depositFromJson(json);
  }

  @override
  Future<CollectorDeposit> reconcileDeposit({
    required String depositId,
    required String reconciledByEmail,
  }) async {
    final json = await client.post('/v1/collector-deposits/$depositId/reconcile', {
      'reconciledByEmail': reconciledByEmail,
    }) as Map<String, dynamic>;
    return _depositFromJson(json);
  }

  @override
  Future<TreasuryStatement?> getStatement(String clientId) async {
    try {
      final json = await client.get('/v1/clients/$clientId/treasury/statement') as Map<String, dynamic>;
      final entries = (json['entries'] as List<dynamic>).map((e) => _entryFromJson(e as Map<String, dynamic>)).toList();
      return TreasuryStatement(
        concentratorBalance: (json['concentratorBalance'] as num).toDouble(),
        currency: json['currency'] as String,
        entries: entries,
      );
    } on KbmBackendException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
