import 'ledger_movement.dart';

/// Saldo y movimientos de la Cuenta Individual, a nivel Cuenta — no de
/// una tarjeta específica. Necesario para un Tarjetahabiente sin ninguna
/// tarjeta asignada todavía (ver
/// docs/adr/0020-cuenta-individual-tarjetahabiente.md, punto 3: "la
/// Cuenta puede recibir SPEI desde el día del alta").
class AccountLedger {
  final double balance;
  final String currency;
  final List<LedgerMovement> movements;

  const AccountLedger({required this.balance, required this.currency, required this.movements});
}
