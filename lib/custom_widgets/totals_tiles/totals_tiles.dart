import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The grand-total display shared by the cart sidebar and the checkout
/// screen: one tile per currency, both amounts set at the same size so USD
/// and LBP read as peers. The tiles sit side by side when there is room and
/// stack vertically inside a narrow parent (the 400px cart sidebar).
class TotalsTiles extends StatelessWidget {
  const TotalsTiles({
    super.key,
    required this.totalUSD,
    required this.totalLBP,
    this.usdFootnote,
    this.lbpFootnote,
    this.amountSize = 52,
    this.gap = 16,
    this.stackBelowWidth = 620,
  });

  final double totalUSD;
  final double totalLBP;

  /// Small muted line under the USD amount (e.g. the VAT it includes).
  final String? usdFootnote;

  /// Small muted line under the LBP amount (e.g. the exchange rate).
  final String? lbpFootnote;

  /// Font size of BOTH amounts. They only shrink when they would overflow.
  final double amountSize;

  /// Gutter between the two tiles; matches the gutter of any button row
  /// placed under them so the grid edges coincide.
  final double gap;

  /// Below this width the tiles stack instead of sharing a row.
  final double stackBelowWidth;

  static const Color lbpColor = Color(0xFF1B8A4B);
  static final NumberFormat _usd = NumberFormat('#,##0.00');
  static final NumberFormat _lbp = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // Reserve the footnote slot in both tiles whenever either has one, so the
    // two amounts stay on the same line across the gutter.
    final reserveFootnote = usdFootnote != null || lbpFootnote != null;

    final usdTile = _TotalTile(
      code: 'USD',
      prefix: '\$',
      amount: _usd.format(totalUSD),
      color: primary,
      amountSize: amountSize,
      footnote: usdFootnote,
      reserveFootnote: reserveFootnote,
    );
    final lbpTile = _TotalTile(
      code: 'LBP',
      suffix: 'LBP',
      amount: _lbp.format(totalLBP),
      color: lbpColor,
      amountSize: amountSize,
      footnote: lbpFootnote,
      reserveFootnote: reserveFootnote,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth.isFinite &&
            constraints.maxWidth < stackBelowWidth;
        if (narrow) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [usdTile, SizedBox(height: gap * 0.75), lbpTile],
          );
        }
        return Row(
          children: [
            Expanded(child: usdTile),
            SizedBox(width: gap),
            Expanded(child: lbpTile),
          ],
        );
      },
    );
  }
}

/// One stat tile: a small caps caption ("TOTAL · USD") directly above a very
/// large centred amount, with an optional muted footnote below.
///
/// Every slot has a fixed height (one caption line, the amount box, the
/// footnote box), so the USD and LBP tiles are always the same height and
/// their rows line up even when only one of them has a footnote.
class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.code,
    required this.amount,
    required this.color,
    required this.amountSize,
    required this.reserveFootnote,
    this.prefix,
    this.suffix,
    this.footnote,
  });

  final String code;

  /// Already formatted digits, e.g. "4.16" or "370,240".
  final String amount;

  /// Currency mark drawn right before the digits ("$4.16").
  final String? prefix;

  /// Currency mark drawn right after the digits ("370,240 LBP").
  final String? suffix;

  final Color color;
  final double amountSize;
  final String? footnote;
  final bool reserveFootnote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final note = footnote;

    // The mark is a smaller run of the same text so it shares the digits'
    // baseline, colour and scaling; identical ratio for "$" and "LBP".
    final markStyle = TextStyle(
      fontSize: amountSize * 0.55,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
      height: 1.0,
      color: color.withValues(alpha: 0.85),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Caption: the currency code takes the amount's colour so the
          // identity sits directly on top of the number it belongs to.
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
                height: 1.2,
                color: muted,
              ),
              children: [
                const TextSpan(text: 'TOTAL  ·  '),
                TextSpan(text: code, style: TextStyle(color: color)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: amountSize * 1.1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: amountSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -amountSize * 0.02,
                    height: 1.0,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    if (prefix != null)
                      TextSpan(text: prefix, style: markStyle),
                    TextSpan(text: amount),
                    if (suffix != null)
                      TextSpan(text: ' $suffix', style: markStyle),
                  ],
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (reserveFootnote) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 20,
              child: note == null
                  ? null
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: muted,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
