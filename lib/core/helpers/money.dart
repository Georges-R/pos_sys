/// Monetary rounding.
///
/// Prices are held as doubles, so accumulating them drifts: ten items at 0.10
/// sum to 0.9999999999999999, and a receipt that prints 1.00 while storing
/// that value will not reconcile against the till at the end of the day.
/// Every figure a customer is charged or that is written to the ledger goes
/// through here.
class Money {
  const Money._();

  static double round(double value, {int decimals = 2}) {
    if (value.isNaN || value.isInfinite) return 0.0;
    final factor = _pow10(decimals);
    return (value * factor).roundToDouble() / factor;
  }

  static double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  /// Parses user- or file-supplied text into an amount, tolerating blanks,
  /// thousands separators and a stray currency symbol.
  static double parse(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    final cleaned = '$value'.replaceAll(RegExp(r'[^0-9eE+\-.]'), '');
    return double.tryParse(cleaned) ?? fallback;
  }
}
