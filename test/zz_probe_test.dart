import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/custom_widgets/product_card/product_card.dart';

void main() {
  test('grid geometry at iPad landscape', () {
    for (final total in <double>[1366, 1194, 1024, 1440, 1112, 900]) {
      const sidebar = 400.0;
      final gridW = total - sidebar - 24; // GridView padding all 12
      const maxExt = 200.0, spacing = 8.0, ratio = 1.15;
      final count = (gridW / (maxExt + spacing)).ceil();
      final usable = gridW - spacing * (count - 1);
      final childW = usable / count;
      final childH = childW / ratio;
      final colH = childH - 8 - 16; // card margin 4*2, padding 8*2
      final perFlex = (colH - 8) / 3;
      // ignore: avoid_print
      print('win=$total gridW=$gridW cols=$count tile=${childW.toStringAsFixed(2)}x'
          '${childH.toStringAsFixed(2)} colH=${colH.toStringAsFixed(2)} '
          'perFlex=${perFlex.toStringAsFixed(2)} '
          'contentW=${(childW - 8 - 20).toStringAsFixed(2)}');
    }
  });

  testWidgets('measure name paragraph', (tester) async {
    for (final tile in <Size>[
      const Size(182, 158.26),
      const Size(200, 173.9),
    ]) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: tile.width,
              height: tile.height,
              child: const ProductCard(
                productName: 'Chicken Sandwich',
                price: 4.16,
                exchangeRate: 89000,
              ),
            ),
          ),
        ),
      ));
      final para = tester.renderObject<RenderParagraph>(
          find.text('Chicken Sandwich'));
      final tp = TextPainter(
        text: TextSpan(text: 'Chicken Sandwich', style: para.text.style),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: para.size.width);
      final col = tester.renderObject<RenderFlex>(find.byType(Column).last);
      // ignore: avoid_print
      print('TILE ${tile.width}x${tile.height} -> paraSize=${para.size} '
          'natural=${tp.height} lines=${tp.computeLineMetrics().length} '
          'colSize=${col.size} style.height=${para.text.style?.height} '
          'fontSize=${para.text.style?.fontSize} '
          'leading=${para.text.style?.leadingDistribution}');
      for (final m in tp.computeLineMetrics()) {
        // ignore: avoid_print
        print('   line ${m.lineNumber}: h=${m.height} asc=${m.ascent} desc=${m.descent} baseline=${m.baseline} w=${m.width}');
      }
      var contentH = 0.0;
      col.visitChildren((c) {
        contentH += (c as RenderBox).size.height;
        // ignore: avoid_print
        print('   child ${c.runtimeType} h=${c.size.height}');
      });
      // ignore: avoid_print
      print('   contentH=$contentH deadSpace=${col.size.height - contentH}');
      expect(tester.takeException(), isNull);
    }
  });
}
