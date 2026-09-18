/// The real pooled account behind a Cliente's Dispersiones/Deducciones —
/// 1:1 with a Cliente, never with a Tarjeta. See
/// docs/business/tesoreria-cliente.md.
class ConcentratorAccount {
  final String id;
  final String clientId;
  final String currency;
  final double balance;

  const ConcentratorAccount({
    required this.id,
    required this.clientId,
    required this.currency,
    required this.balance,
  });

  ConcentratorAccount copyWith({double? balance}) {
    return ConcentratorAccount(
      id: id,
      clientId: clientId,
      currency: currency,
      balance: balance ?? this.balance,
    );
  }
}
