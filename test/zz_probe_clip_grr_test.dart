import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/custom_widgets/product_card/product_card.dart';
import 'package:pos/http_client/local_storage/hive_service.dart';

import 'helpers/pos_harness.dart';

const names = <String>[
  'Coca Cola 1.5L Bottle',
  'Chocolate Chip Cookies Family Pack',
  'Espresso',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(bootStorage);
  tearDown(tearDownStorage);

  Future<void> openAt(WidgetTester tester, Size logical) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = logical * 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await withStorage(tester, () async {
      await HiveService.storeSetting('exchangeRate', 90000.0);
      await HiveService.storeSetting('tva', 0.0);
      await seedCatalog(categories: [
        'Drinks'
      ], products: [
        for (var i = 0; i < names.length; i++)
          product(
              description: names[i],
              category: 'Drinks',
              barcode: '10$i',
              sellingPrice: 4.16),
      ]);
    });
    await tester.pumpWidget(posApp());
    await settle(tester);
  }

  for (final logical in const [
    Size(1366, 1024),
    Size(1180, 820),
    Size(960, 720),
  ]) {
    testWidgets('MEASURE ${logical.width}x${logical.height}', (tester) async {
      await openAt(tester, logical);
      final card = find.byType(ProductCard).evaluate().first;
      final cardBox = card.findRenderObject() as RenderBox;
      debugPrint('--- ${logical.width}x${logical.height} tile=${cardBox.size}');
      for (final n in names) {
        final f = find.text(n);
        if (f.evaluate().isEmpty) {
          debugPrint('  "$n" NOT FOUND');
          continue;
        }
        final rp = tester.renderObject<RenderParagraph>(f);
        final cons = rp.constraints;
        debugPrint('  "$n"');
        debugPrint('     boxSize=${rp.size} textSize=${rp.textSize} '
            'exceeded=${rp.didExceedMaxLines} maxH=${cons.maxHeight.toStringAsFixed(2)} '
            'maxW=${cons.maxWidth.toStringAsFixed(2)}');
        debugPrint('     clipped=${rp.size.height < rp.textSize.height} '
            'cut=${(rp.textSize.height - rp.size.height).toStringAsFixed(2)}');
      }
      // What the whole column actually uses vs the room it has.
      final col = find
          .descendant(of: find.byType(ProductCard).first, matching: find.byType(Column))
          .evaluate()
          .first
          .findRenderObject() as RenderBox;
      debugPrint('  columnBox=${col.size} constraints=${col.constraints}');
      final pad = find
          .descendant(of: find.byType(ProductCard).first, matching: find.byType(Padding))
          .evaluate()
          .map((e) => (e.findRenderObject() as RenderBox).size)
          .toList();
      debugPrint('  paddings=$pad');
    });
  }
}

// appended: where does the slack actually sit?
void main2() {}
