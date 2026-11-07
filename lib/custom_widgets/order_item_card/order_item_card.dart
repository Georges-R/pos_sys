import 'package:flutter/material.dart';

class OrderItemCard extends StatelessWidget {
  const OrderItemCard({
    super.key,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.onIncrease,
    this.onDecrease,
    this.onRemove,
    this.onLongPress,
    this.lowStockLeft,
    this.backgroundColor,
    this.textColor,
  });

  final String productName;
  final int quantity;
  final double unitPrice;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback? onRemove;
  final VoidCallback? onLongPress;

  /// The stock left on the shelf, set only when the product has fallen to its
  /// low-stock warning. The line is then drawn in red so the cashier notices
  /// while ringing it up.
  final int? lowStockLeft;
  final Color? backgroundColor;
  final Color? textColor;

  /// The cart owns the wide side of the till, so the line is sized to be
  /// read and tapped at arm's length rather than packed into a sidebar.
  static const double _buttonSize = 56.0;
  static const double _iconSize = 34.0;

  /// The line total never gives up more of the row than this, and scales its
  /// digits down instead of pushing the name off the card.
  static const double _totalMaxWidth = 180.0;

  /// The unit line and the line total share one size: the count and the unit
  /// price are what a customer checks the total against.
  static const double _amountFontSize = 28.0;

  static const double _lowStockStripeWidth = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = quantity * unitPrice;
    final lowStockLeft = this.lowStockLeft;
    final isLowStock = lowStockLeft != null;
    final alert = theme.colorScheme.error;
    final baseColor = backgroundColor ?? theme.cardColor;

    return Card(
      color: isLowStock
          ? Color.alphaBlend(alert.withValues(alpha: 0.08), baseColor)
          : baseColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      elevation: 2.0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: isLowStock
                ? Border(
                    left: BorderSide(color: alert, width: _lowStockStripeWidth),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 18.0, 12.0, 18.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        productName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6.0),
                      // Scaled down rather than cut off: a price with its last
                      // digits ellipsised away reads as a different price.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$quantity x \$${unitPrice.toStringAsFixed(2)}',
                          maxLines: 1,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color:
                                textColor ?? theme.colorScheme.onSurfaceVariant,
                            fontSize: _amountFontSize,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (isLowStock) ...[
                        const SizedBox(height: 6.0),
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 22, color: alert),
                            const SizedBox(width: 6.0),
                            Flexible(
                              child: Text(
                                'Low stock · $lowStockLeft left',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: alert,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12.0),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _totalMaxWidth),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '\$${total.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontSize: _amountFontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      iconSize: _iconSize,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                          width: _buttonSize, height: _buttonSize),
                      color: textColor ?? theme.colorScheme.primary,
                      onPressed: onDecrease,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      iconSize: _iconSize,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                          width: _buttonSize, height: _buttonSize),
                      color: textColor ?? theme.colorScheme.primary,
                      onPressed: onIncrease,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      iconSize: _iconSize,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                          width: _buttonSize, height: _buttonSize),
                      color: theme.colorScheme.error,
                      onPressed: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
