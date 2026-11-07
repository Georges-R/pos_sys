import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/http_client/local_storage/hive_service.dart';
import 'package:pos/http_client/local_storage/local_storage_helpers.dart';
import 'package:pos/http_client/services/excel_service.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';

import '../helpers/pos_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(bootStorage);
  tearDown(tearDownStorage);

  group('the low stock warning', () {
    test('is reached at the warning level, not only below it', () {
      final item = AddEditItemModel(quantity: 5, lowStockWarning: 5);
      expect(item.isLowOnStock, isTrue);
      item.quantity = 6;
      expect(item.isLowOnStock, isFalse);
    });

    test('is never reached on an item with no warning set', () {
      expect(AddEditItemModel(quantity: 0).isLowOnStock, isFalse);
    });

    test('is saved with the item', () {
      final json = AddEditItemModel(lowStockWarning: 4).toJson();
      expect(AddEditItemModel.fromJson(json).lowStockWarning, 4);
      expect(AddEditItemModel.fromJson({}).lowStockWarning, isNull);
    });

    test('survives a backup, and a blank one stays blank', () async {
      await seedCatalog(categories: [
        'Drinks'
      ], products: [
        product(description: 'Espresso', category: 'Drinks', barcode: '1')
          ..lowStockWarning = 5,
        product(description: 'Latte', category: 'Drinks', barcode: '2'),
      ]);
      final workbook = await ExcelService.buildWorkbook();
      await HiveService.clearBox('itemsBox');
      await ExcelService.applyWorkbook(workbook);

      final restored = LocalStorageHelpers.getJsonList('itemsBox', 'products')!
          .map(AddEditItemModel.fromJson)
          .toList();
      expect(restored.firstWhere((p) => p.barcode == '1').lowStockWarning, 5);
      expect(
          restored.firstWhere((p) => p.barcode == '2').lowStockWarning, isNull);
    });
  });

  group('renaming a category', () {
    Future<HomeSceenController> openCatalog() async {
      await seedCatalog(categories: [
        'Drnks',
        'Snacks'
      ], products: [
        // No barcode: identified by name, category and price.
        product(description: 'Tea', category: 'Drnks', sellingPrice: 1.5),
        product(description: 'Chips', category: 'Snacks', barcode: '2001'),
      ]);
      return register(HomeSceenController());
    }

    test('moves every item and every line being sold', () async {
      final home = await openCatalog();
      home.addToCart(home.allProducts.first);
      home.selectedCategory.value = 'Drnks';

      expect(home.renameCategory('Drnks', 'Drinks'), isTrue);

      expect(home.categories, ['Drinks', 'Snacks'],
          reason: 'renamed where it stood in the list');
      expect(home.allProducts.first.category, 'Drinks');
      expect(home.cart.single.category, 'Drinks');
      expect(home.selectedCategory.value, 'Drinks');
      expect(home.catalogProductFor(home.cart.single), isNotNull,
          reason: 'the line still finds the item it was rung up from');
    });

    test('is kept after the app restarts', () async {
      final home = await openCatalog();
      home.renameCategory('Drnks', 'Drinks');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await restartApp();

      final categories =
          LocalStorageHelpers.getJsonList('itemsBox', 'categories')!;
      expect(categories.map((c) => c['name']), ['Drinks', 'Snacks']);
      final products = LocalStorageHelpers.getJsonList('itemsBox', 'products')!;
      expect(products.first['category'], 'Drinks');
    });

    test('onto another category, or to nothing, is refused', () async {
      final home = await openCatalog();

      expect(home.renameCategory('Drnks', 'Snacks'), isFalse);
      expect(home.renameCategory('Drnks', '   '), isFalse);
      expect(home.categories, ['Drnks', 'Snacks']);
      expect(home.allProducts.first.category, 'Drnks');
    });
  });

  group('on the till', () {
    Future<HomeSceenController> openTill(WidgetTester tester) async {
      await useTabletSurface(tester);
      await withStorage(tester, () async {
        await HiveService.storeSetting('exchangeRate', 90000.0);
        await HiveService.storeSetting('tva', 0.0);
        await seedCatalog(
          categories: ['Drnks', 'Snacks'],
          products: [
            product(
                description: 'Tea',
                category: 'Drnks',
                sellingPrice: 1.50,
                quantity: 3)
              ..lowStockWarning = 5,
            product(
                description: 'Chips',
                category: 'Snacks',
                barcode: '2001',
                sellingPrice: 1.25)
              ..lowStockWarning = 5,
          ],
        );
      });
      await tester.pumpWidget(posApp());
      await settle(tester);
      return Get.find<HomeSceenController>();
    }

    testWidgets('a line running low on stock says so', (tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[0]); // Tea, 3 left
      home.addToCart(home.allProducts[1]); // Chips, 100 left
      await settle(tester);

      expect(find.text('Low stock · 3 left'), findsOneWidget);
      expect(find.textContaining('Low stock'), findsOneWidget,
          reason: 'only the line that is low');
    });

    testWidgets('double-tapping a category in the item editor renames it',
        (tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[0]);
      await settle(tester);
      await tester.longPress(find.text('Tea'));
      await settle(tester);

      // Open the list, then double-tap the misspelt category in it.
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await settle(tester);
      final inList = find.text('Drnks').last;
      await tester.tap(inList);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(inList);
      await settle(tester);

      expect(find.text('Rename Category'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Drnks'), 'Drinks');
      await act(tester, () => tester.tap(find.text('Rename')));
      await settle(tester);
      // The rename is saved once the dialog has closed, after act() returned;
      // let that write reach the disk before the test moves on.
      await act(tester, () async {});

      expect(find.text('Rename Category'), findsNothing);
      expect(home.categories, contains('Drinks'));
      expect(find.text('Drinks'), findsWidgets,
          reason: 'the editor shows the new name');

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Warn at this stock level'), '2');
      await act(tester, () => tester.tap(find.text('Save Changes')));
      await settle(tester);

      expect(find.text('Edit Item'), findsNothing,
          reason: 'the item was still found after its category was renamed');
      final tea = home.allProducts.firstWhere((p) => p.description == 'Tea');
      expect(tea.category, 'Drinks');
      expect(tea.lowStockWarning, 2);
    });
  });
}
