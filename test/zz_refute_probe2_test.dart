import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/custom_widgets/product_card/product_card.dart';
import 'package:pos/http_client/local_storage/hive_service.dart';

import 'helpers/pos_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(bootStorage);
  tearDown(tearDownStorage);

  const names = [
    'Coca Cola 1.5L Bottle',
    'Chocolate Chip Cookies Family Pack',
    'Espresso',
  ];

  Future<void> openTill(WidgetTester tester, Size logical) async {
    tester.view.physicalSize = Size(logical.width * 2, logical.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await withStorage(tester, () async {
      await HiveService.storeSetting('exchangeRate', 89000.0);
      await HiveService.storeSetting('tva', 0.0);
      await seedCatalog(
        categories: ['Food'],
        products: [
          for (final n in names)
            product(description: n, category: 'Food', sellingPrice: 4.16),
        ],
      );
    });
    await tester.pumpWidget(posApp());
    await settle(tester);
  }

  for (final size in [
    const Size(1366, 1024),
    const Size(1180, 820),
    const Size(960, 720),
  ]) {
    testWidgets('M ${size.width}x${size.height}', (tester) async {
      await openTill(tester, size);
      final cards = find.byType(ProductCard);
      // ignore: avoid_print
      print('=== surface $size  cards=${cards.evaluate().length}');
      print('tile=${tester.getSize(cards.first)}');
      for (final n in names) {
        final f = find.text(n);
        if (f.evaluate().isEmpty) {
          print('  [$n] MISSING');
          continue;
        }
        final p = tester.renderObject<RenderParagraph>(f);
        final w = p.size.width;
        final unbounded =
            p.getDryLayout(BoxConstraints(minWidth: w, maxWidth: w));
        final tp = TextPainter(
          text: p.text,
          textDirection: TextDirection.ltr,
          textAlign: p.textAlign,
          maxLines: p.maxLines,
          textScaler: p.textScaler,
        )..layout(minWidth: 0, maxWidth: w);
        final lm = tp.computeLineMetrics();
        final lastBottom =
            lm.isEmpty ? 0.0 : lm.last.baseline + lm.last.descent;
        print('  [$n]');
        print('     boxSize=${p.size}  dryUnbounded=$unbounded '
            'painterH=${tp.height.toStringAsFixed(2)} '
            'lines=${lm.length} exceededMaxLines=${tp.didExceedMaxLines}');
        for (final m in lm) {
          print('       line${m.lineNumber} h=${m.height.toStringAsFixed(2)} '
              'base=${m.baseline.toStringAsFixed(2)} '
              'asc=${m.ascent.toStringAsFixed(2)} '
              'desc=${m.descent.toStringAsFixed(2)} '
              'w=${m.width.toStringAsFixed(1)}');
        }
        print('     lastInkBottom=${lastBottom.toStringAsFixed(2)} '
            'box=${p.size.height.toStringAsFixed(2)} '
            'CLIPPED=${lastBottom > p.size.height + 0.01}');
      }
      // dead space in the first card
      final col =
          find.descendant(of: cards.first, matching: find.byType(Column)).first;
      final colBox = tester.renderObject<RenderBox>(col);
      final texts =
          find.descendant(of: cards.first, matching: find.byType(Text));
      print('  column=${colBox.size}');
      final colTop = tester.getTopLeft(col).dy;
      for (final e in texts.evaluate()) {
        final rb = e.renderObject as RenderBox;
        print('   text "${(e.widget as Text).data}" size=${rb.size} '
            'relTop=${(rb.localToGlobal(Offset.zero).dy - colTop).toStringAsFixed(2)}');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
