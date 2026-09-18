const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Formato compacto para una fila de movimiento — no usa `intl` a
/// propósito, mismo criterio minimalista que `currency_format.dart`.
String formatMovementDate(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_months[date.month - 1]} ${date.year}, $hour:$minute';
}
