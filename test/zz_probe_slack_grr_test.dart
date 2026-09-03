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

  testWidgets('slack distribution at 1366x1024', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(2732, 2048);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await withStorage(tester, () async {
      await HiveService.storeSetting('exchangeRate', 90000.0);
      await HiveService.storeSetting('tva', 0.0);
      await seedCatalog(categories: ['Drinks'], products: [
        product(description: 'Coca Cola 1.5L Bottle', category: 'Drinks', barcode: '1', sellingPrice: 4.16),
      ]);
    });
    await tester.pumpWidget(posApp());
    await settle(tester);

    final cardEl = find.byType(ProductCard).evaluate().first;
    final cardBox = cardEl.findRenderObject() as RenderBox;
    final cardTop = cardBox.localToGlobal(Offset.zero).dy;
    debugPrint('card top=$cardTop size=${cardBox.size}');

    void report(String label, Finder f) {
      final b = f.evaluate().first.findRenderObject() as RenderBox;
      final top = b.localToGlobal(Offset.zero).dy - cardTop;
      debugPrint('  $label: top=${top.toStringAsFixed(2)} '
          'h=${b.size.height.toStringAsFixed(2)} '
          'bottom=${(top + b.size.height).toStringAsFixed(2)}');
    }

    report('name', find.text('Coca Cola 1.5L Bottle'));
    report('usd', find.text('\$4.16'));
    report('lbp', find.text('374,400 LBP'));
    debugPrint('  card height=${cardBox.size.height}');
  });
}
