import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos/core/routes/paths.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/http_client/local_storage/hive_service.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';
import 'package:pos/modules/items/add_edit_item/controller/add_edit_item_controller.dart';

import '../helpers/pos_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(bootStorage);
  tearDown(tearDownStorage);

  Future<HomeSceenController> openTill(WidgetTester tester) async {
    await useTabletSurface(tester);
    await withStorage(tester, () async {
      await HiveService.storeSetting('tva', 11.0);
      await seedCatalog(
        categories: ['Drinks', 'Snacks'],
        products: [
          product(
              description: 'Espresso',
              category: 'Drinks',
              barcode: '1001',
              sellingPrice: 2.50),
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

  Future<AddEditItemController> openItemForm(
      WidgetTester tester, Object? arguments) async {
    Get.toNamed(Paths.addEditItemScreen, arguments: arguments);
    await settle(tester);
    return Get.find<AddEditItemController>();
  }

  group('adding an item', () {
    // The save path itself (validation + persistence) is exercised through
    // HomeSceenController in the other groups: driving the Form's validator
    // needs the widget-test zone, which cannot coexist with the real async
    // that Hive's disk write requires.
    testWidgets('the form opens with the store VAT already filled in',
        (tester) async {
      await openTill(tester);
      final form = await openItemForm(tester, 'Drinks');

      expect(form.tvaPercentController.text, '11.0');
    });

    testWidgets('a form left blank still saves', (tester) async {
      final home = await openTill(tester);
      final form = await openItemForm(tester, null);

      form.descriptionController.text = 'Gum';
      form.tvaPercentController.clear();
      await act(
          tester, () => form.saveNewItem(newItem: form.newItemDataBind()));
      await settle(tester);

      expect(home.allProducts, hasLength(3),
          reason: 'no field on the item form is mandatory');
      expect(home.allProducts.last.description, 'Gum');
      expect(home.allProducts.last.sellingPrice, isNull);
    });

    testWidgets('opening the form from the till preselects the category',
        (tester) async {
      await openTill(tester);
      final form = await openItemForm(tester, 'Snacks');

      expect(form.selectedCategory.value, 'Snacks');
    });
  });

  group('editing an item', () {
    testWidgets('the form opens filled in with the item being edited',
        (tester) async {
      final home = await openTill(tester);
      final espresso = home.allProducts.first;

      final form = await openItemForm(tester, espresso);

      expect(form.isEditing, isTrue,
          reason: 'the edit button must open an edit, not a blank add');
      expect(form.descriptionController.text, 'Espresso');
      expect(form.barcodeController.text, '1001');
      expect(form.sellingPriceController.text, '2.5');
      expect(form.selectedCategory.value, 'Drinks');
    });

    testWidgets('saving an edit changes the item instead of duplicating it',
        (tester) async {
      final home = await openTill(tester);
      final espresso = home.allProducts.first;
      final form = await openItemForm(tester, espresso);

      form.sellingPriceController.text = '2.95';
      await act(tester,
          () => form.saveEditedItem(editedItem: form.editedItemDataBind()));
      await settle(tester);

      expect(home.allProducts, hasLength(2),
          reason: 'an edit must not add a second row');
      expect(home.allProducts.first.sellingPrice, 2.95);
    });

    testWidgets('a price change survives a restart', (tester) async {
      final home = await openTill(tester);
      final form = await openItemForm(tester, home.allProducts.first);
      form.sellingPriceController.text = '2.95';
      await act(tester,
          () => form.saveEditedItem(editedItem: form.editedItemDataBind()));

      await withStorage(tester, restartApp);
      home.loadProducts();

      expect(home.allProducts.first.sellingPrice, 2.95);
    });

    testWidgets('renaming an item does not create a second one',
        (tester) async {
      final home = await openTill(tester);
      final form = await openItemForm(tester, home.allProducts.first);

      form.descriptionController.text = 'Espresso Doppio';
      await act(tester,
          () => form.saveEditedItem(editedItem: form.editedItemDataBind()));
      await settle(tester);

      expect(home.allProducts, hasLength(2));
      expect(home.allProducts.map((p) => p.description),
          containsAll(['Espresso Doppio', 'Chips']));
    });
  });

  group('the stock screen', () {
    Future<void> openStock(WidgetTester tester) async {
      await openTill(tester);
      Get.toNamed(Paths.itemListingScreen);
      await settle(tester);
    }

    Finder search() =>
        find.widgetWithText(TextField, 'Search by name or barcode...');

    testWidgets('lists every item without opening a category first',
        (tester) async {
      await openStock(tester);
      expect(find.text('Espresso'), findsOneWidget);
      expect(find.text('Chips'), findsOneWidget);
    });

    testWidgets('finds an item by its name', (tester) async {
      await openStock(tester);
      await tester.enterText(search(), 'chip');
      await settle(tester);

      expect(find.text('Chips'), findsOneWidget);
      expect(find.text('Espresso'), findsNothing);
    });

    testWidgets('finds an item by its barcode', (tester) async {
      await openStock(tester);
      await tester.enterText(search(), '1001');
      await settle(tester);

      expect(find.text('Espresso'), findsOneWidget);
      expect(find.text('Chips'), findsNothing);
    });

    testWidgets('every row offers edit and delete', (tester) async {
      await openStock(tester);
      expect(find.byTooltip('Edit'), findsNWidgets(2));
      expect(find.byTooltip('Delete'), findsNWidgets(2));
    });
  });

  group('removing things', () {
    testWidgets('deleting an item removes only that item', (tester) async {
      final home = await openTill(tester);

      await act(tester, () => home.deleteProduct(home.allProducts.first));

      expect(home.allProducts, hasLength(1));
      expect(home.allProducts.single.description, 'Chips');
    });

    testWidgets('deleting a category takes its items with it', (tester) async {
      final home = await openTill(tester);

      await act(tester, () => home.deleteCategory('Drinks'));

      expect(home.categories, isNot(contains('Drinks')));
      expect(
          home.allProducts.map((p) => p.category), isNot(contains('Drinks')));
    });

    testWidgets('a deletion survives a restart', (tester) async {
      final home = await openTill(tester);
      await act(tester, () => home.deleteProduct(home.allProducts.first));

      await withStorage(tester, restartApp);
      home.loadProducts();

      expect(home.allProducts, hasLength(1));
    });
  });

  group('two products that share a name', () {
    testWidgets('both stay in the catalog and both can be sold',
        (tester) async {
      final home = await openTill(tester);
      await act(
          tester,
          () => home.addProduct(AddEditItemModel(
              description: 'Water',
              category: 'Drinks',
              barcode: '3001',
              sellingPrice: 1.00,
              quantity: 10)));
      await act(
          tester,
          () => home.addProduct(AddEditItemModel(
              description: 'Water',
              category: 'Drinks',
              barcode: '3002',
              sellingPrice: 2.00,
              quantity: 10)));

      expect(home.allProducts, hasLength(4));

      await act(tester, () => home.deleteProduct(home.allProducts[2]));

      expect(home.allProducts, hasLength(3),
          reason: 'deleting one must not take the other with it');
      expect(home.allProducts.last.barcode, '3002');
    });
  });
}
