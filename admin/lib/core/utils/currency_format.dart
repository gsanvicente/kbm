/// Minimal currency formatting (thousands separator + 2 decimals) without
/// adding a dependency like `intl` — revisit if real fondeo/débito forms
/// later need locale-aware parsing/validation, not just display.
String formatCurrency(double amount, String currencyCode) {
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

  return '\$$withSeparators.$decimals $currencyCode';
}
