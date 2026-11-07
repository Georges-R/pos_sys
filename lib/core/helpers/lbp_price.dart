import 'package:pos/core/helpers/money.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';

/// Items rung up at a price keyed in in Lebanese pounds rather than looked up
/// in the catalog: typing "T250000" in the barcode field sells an item with
/// no barcode for 250,000 LL.
class LbpPrice {
  const LbpPrice._();

  static final RegExp _code = RegExp(r'^[tT]\s*(\d[\d,]*)$');

  /// The LL amount in a price code such as "T250000" (or "t250,000"), or null
  /// when [code] is not one. A code of "T0" parses to 0; it is up to the
  /// caller to refuse it.
  static double? parseCode(String code) {
    final match = _code.firstMatch(code.trim());
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  /// What [lines] come to in Lebanese pounds, VAT included.
  ///
  /// Lines priced in USD are totalled and rounded exactly as the USD total
  /// is, then converted at [exchangeRate]. Lines keyed in in LL are added at
  /// the amount the cashier typed, so T250000 comes to 250,000 LL and not to
  /// whatever its USD equivalent rounded to the cent converts back to.
  static double cartTotal(
    Iterable<AddEditItemModel> lines,
    double exchangeRate, {
    double tvaPercent = 0,
  }) {
    final vat = tvaPercent <= 0 ? 0.0 : tvaPercent / 100;
    var usd = 0.0;
    var lbp = 0.0;
    for (final line in lines) {
      final quantity = line.quantity ?? 1;
      final priceLBP = line.priceLBP;
      if (priceLBP != null) {
        lbp += priceLBP * quantity;
      } else {
        usd += (line.sellingPrice ?? 0.0) * quantity;
      }
    }
    final subtotalUSD = Money.round(usd);
    final totalUSD = Money.round(subtotalUSD + Money.round(subtotalUSD * vat));
    return Money.round(totalUSD * exchangeRate + lbp * (1 + vat), decimals: 0);
  }
}
