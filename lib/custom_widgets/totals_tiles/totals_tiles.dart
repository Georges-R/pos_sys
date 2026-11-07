import 'dart:math' as math;

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
    this.expand = false,
  });

  final double totalUSD;
  final double totalLBP;

  /// Small muted line under the USD amount (e.g. the VAT it includes).
  final String? usdFootnote;

  /// Small muted line under the LBP amount (e.g. the exchange rate).
  final String? lbpFootnote;

  /// Font size of BOTH amounts. They only shrink when they would overflow.
  /// With [expand] it is the largest size the amounts may grow to.
  final double amountSize;

  /// Gutter between the two tiles; matches the gutter of any button row
  /// placed under them so the grid edges coincide.
  final double gap;

  /// Below this width the tiles stack instead of sharing a row.
  final double stackBelowWidth;

  /// Fill the parent's whole height instead of sizing to the content: the
  /// tiles stretch to share it and the amounts grow (up to [amountSize]) to
  /// use it. When the space is too short even for the smallest amount, the
  /// whole tile is scaled down, so nothing overflows and nothing scrolls.
  final bool expand;

  /// Smallest amount size [expand] picks; below it the tile scales instead.
  static const double _minFittedAmountSize = 24;

  static const Color lbpColor = Color(0xFF1B8A4B);
  static final NumberFormat _usd = NumberFormat('#,##0.00');
  static final NumberFormat _lbp = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // Reserve the footnote slot in both tiles whenever either has one, so the
    // two amounts stay on the same line across the gutter.
    final reserveFootnote = usdFootnote != null || lbpFootnote != null;

    _TotalTile usdTileAt(double size, {bool fill = false}) => _TotalTile(
          code: 'USD',
          prefix: '\$',
          amount: _usd.format(totalUSD),
          color: primary,
          amountSize: size,
          footnote: usdFootnote,
          reserveFootnote: reserveFootnote,
          centerContent: fill,
        );
    _TotalTile lbpTileAt(double size, {bool fill = false}) => _TotalTile(
          code: 'LBP',
          suffix: 'LBP',
          amount: _lbp.format(totalLBP),
          color: lbpColor,
          amountSize: size,
          footnote: lbpFootnote,
          reserveFootnote: reserveFootnote,
          centerContent: fill,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth.isFinite &&
            constraints.maxWidth < stackBelowWidth;

        if (expand && constraints.hasBoundedHeight) {
          final tileWidth =
              narrow ? constraints.maxWidth : (constraints.maxWidth - gap) / 2;
          final tileHeight = narrow
              ? (constraints.maxHeight - gap * 0.75) / 2
              : constraints.maxHeight;
          final size = _fittedAmountSize(tileHeight, reserveFootnote);

          // The tile is laid out at its real width and at least the slot's
          // height (content centred); if it still comes out taller than the
          // slot, FittedBox shrinks the whole tile to fit.
          Widget fitted(Widget tile) => FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: math.max(0, tileWidth),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: math.max(0, tileHeight)),
                    child: tile,
                  ),
                ),
              );

          final usd = fitted(usdTileAt(size, fill: true));
          final lbp = fitted(lbpTileAt(size, fill: true));
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: usd),
                SizedBox(height: gap * 0.75),
                Expanded(child: lbp),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: usd),
              SizedBox(width: gap),
              Expanded(child: lbp),
            ],
          );
        }

        final usdTile = usdTileAt(amountSize);
        final lbpTile = lbpTileAt(amountSize);
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

  /// The largest amount size, capped at [amountSize], whose tile fits in
  /// [tileHeight]. A tile's height grows steadily with its amount size, so a
  /// bisection finds it.
  double _fittedAmountSize(double tileHeight, bool reserveFootnote) {
    bool fits(double size) =>
        _TileMetrics(size).height(reserveFootnote: reserveFootnote) <=
        tileHeight;

    if (amountSize <= _minFittedAmountSize) return amountSize;
    if (fits(amountSize)) return amountSize;
    if (!fits(_minFittedAmountSize)) return _minFittedAmountSize;
    var lo = _minFittedAmountSize;
    var hi = amountSize;
    for (var i = 0; i < 20; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

/// Every size inside a tile, derived from its amount size. Shared by the
/// tile's layout and by [TotalsTiles] when it works out the amount size that
/// fills a given height, so the two can't drift apart.
class _TileMetrics {
  _TileMetrics(this.amountSize)
      // Caption, footnote and padding grow with a large amount so the tile
      // keeps its proportions; at the default size they stay as they were.
      : captionSize = math.max(13.0, amountSize * 0.2),
        footnoteSize = math.max(14.0, amountSize * 0.2),
        verticalPadding = math.max(14.0, amountSize * 0.2);

  final double amountSize;
  final double captionSize;
  final double footnoteSize;
  final double verticalPadding;

  static const double horizontalPadding = 20;
  static const double borderWidth = 1;
  static const double captionLineHeight = 1.2;
  static const double captionGap = 8;
  static const double footnoteGap = 6;

  double get amountBoxHeight => amountSize * 1.1;
  double get footnoteBoxHeight => math.max(20.0, footnoteSize * 1.45);

  /// Outer height of the tile, border included.
  double height({required bool reserveFootnote}) =>
      2 * (verticalPadding + borderWidth) +
      captionSize * captionLineHeight +
      captionGap +
      amountBoxHeight +
      (reserveFootnote ? footnoteGap + footnoteBoxHeight : 0);
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
    this.centerContent = false,
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

  /// Centre the content vertically when the tile is stretched taller than
  /// it needs (the [TotalsTiles.expand] layout).
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final note = footnote;
    final metrics = _TileMetrics(amountSize);
    final captionSize = metrics.captionSize;
    final footnoteSize = metrics.footnoteSize;
    final verticalPadding = metrics.verticalPadding;

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
      alignment: centerContent ? Alignment.center : null,
      padding: EdgeInsets.symmetric(
        horizontal: _TileMetrics.horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant,
          width: _TileMetrics.borderWidth,
        ),
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
                fontSize: captionSize,
                fontWeight: FontWeight.w800,
                letterSpacing: captionSize * 0.17,
                height: _TileMetrics.captionLineHeight,
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
          const SizedBox(height: _TileMetrics.captionGap),
          SizedBox(
            height: metrics.amountBoxHeight,
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
            const SizedBox(height: _TileMetrics.footnoteGap),
            SizedBox(
              height: metrics.footnoteBoxHeight,
              child: note == null
                  ? null
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: footnoteSize,
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
