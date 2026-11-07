import 'package:get/get.dart';
import 'package:pos/core/helpers/notify.dart';
import 'package:pos/http_client/services/clients_service.dart';
import 'package:pos/http_client/services/sales_service.dart';

class ClientsController extends GetxController {
  RxList<Map<String, dynamic>> clients = <Map<String, dynamic>>[].obs;
  RxString selectedClientId = ''.obs;
  RxString selectedClientName = ''.obs;

  /// Tabs and stats are kept per customer. A single shared map meant that
  /// expanding a second customer replaced what the first customer's panel was
  /// showing, so two open panels displayed the same person's debt.
  final RxMap<String, Map<String, dynamic>> tabsByClient =
      <String, Map<String, dynamic>>{}.obs;
  final RxMap<String, Map<String, dynamic>> statsByClient =
      <String, Map<String, dynamic>>{}.obs;

  /// Bumped whenever the tab ledger changes, so balances shown outside a
  /// panel recompute instead of sitting stale until the screen is reopened.
  final RxInt ledgerRevision = 0.obs;

  Map<String, dynamic> tabsOf(String clientId) =>
      tabsByClient[clientId] ?? const <String, dynamic>{};

  /// The tabs the customer still owes on. Paid tabs stay in the ledger for
  /// the sales history, but listing them here meant a converted tab never
  /// left the panel, so converting looked like it had done nothing.
  List<Map<String, dynamic>> openTabsOf(String clientId) => tabsOf(clientId)
      .values
      .whereType<Map>()
      .where((tab) => tab['status'] == 'open')
      .map((tab) => Map<String, dynamic>.from(tab))
      .toList();

  Map<String, dynamic> statsOf(String clientId) =>
      statsByClient[clientId] ??
      const <String, dynamic>{
        'totalTabs': 0,
        'openTabs': 0,
        'totalOwed': 0.0,
        'closedTabs': 0,
      };

  @override
  void onInit() {
    super.onInit();
    loadClients();
  }

  void loadClients() {
    try {
      final loadedClients = ClientsService.getAllClients();
      clients.assignAll(loadedClients);
    } catch (e) {
      Notify.error('Error', 'Failed to load clients: $e');
    }
  }

  void loadClientTabs(String clientId) {
    try {
      selectedClientId.value = clientId;

      final client = ClientsService.getClientById(clientId);
      if (client != null && client.isNotEmpty) {
        selectedClientName.value = client['name'] ?? 'Unknown';
      } else {
        selectedClientName.value = 'Unknown Client';
        Notify.error('Warning', 'Client not found');
        return;
      }

      tabsByClient[clientId] = SalesService.getClientTabs(clientId);
      statsByClient[clientId] = ClientsService.getClientStats(clientId);
    } catch (e) {
      Notify.error('Error', 'Failed to load client tabs: $e');
    }
  }

  /// Reloads every panel that has been opened. Reloading only
  /// [selectedClientId] refreshed whichever customer was expanded last, not
  /// necessarily the one whose tab just changed.
  void _refreshLedger() {
    for (final clientId in tabsByClient.keys.toList()) {
      tabsByClient[clientId] = SalesService.getClientTabs(clientId);
      statsByClient[clientId] = ClientsService.getClientStats(clientId);
    }
    ledgerRevision.value++;
  }

  Future<void> deleteTab(String tabId) async {
    if (tabId.isEmpty) return;
    try {
      await SalesService.deleteTab(tabId);
      _refreshLedger();
      Notify.success('Success', 'Tab deleted successfully');
    } catch (e) {
      Notify.error('Error', 'Failed to delete tab: $e');
    }
  }

  Future<void> convertTabToSale(String tabId) async {
    if (tabId.isEmpty) return;
    try {
      await SalesService.markTabAsPaid(tabId);
      _refreshLedger();
      Notify.success('Success', 'Tab converted to sale');
    } catch (e) {
      Notify.error('Error', 'Failed to convert tab: $e');
    }
  }

  Future<void> addNewClient(String name, String phone) async {
    try {
      final id = await ClientsService.addClient(name, phone);
      if (id == null) {
        Notify.error('Error', 'A customer needs a name');
        return;
      }
      loadClients();
      Notify.success('Success', 'Client added successfully');
    } catch (e) {
      Notify.error('Error', 'Failed to add client: $e');
    }
  }

  Future<void> updateClient(String clientId, String name, String phone) async {
    try {
      await ClientsService.updateClient(clientId, name, phone);
      loadClients();
      Notify.success('Success', 'Client updated successfully');
    } catch (e) {
      Notify.error('Error', 'Failed to update client: $e');
    }
  }

  Future<void> deleteClient(String clientId) async {
    try {
      // Deleting the customer leaves their open tabs in the ledger with no
      // one attached to them; the money owed would simply disappear.
      final owed = ClientsService.getClientBalance(clientId);
      if (owed > 0) {
        Notify.error('Cannot delete',
            'This customer still owes \$${owed.toStringAsFixed(2)}. Settle their tabs first.');
        return;
      }
      await ClientsService.deleteClient(clientId);
      tabsByClient.remove(clientId);
      statsByClient.remove(clientId);
      loadClients();
      Notify.success('Success', 'Client deleted successfully');
    } catch (e) {
      Notify.error('Error', 'Failed to delete client: $e');
    }
  }

  double getClientBalance(String clientId) {
    // Touch the revision so any Obx reading a balance re-runs when a tab is
    // settled or deleted.
    ledgerRevision.value;
    return ClientsService.getClientBalance(clientId);
  }

  List<Map<String, dynamic>> searchClients(String query) {
    return ClientsService.searchClients(query);
  }
}
