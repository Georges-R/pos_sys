import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/http_client/local_storage/hive_service.dart';
import 'package:pos/http_client/local_storage/local_storage_helpers.dart';
import 'package:pos/http_client/services/clients_service.dart';
import 'package:pos/http_client/services/excel_service.dart';
import 'package:pos/http_client/services/sales_service.dart';
import 'package:pos/modules/settings/controller/settings_controller.dart';

import '../helpers/pos_harness.dart';

/// Exercises the Excel backup the way the Settings screen does, minus the
/// file picker: build the workbook, wipe the shop, restore from it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(bootStorage);
  tearDown(tearDownStorage);

  Future<void> seedShop() async {
    await HiveService.storeSetting('storeName', 'Corner Shop');
    await HiveService.storeSetting('exchangeRate', 89000.0);
    await HiveService.storeSetting('tva', 11.0);
    await ClientsService.addClient('Rita Haddad', '03111222');
    await ClientsService.addClient('Karim', '');
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
    await SalesService.saveSale([
      {'description': 'Espresso', 'selling_price': 2.5, 'quantity': 2},
    ], 5.0, 445000.0, 89000.0, 11.0);
  }

  Future<void> wipeShop() async {
    for (final box in kPosBoxes) {
      await HiveService.clearBox(box);
    }
  }

  test('a backup restores the catalog', () async {
    await seedShop();
    final workbook = await ExcelService.buildWorkbook();

    await wipeShop();
    expect(await ExcelService.applyWorkbook(workbook), isTrue);

    final products = LocalStorageHelpers.getJsonList('itemsBox', 'products');
    expect(products, isNotNull);
    expect(products!.map((p) => p['description']),
        containsAll(['Espresso', 'Chips']));
    expect(
        products
            .firstWhere((p) => p['description'] == 'Espresso')['selling_price'],
        2.5);
  });

  test('a backup restores the categories', () async {
    await seedShop();
    final workbook = await ExcelService.buildWorkbook();

    await wipeShop();
    await ExcelService.applyWorkbook(workbook);

    final categories =
        LocalStorageHelpers.getJsonList('itemsBox', 'categories') ?? [];
    expect(categories.map((c) => c['name']), containsAll(['Drinks', 'Snacks']));
  });

  test('a backup restores the customers, including one with no phone',
      () async {
    await seedShop();
    final workbook = await ExcelService.buildWorkbook();

    await wipeShop();
    await ExcelService.applyWorkbook(workbook);

    final clients = ClientsService.getAllClients();
    expect(
        clients.map((c) => c['name']), containsAll(['Rita Haddad', 'Karim']));
  });

  test('a backup restores the sales ledger', () async {
    await seedShop();
    final workbook = await ExcelService.buildWorkbook();

    await wipeShop();
    await ExcelService.applyWorkbook(workbook);

    final sales = SalesService.getAllSales();
    expect(sales, hasLength(1));
    expect((sales.values.first as Map)['totalUSD'], 5.0);
  });

  test('restored settings are still numbers, and the app still starts',
      () async {
    await seedShop();
    final workbook = await ExcelService.buildWorkbook();

    await wipeShop();
    await ExcelService.applyWorkbook(workbook);

    final settings = SettingsController()..loadSettings();
    expect(settings.exchangeRate.value, 89000.0);
    expect(settings.tva.value, 11.0);
    expect(settings.storeName.value, 'Corner Shop');
  });

  test('a backup taken after a restart still contains everything', () async {
    await seedShop();
    await restartApp();

    final workbook = await ExcelService.buildWorkbook();
    await wipeShop();
    await ExcelService.applyWorkbook(workbook);

    expect(ClientsService.getAllClients(), hasLength(2),
        reason: 'clients written in an earlier session must be backed up');
    expect(SalesService.getAllSales(), hasLength(1),
        reason: 'sales written in an earlier session must be backed up');
  });

  group('a damaged or foreign file', () {
    test('a workbook with the columns reordered still imports correctly',
        () async {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['Items'];
      sheet.appendRow(['Selling Price', 'Description', 'Category', 'Barcode']);
      sheet.appendRow([3.75, 'Mocha', 'Drinks', '1009']);

      expect(await ExcelService.applyWorkbook(excel), isTrue);

      final products =
          LocalStorageHelpers.getJsonList('itemsBox', 'products') ?? [];
      expect(products, hasLength(1));
      expect(products.first['description'], 'Mocha',
          reason: 'columns are matched by header, not by position');
      expect(products.first['selling_price'], 3.75);
    });

    test('an empty Items sheet does not erase the catalog', () async {
      await seedShop();
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      excel['Items'].appendRow(['Description', 'Category', 'Selling Price']);

      await ExcelService.applyWorkbook(excel);

      expect(
          LocalStorageHelpers.getJsonList('itemsBox', 'products'), hasLength(2),
          reason: 'an import with no rows must not wipe the shop');
    });

    test('an empty Clients sheet does not erase the customer book', () async {
      await seedShop();
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      excel['Clients'].appendRow(['ID', 'Name', 'Phone']);

      await ExcelService.applyWorkbook(excel);

      expect(ClientsService.getAllClients(), hasLength(2),
          reason: 'an import with no rows must not wipe the customer book');
    });

    test('a workbook that is not a POS backup is refused', () async {
      final excel = Excel.createExcel();

      expect(await ExcelService.applyWorkbook(excel), isFalse,
          reason: 'the user must not be told an unrelated file imported fine');
    });

    test('text where a price belongs does not become a silent zero', () async {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');
      final sheet = excel['Items'];
      sheet.appendRow(['Description', 'Category', 'Selling Price', 'Quantity']);
      sheet.appendRow(['Mocha', 'Drinks', '\$3.75', '12 units']);

      await ExcelService.applyWorkbook(excel);

      final products =
          LocalStorageHelpers.getJsonList('itemsBox', 'products') ?? [];
      expect(products.first['selling_price'], 3.75);
      expect(products.first['quantity'], 12);
    });
  });
}
