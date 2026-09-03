import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/custom_widgets/totals_tiles/totals_tiles.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.productName,
    required this.price,
    this.exchangeRate = 0,
    this.onAddToCart,
    this.onLongPress,
    this.backgroundColor,
    this.textColor,
  });

  final String productName;

  /// Shelf price in USD.
  final double price;

  /// LBP per USD. The LBP line is dropped when no rate is configured rather
  /// than showing a 0 that a cashier could read as the real price.
  final double exchangeRate;

  final VoidCallback? onAddToCart;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? textColor;

  static final NumberFormat _usd = NumberFormat('#,##0.00');
  static final NumberFormat _lbp = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showLBP = exchangeRate > 0;
    // Same green the totals tiles use, so LBP reads as one currency
    // everywhere it appears.
    final lbpColor = textColor ?? TotalsTiles.lbpColor;
    final usdColor = textColor ?? theme.colorScheme.primary;

    return Card(
      color: backgroundColor ?? theme.cardColor,
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: onAddToCart,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          // A tile only ever gets as much room as the grid gives it. Taking
          // the children's natural height overflowed as soon as the window
          // was narrow enough to squeeze the cells, so every line is
          // Flexible and the amounts scale down before they clip.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  productName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6.0),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '\$${_usd.format(price)}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: usdColor,
                    ),
                  ),
                ),
              ),
              if (showLBP) ...[
                const SizedBox(height: 2.0),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_lbp.format((price * exchangeRate).roundToDouble())} LBP',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: lbpColor,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
