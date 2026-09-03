import 'package:flutter_test/flutter_test.dart';
import 'package:pos/http_client/services/clients_service.dart';
import 'package:pos/http_client/services/sales_service.dart';
import 'package:pos/modules/clients/controller/clients_controller.dart';

import '../helpers/pos_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(bootStorage);
  tearDown(tearDownStorage);

  /// The clients screen as the controller sees it. Driven directly rather
  /// than through a pumped widget tree because these assertions are about
  /// stored data, and GetX snackbars need an overlay that a fake-async pump
  /// cannot keep alive across real disk writes.
  ClientsController openClients() => ClientsController()..loadClients();

  /// Writes go through the service and the screen is then reloaded, which is
  /// what the controller does anyway. Calling the controller's own mutators
  /// here would fire a GetX snackbar, and that needs an overlay no headless
  /// test can hold up.
  Future<void> addClient(ClientsController c, String name, String phone) async {
    await ClientsService.addClient(name, phone);
    c.loadClients();
  }

  test('a new customer shows up in the list', () async {
    final clients = openClients();

    await addClient(clients, 'Rita', '03111222');

    expect(clients.clients, hasLength(1));
    expect(clients.clients.first['name'], 'Rita');
  });

  test('the customer list is still there on the next shift', () async {
    final clients = openClients();
    await addClient(clients, 'Rita', '03111222');

    await restartApp();
    clients.loadClients();

    expect(clients.clients, hasLength(1),
        reason: 'closing the app must not wipe the customer book');
  });

  test('renaming a customer keeps everyone else', () async {
    final clients = openClients();
    await addClient(clients, 'Rita', '03111222');
    await addClient(clients, 'Karim', '03999888');

    await restartApp();
    clients.loadClients();
    final id = clients.clients.first['id'] as String;
    await ClientsService.updateClient(id, 'Rita H', '03111222');
    clients.loadClients();

    expect(clients.clients, hasLength(2));
    expect(clients.clients.first['name'], 'Rita H');
  });

  test('an unpaid tab appears on the customer balance', () async {
    final clients = openClients();
    await addClient(clients, 'Zeina', '03555444');
    final id = clients.clients.first['id'] as String;

    await SalesService.saveTab(id, [], 25.0, 2250000.0, 90000.0, 0.0);

    expect(clients.getClientBalance(id), 25.0);
  });

  test('the balance survives a restart', () async {
    final clients = openClients();
    await addClient(clients, 'Zeina', '03555444');
    final id = clients.clients.first['id'] as String;
    await SalesService.saveTab(id, [], 25.0, 2250000.0, 90000.0, 0.0);

    await restartApp();

    expect(clients.getClientBalance(id), 25.0,
        reason: 'a debt does not vanish when the app restarts');
  });

  test('settling a tab clears the balance', () async {
    final clients = openClients();
    await addClient(clients, 'Zeina', '03555444');
    final id = clients.clients.first['id'] as String;
    await SalesService.saveTab(id, [], 25.0, 2250000.0, 90000.0, 0.0);
    final tabId = SalesService.getClientTabs(id).keys.first;

    await SalesService.markTabAsPaid(tabId);
    clients.loadClientTabs(id);

    expect(clients.getClientBalance(id), 0.0);
    expect(ClientsService.getClientStats(id)['openTabs'], 0);
  });

  test('searching finds a customer by name and by phone', () async {
    final clients = openClients();
    await addClient(clients, 'Rita', '03111222');
    await addClient(clients, 'Karim', '03999888');

    expect(clients.searchClients('rita'), hasLength(1));
    expect(clients.searchClients('03999'), hasLength(1));
    expect(clients.searchClients('nobody'), isEmpty);
  });

  test('two customers with the same name stay distinct', () async {
    final clients = openClients();
    await addClient(clients, 'Ali', '03111111');
    await addClient(clients, 'Ali', '03222222');

    expect(clients.clients, hasLength(2));
    final ids = clients.clients.map((c) => c['id']).toSet();
    expect(ids, hasLength(2), reason: 'ids must be unique');
  });

  test('deleting a customer removes only that customer', () async {
    final clients = openClients();
    await addClient(clients, 'Rita', '03111222');
    await addClient(clients, 'Karim', '03999888');
    final id = clients.clients.first['id'] as String;

    await ClientsService.deleteClient(id);
    clients.loadClients();

    expect(clients.clients, hasLength(1));
    expect(clients.clients.first['name'], 'Karim');
  });

  test('a blank customer is rejected', () async {
    final clients = openClients();

    await addClient(clients, '', '');

    expect(clients.clients, isEmpty,
        reason: 'a nameless customer cannot be put on a tab later');
  });
}
