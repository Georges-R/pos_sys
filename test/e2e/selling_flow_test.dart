import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos/core/routes/paths.dart';
import 'package:pos/http_client/local_storage/hive_service.dart';
import 'package:pos/http_client/services/sales_service.dart';
import 'package:pos/modules/checkout/controller/checkout_controller.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';

import '../helpers/pos_harness.dart';

/// Drives the real GetMaterialApp through real routes and real bindings, so
/// GetX dependency lifetimes behave exactly as they do on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(bootStorage);
  tearDown(tearDownStorage);

  Future<HomeSceenController> openTill(
    WidgetTester tester, {
    double exchangeRate = 90000,
    double tva = 0,
  }) async {
    await useTabletSurface(tester);
    await withStorage(tester, () async {
      await HiveService.storeSetting('exchangeRate', exchangeRate);
      await HiveService.storeSetting('tva', tva);
      await seedCatalog(
        categories: ['Drinks', 'Snacks'],
        products: [
          product(
              description: 'Espresso',
              category: 'Drinks',
              barcode: '1001',
              sellingPrice: 2.50),
          product(
              description: 'Latte',
              category: 'Drinks',
              barcode: '1002',
              sellingPrice: 4.00),
          product(
              description: 'Chips',
              category: 'Snacks',
              barcode: '2001',
              sellingPrice: 1.25),
        ],
      );
    });
    await tester.pumpWidget(posApp());
    await settle(tester);
    return Get.find<HomeSceenController>();
  }

  Future<CheckoutController> goToCheckout(
      WidgetTester tester, HomeSceenController home) async {
    Get.toNamed(Paths.checkout, arguments: home.cart);
    await settle(tester);
    return Get.find<CheckoutController>();
  }

  group('the product grid', () {
    testWidgets('shows the catalog before any category is picked',
        (tester) async {
      final home = await openTill(tester);
      expect(home.allProducts, hasLength(3));
      expect(home.filteredProducts, isNotEmpty,
          reason: 'a cashier opening the till must see something to sell');
    });

    testWidgets('narrows to the picked category', (tester) async {
      final home = await openTill(tester);
      home.selectedCategory.value = 'Drinks';
      expect(home.filteredProducts.map((p) => p.description),
          containsAll(['Espresso', 'Latte']));
      expect(home.filteredProducts.map((p) => p.description),
          isNot(contains('Chips')));
    });
  });

  group('the cart', () {
    testWidgets('adding the same product twice makes one line of two',
        (tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[0]);
      home.addToCart(home.allProducts[0]);

      expect(home.cart, hasLength(1));
      expect(home.cart.first.quantity, 2);
      expect(home.total, 5.00);
    });

    testWidgets('adding to the cart never touches the catalog stock',
        (tester) async {
      final home = await openTill(tester);
      final stockBefore = home.allProducts[0].quantity;

      home.addToCart(home.allProducts[0]);
      home.addToCart(home.allProducts[0]);

      expect(home.allProducts[0].quantity, stockBefore,
          reason: 'the catalog row must not become the cart line');
    });

    testWidgets('two different products with the same name stay separate lines',
        (tester) async {
      final home = await openTill(tester);
      // A real catalog carries "Water" from two suppliers at two prices.
      home.allProducts.add(product(
          description: 'Water',
          category: 'Drinks',
          barcode: '3001',
          sellingPrice: 1.00));
      home.allProducts.add(product(
          description: 'Water',
          category: 'Drinks',
          barcode: '3002',
          sellingPrice: 2.00));

      home.addToCart(home.allProducts[3]);
      home.addToCart(home.allProducts[4]);

      expect(home.cart, hasLength(2),
          reason: 'two distinct products are two distinct cart lines');
      expect(home.total, 3.00);
    });

    testWidgets('decrementing to zero removes the line', (tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[0]);
      home.updateQuantity(0, -1);
      expect(home.cart, isEmpty);
      expect(home.total, 0);
    });

    testWidgets('a barcode scan adds the matching product', (tester) async {
      final home = await openTill(tester);
      expect(home.findAndAddByBarcode('2001'), isTrue);
      expect(home.cart.single.description, 'Chips');
    });

    testWidgets('an unknown barcode adds nothing', (tester) async {
      final home = await openTill(tester);
      expect(home.findAndAddByBarcode('9999'), isFalse);
      expect(home.cart, isEmpty);
    });
  });

  group('scanning an item the catalog does not have', () {
    Future<HomeSceenController> scanUnknown(WidgetTester tester,
        {String code = '5005'}) async {
      final home = await openTill(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Scan barcode here'), code);
      await settle(tester);
      return home;
    }

    testWidgets('warns instead of failing silently', (tester) async {
      await scanUnknown(tester);
      expect(find.text('Item not found'), findsOneWidget);
      expect(find.textContaining('5005'), findsWidgets,
          reason: 'the cashier has to see which code came up empty');
    });

    testWidgets('backing out leaves the catalog and the sale alone',
        (tester) async {
      final home = await scanUnknown(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(find.text('Item not found'), findsNothing);
      expect(home.allProducts, hasLength(3));
      expect(home.cart, isEmpty);
    });

    testWidgets('creating the item rings it up without leaving the till',
        (tester) async {
      final home = await scanUnknown(tester);
      await tester.tap(find.text('Create item'));
      await settle(tester);

      expect(find.text('New Item'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '5005'), findsOneWidget,
          reason: 'the scanned code is pre-filled, not retyped');

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter item name'),
          'Energy Drink');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      await tester.tap(find.text('Drinks').last);
      await settle(tester);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter selling price'), '3.5');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Enter stock quantity'), '24');
      await settle(tester);

      // The save writes to Hive. A write started inside the fake-async zone
      // never completes, and teardown then blocks on it forever.
      await act(tester, () => tester.tap(find.text('Save & Add to Sale')));
      await settle(tester);

      expect(find.text('New Item'), findsNothing);
      expect(home.allProducts, hasLength(4));
      final created = home.findByBarcode('5005');
      expect(created, isNotNull);
      expect(created!.description, 'Energy Drink');
      expect(created.category, 'Drinks');
      expect(created.sellingPrice, 3.50);
      expect(created.quantity, 24,
          reason: 'the stock entered in the dialog is the stock on file');
      expect(home.cart.single.description, 'Energy Drink',
          reason: 'the scan that opened the dialog was a sale in progress');
      expect(home.total, 3.50);
    });

    testWidgets('nothing but the scanned barcode is needed', (tester) async {
      final home = await scanUnknown(tester);
      await tester.tap(find.text('Create item'));
      await settle(tester);

      await act(tester, () => tester.tap(find.text('Save & Add to Sale')));
      await settle(tester);

      expect(find.text('New Item'), findsNothing,
          reason: 'blank fields must not block the save');
      final created = home.findByBarcode('5005');
      expect(created, isNotNull);
      expect(created!.sellingPrice, 0);
      expect(created.quantity, 0);
      expect(created.category, isNull);
      expect(home.cart.single.barcode, '5005');
    });

    testWidgets('the quick-created item survives a restart', (tester) async {
      final home = await openTill(tester);
      await withStorage(tester, () async {
        home.quickCreateProduct(
          description: 'Energy Drink',
          barcode: '5005',
          sellingPrice: 3.5,
          category: 'Drinks',
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await withStorage(tester, restartApp);

      final reopened = register(HomeSceenController());
      reopened.onInit();
      expect(reopened.findByBarcode('5005')?.description, 'Energy Drink');
    });

    testWidgets('a category typed in the dialog joins the catalog',
        (tester) async {
      final home = await openTill(tester);
      await withStorage(tester, () async {
        home.quickCreateProduct(
          description: 'Batteries',
          barcode: '7007',
          sellingPrice: 5,
          category: 'Hardware',
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });

      expect(home.categories, contains('Hardware'),
          reason:
              'an item filed under a category the till cannot show is lost');
    });

    testWidgets('a barcode already in use is refused', (tester) async {
      final home = await openTill(tester);
      final created = home.quickCreateProduct(
        description: 'Not Espresso',
        barcode: '1001',
        sellingPrice: 9.99,
      );

      expect(created, isNull,
          reason: 'two rows on one barcode make edits and deletes ambiguous');
      expect(home.allProducts, hasLength(3));
      expect(home.findByBarcode('1001')?.description, 'Espresso');
    });
  });

  group('the till keeps the scanner ready', () {
    Finder scanner() => find.widgetWithText(TextField, 'Scan barcode here');

    bool scannerHasFocus(WidgetTester tester) =>
        tester.widget<TextField>(scanner()).focusNode!.hasFocus;

    testWidgets('after the cart buttons are used', (tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[0]);
      home.addToCart(home.allProducts[2]);
      await settle(tester);

      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await settle(tester);
      expect(scannerHasFocus(tester), isTrue);

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await settle(tester);
      expect(scannerHasFocus(tester), isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await settle(tester);
      expect(scannerHasFocus(tester), isTrue);
      expect(home.cart.single.description, 'Chips');
    });

    testWidgets('after a scan', (tester) async {
      final home = await openTill(tester);
      await tester.enterText(scanner(), '1001\n');
      await settle(tester);

      expect(home.cart.single.description, 'Espresso');
      expect(scannerHasFocus(tester), isTrue);
    });

    testWidgets('after the clear-cart prompt closes', (tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[0]);
      await settle(tester);

      await tester.tap(find.text('Clear cart'));
      await settle(tester);
      await tester.tap(find.text('Clear'));
      await settle(tester);

      expect(home.cart, isEmpty);
      expect(scannerHasFocus(tester), isTrue);
    });
  });

  group('editing an item from the cart', () {
    Future<HomeSceenController> openEditor(WidgetTester tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[1]); // Latte 4.00
      home.addToCart(home.allProducts[1]);
      await settle(tester);
      await tester.longPress(find.text('Latte'));
      await settle(tester);
      return home;
    }

    testWidgets('a long press opens every field of the item', (tester) async {
      await openEditor(tester);

      expect(find.text('Edit Item'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Latte'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '1002'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '100'), findsOneWidget,
          reason: 'the stock on file, not the two being sold');
      for (final label in [
        'Category',
        'Cost Price',
        'TVA %',
        'Price After TVA',
        'Profit %',
        'Selling Price',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('saving updates the catalog and the line being sold',
        (tester) async {
      final home = await openEditor(tester);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Latte'), 'Oat Latte');
      await tester.enterText(find.widgetWithText(TextFormField, '4.0'), '4.5');
      await tester.enterText(find.widgetWithText(TextFormField, '100'), '80');
      await settle(tester);
      await act(tester, () => tester.tap(find.text('Save Changes')));
      await settle(tester);

      expect(find.text('Edit Item'), findsNothing);
      final row = home.findByBarcode('1002')!;
      expect(row.description, 'Oat Latte');
      expect(row.sellingPrice, 4.50);
      expect(row.quantity, 80);
      expect(home.allProducts, hasLength(3), reason: 'edited, not duplicated');

      final line = home.cart.single;
      expect(line.description, 'Oat Latte');
      expect(line.quantity, 2, reason: 'the count being sold is untouched');
      expect(home.total, 9.00);
      expect(
          tester
              .widget<TextField>(
                  find.widgetWithText(TextField, 'Scan barcode here'))
              .focusNode!
              .hasFocus,
          isTrue);
    });

    testWidgets('blank fields are saved, not refused', (tester) async {
      final home = await openEditor(tester);

      await tester.enterText(find.widgetWithText(TextFormField, '4.0'), '');
      await tester.enterText(find.widgetWithText(TextFormField, '100'), '');
      await settle(tester);
      await act(tester, () => tester.tap(find.text('Save Changes')));
      await settle(tester);

      expect(find.text('Edit Item'), findsNothing);
      final row = home.findByBarcode('1002')!;
      expect(row.sellingPrice, 0);
      expect(row.quantity, 0);
    });

    testWidgets('a barcode another item uses is refused', (tester) async {
      final home = await openEditor(tester);

      await tester.enterText(
          find.widgetWithText(TextFormField, '1002'), '1001');
      await settle(tester);
      await tester.tap(find.text('Save Changes'));
      await settle(tester);

      expect(
          find.text('Another item already uses this barcode'), findsOneWidget);
      expect(home.findByBarcode('1001')?.description, 'Espresso');
      expect(home.findByBarcode('1002')?.description, 'Latte');
    });
  });

  group('checkout', () {
    testWidgets('the LBP total is the USD total at the configured rate',
        (tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[1]); // Latte 4.00
      final checkout = await goToCheckout(tester, home);

      expect(checkout.totalUSD.value, 4.00);
      expect(checkout.totalLBP.value, 4.00 * 90000);
    });

    testWidgets('the customer is charged the VAT the store configured',
        (tester) async {
      final home = await openTill(tester, tva: 11);
      home.addToCart(home.allProducts[1]); // Latte 4.00, VAT 11%
      final checkout = await goToCheckout(tester, home);

      expect(checkout.totalUSD.value, closeTo(4.44, 0.001),
          reason: '4.00 + 11% VAT = 4.44');
    });

    testWidgets('paying cash records the sale and empties the till',
        (tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[0]);
      final checkout = await goToCheckout(tester, home);

      await withStorage(tester, checkout.payNow);
      await settle(tester);

      expect(SalesService.getAllSales(), hasLength(1),
          reason: 'the sale must reach the ledger');
      expect(home.cart, isEmpty, reason: 'the till must be cleared');
    });

    testWidgets('a sale is never recorded for an empty cart', (tester) async {
      final home = await openTill(tester);
      final checkout = await goToCheckout(tester, home);

      await withStorage(tester, checkout.payNow);
      await settle(tester);

      expect(SalesService.getAllSales(), isEmpty,
          reason: 'an accidental double-tap must not book a \$0 sale');
    });

    testWidgets('the recorded sale total matches what the customer was shown',
        (tester) async {
      final home = await openTill(tester, tva: 11);
      home.addToCart(home.allProducts[1]);
      final checkout = await goToCheckout(tester, home);
      final shown = checkout.totalUSD.value;

      await withStorage(tester, checkout.payNow);
      await settle(tester);

      final sale = SalesService.getAllSales().values.first as Map;
      expect(sale['totalUSD'], shown);
    });

    testWidgets('editing a quantity at checkout does not rewrite the catalog',
        (tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[0]);
      final checkout = await goToCheckout(tester, home);

      checkout.updateQuantity(0, 7);

      expect(home.allProducts[0].quantity, 100,
          reason: 'the catalog row is not the cart line');
    });

    testWidgets('a failed save does not silently pass as a completed sale',
        (tester) async {
      final home = await openTill(tester);
      home.addToCart(home.allProducts[0]);
      final checkout = await goToCheckout(tester, home);

      // The ledger is unavailable — a power blip, a corrupted box.
      await withStorage(tester, HiveService.close);

      await withStorage(tester, checkout.payNow);
      await settle(tester);

      expect(home.cart, isNotEmpty,
          reason:
              'if the sale was not recorded the cashier must still have the cart');

      await withStorage(tester, restartApp);
    });
  });

  group('money arithmetic', () {
    testWidgets('a long receipt totals to the cent', (tester) async {
      final home = await openTill(tester);
      home.allProducts.add(
          product(description: 'Gum', category: 'Snacks', sellingPrice: 0.10));
      for (var i = 0; i < 10; i++) {
        home.addToCart(home.allProducts[3]);
      }
      expect(home.total, 1.00,
          reason: '10 x 0.10 must be exactly 1.00 on the receipt');
    });
  });
}
