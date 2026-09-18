class InsufficientFundsException implements Exception {
  final double currentBalance;
  final double requestedAmount;
  const InsufficientFundsException({required this.currentBalance, required this.requestedAmount});

  String get message =>
      'Fondos insuficientes: saldo actual \$${currentBalance.toStringAsFixed(2)}, '
      'monto solicitado \$${requestedAmount.toStringAsFixed(2)}.';

  @override
  String toString() => message;
}
