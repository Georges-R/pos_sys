import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.productName,
    required this.price,
    this.onAddToCart,
    this.onLongPress,
    this.backgroundColor,
    this.textColor,
  });

  final String productName;
  final double price;
  final VoidCallback? onAddToCart;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: backgroundColor ?? theme.cardColor,
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: onAddToCart,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          // A tile only ever gets as much room as the grid gives it. Taking
          // the children's natural height overflowed as soon as the window
          // was narrow enough to squeeze the cells.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  productName,
                  textAlign: TextAlign.center,
                  style:
                      theme.textTheme.titleMedium?.copyWith(color: textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4.0),
              Flexible(
                child: Text(
                  '\$${price.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
