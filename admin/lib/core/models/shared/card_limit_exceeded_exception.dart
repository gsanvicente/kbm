class CardLimitExceededException implements Exception {
  final int limit;
  const CardLimitExceededException(this.limit);

  String get message =>
      'Este Cliente permite un máximo de $limit tarjeta(s) activa(s) por tarjetahabiente.';

  @override
  String toString() => message;
}
