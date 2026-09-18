/// Minimal number formatting (thousands separator + 2 decimals) without
/// adding a dependency like `intl` — no "$" prefix or currency code, just
/// the digits. Shared by [formatCurrency] and CurrencyField's live mask.
String formatAmount(double amount) {
  final fixed = amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decimals = parts[1];

  final buffer = StringBuffer();
  final reversed = intPart.split('').reversed.toList();
  for (var i = 0; i < reversed.length; i++) {
    if (i != 0 && i % 3 == 0) buffer.write(',');
    buffer.write(reversed[i]);
  }
  final withSeparators = buffer.toString().split('').reversed.join();

  return '$withSeparators.$decimals';
}

String formatCurrency(double amount, String currencyCode) {
  return '\$${formatAmount(amount)} $currencyCode';
}
