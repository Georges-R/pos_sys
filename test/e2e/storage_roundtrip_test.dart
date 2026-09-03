import 'package:flutter_test/flutter_test.dart';
import 'package:pos/http_client/services/clients_service.dart';
import 'package:pos/http_client/services/sales_service.dart';

import '../helpers/pos_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(bootStorage);
  tearDown(tearDownStorage);

  group('clients survive an app restart', () {
    test('a client added today is still there tomorrow', () async {
      await ClientsService.addClient('Rita Haddad', '03111222');
      expect(ClientsService.getAllClients(), hasLength(1));

      await restartApp();

      final clients = ClientsService.getAllClients();
      expect(clients, hasLength(1),
          reason: 'clients must reload from disk after a restart');
      expect(clients.first['name'], 'Rita Haddad');
    });

    test('a client can still be looked up by id after a restart', () async {
      await ClientsService.addClient('Karim Nassar', '03999888');
      final id = ClientsService.getAllClients().first['id'] as String;

      await restartApp();

      expect(ClientsService.getClientById(id), isNotNull);
    });

    test('editing a client after a restart keeps the other clients', () async {
      await ClientsService.addClient('A', '1');
      await ClientsService.addClient('B', '2');
      final idB = ClientsService.getAllClients()[1]['id'] as String;

      await restartApp();
      await ClientsService.updateClient(idB, 'B renamed', '2');

      final clients = ClientsService.getAllClients();
      expect(clients, hasLength(2), reason: 'the edit must not drop client A');
      expect(clients[1]['name'], 'B renamed');
    });
  });

  group('tabs and balances', () {
    test('an open tab shows up in the client balance', () async {
      await ClientsService.addClient('Zeina', '03555444');
      final id = ClientsService.getAllClients().first['id'] as String;

      await SalesService.saveTab(
          id,
          [
            {'description': 'Coffee', 'selling_price': 3.0, 'quantity': 2},
          ],
          6.0,
          540000.0,
          90000.0,
          0.0);

      expect(ClientsService.getClientBalance(id), 6.0);
    });

    test('an open tab still shows up in the balance after a restart', () async {
      await ClientsService.addClient('Zeina', '03555444');
      final id = ClientsService.getAllClients().first['id'] as String;
      await SalesService.saveTab(
          id,
          [
            {'description': 'Coffee', 'selling_price': 3.0, 'quantity': 2},
          ],
          6.0,
          540000.0,
          90000.0,
          0.0);

      await restartApp();

      expect(ClientsService.getClientBalance(id), 6.0,
          reason: 'a debt does not disappear because the app was closed');
    });

    test('paying a tab off clears the balance', () async {
      await ClientsService.addClient('Zeina', '03555444');
      final id = ClientsService.getAllClients().first['id'] as String;
      await SalesService.saveTab(id, [], 6.0, 540000.0, 90000.0, 0.0);
      final tabId = SalesService.getClientTabs(id).keys.first;

      await SalesService.markTabAsPaid(tabId);

      expect(ClientsService.getClientBalance(id), 0.0);
    });
  });

  group('the sales ledger holds sales and nothing else', () {
    test('client records do not leak into the sales history', () async {
      await ClientsService.addClient('Rita', '03111222');
      await SalesService.saveSale([], 10.0, 900000.0, 90000.0, 0.0);

      final sales = SalesService.getAllSales();
      expect(sales.values.every((s) => s is Map && s['id'] != null), isTrue,
          reason: 'every entry in the sales box must be a sale');
      expect(sales, hasLength(1));
    });

    test('a date-range report over real history does not blow up', () async {
      await ClientsService.addClient('Rita', '03111222');
      await SalesService.saveSale([], 10.0, 900000.0, 90000.0, 0.0);

      expect(
        () => SalesService.getSalesByDateRange(
          DateTime(2000),
          DateTime(2100),
        ),
        returnsNormally,
      );
    });

    test('a sale saved today is inside a range that covers today', () async {
      await SalesService.saveSale([], 10.0, 900000.0, 90000.0, 0.0);

      final range = SalesService.getSalesByDateRange(
        DateTime(2000),
        DateTime(2100),
      );
      expect(range, hasLength(1));
    });

    test('sales survive a restart and stay readable', () async {
      await SalesService.saveSale([
        {'description': 'Water', 'selling_price': 1.5, 'quantity': 4},
      ], 6.0, 540000.0, 90000.0, 0.0);

      await restartApp();

      final sales = SalesService.getAllSales();
      expect(sales, hasLength(1));
      final sale = sales.values.first as Map;
      expect(sale['totalUSD'], 6.0);
      expect((sale['items'] as List).first['description'], 'Water');
    });
  });
}
