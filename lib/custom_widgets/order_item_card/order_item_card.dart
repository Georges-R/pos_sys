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
    this.backgroundColor,
    this.textColor,
  });

  final String productName;
  final int quantity;
  final double unitPrice;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback? onRemove;
  final Color? backgroundColor;
  final Color? textColor;

  /// The three buttons are the widest fixed block on the line. Left at the
  /// default 48pt they took 144 of the sidebar's 368 usable points and left
  /// the product name too little room to grow, so they are packed tighter
  /// while keeping a comfortable tap target.
  static const double _buttonSize = 42.0;

  /// The line total never gives up more of the row than this, and scales its
  /// digits down instead of pushing the name off the card.
  static const double _totalMaxWidth = 116.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = quantity * unitPrice;

    return Card(
      color: backgroundColor ?? theme.cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 8.0, 12.0),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5.0),
                  Text(
                    '$quantity x \$${unitPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor ?? theme.colorScheme.onSurfaceVariant,
                      fontSize: 15,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: _totalMaxWidth),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '\$${total.toStringAsFixed(2)}',
                  maxLines: 1,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 26,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                      width: _buttonSize, height: _buttonSize),
                  color: textColor ?? theme.colorScheme.primary,
                  onPressed: onDecrease,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 26,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                      width: _buttonSize, height: _buttonSize),
                  color: textColor ?? theme.colorScheme.primary,
                  onPressed: onIncrease,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 26,
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
    );
  }
}
