import 'ledger_entry.dart';

/// Saldo y movimientos de la Cuenta Individual de un Tarjetahabiente, a
/// nivel Cuenta — no de una tarjeta específica. Necesario para que staff
/// pueda ver el estado de cuenta de un Tarjetahabiente sin ninguna
/// tarjeta asignada todavía, ver
/// docs/adr/0020-cuenta-individual-tarjetahabiente.md, punto 3, y
/// docs/adr/0022-reportes-staff-y-visibilidad-beneficiarios.md, punto 6.
class AccountLedger {
  final double balance;
  final String currency;
  final List<LedgerEntry> entries;

  const AccountLedger({required this.balance, required this.currency, required this.entries});
}
