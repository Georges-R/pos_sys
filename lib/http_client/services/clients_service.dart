import 'package:flutter/widgets.dart';
import 'package:pos/http_client/local_storage/hive_service.dart';
import 'package:pos/http_client/services/sales_service.dart';
import 'package:uuid/uuid.dart';

class ClientsService {
  static const String _clientsKey = 'clients';
  static const Uuid _uuid = Uuid();

  static List<Map<String, dynamic>> getAllClients() {
    try {
      return HiveService.getClientMapList(_clientsKey);
    } catch (e) {
      debugPrint('Error getting clients: $e');
      return [];
    }
  }

  static Map<String, dynamic>? getClientById(String clientId) {
    try {
      final clients = getAllClients();
      final client = clients.firstWhere(
        (client) => client['id'] == clientId,
        orElse: () => <String, dynamic>{},
      );

      if (client.isEmpty) {
        return null;
      }

      return client;
    } catch (e) {
      debugPrint('Error getting client: $e');
      return null;
    }
  }

  /// Returns the new client's id, or null if the input was not usable.
  ///
  /// A customer with no name cannot be picked off the tab list later, so an
  /// empty name is refused rather than stored.
  static Future<String?> addClient(String name, String phone) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      debugPrint('Refusing to add a client with no name');
      return null;
    }
    try {
      // A millisecond timestamp collides whenever two customers are added in
      // the same millisecond, and every later edit or delete then hits both.
      final id = _uuid.v4();
      final newClient = {
        'id': id,
        'name': trimmedName,
        'phone': phone.trim(),
        'createdDate': DateTime.now().toIso8601String(),
        'status': 'active',
      };

      final clients = getAllClients();
      clients.add(newClient);

      await HiveService.setClientValue(_clientsKey, clients);
      return id;
    } catch (e) {
      debugPrint('Error adding client: $e');
      rethrow;
    }
  }

  static Future<void> updateClient(
    String clientId,
    String name,
    String phone,
  ) async {
    try {
      final clients = getAllClients();
      final index = clients.indexWhere((client) => client['id'] == clientId);

      if (index != -1) {
        clients[index] = {
          ...clients[index],
          'name': name.trim(),
          'phone': phone.trim(),
          'updatedDate': DateTime.now().toIso8601String(),
        };

        await HiveService.setClientValue(_clientsKey, clients);
      }
    } catch (e) {
      debugPrint('Error updating client: $e');
      rethrow;
    }
  }

  static Future<void> deleteClient(String clientId) async {
    try {
      final clients = getAllClients();
      clients.removeWhere((client) => client['id'] == clientId);

      await HiveService.setClientValue(_clientsKey, clients);
    } catch (e) {
      debugPrint('Error deleting client: $e');
      rethrow;
    }
  }

  static double getClientBalance(String clientId) {
    try {
      final tabsMap = SalesService.getClientTabs(clientId);
      double totalBalance = 0.0;

      for (final tabData in tabsMap.values) {
        if (tabData is Map && tabData['status'] == 'open') {
          totalBalance += _toDouble(tabData['totalUSD']);
        }
      }
      return totalBalance;
    } catch (e) {
      debugPrint('Error calculating client balance: $e');
      return 0.0;
    }
  }

  static List<Map<String, dynamic>> getClientPaymentHistory(String clientId) {
    try {
      return HiveService.getClientMapList(_historyKey(clientId));
    } catch (e) {
      debugPrint('Error getting payment history: $e');
      return [];
    }
  }

  static Future<void> addPaymentToHistory(
    String clientId,
    Map<String, dynamic> payment,
  ) async {
    try {
      final history = getClientPaymentHistory(clientId);
      history.add({
        ...payment,
        'date': DateTime.now().toIso8601String(),
      });

      await HiveService.setClientValue(_historyKey(clientId), history);
    } catch (e) {
      debugPrint('Error adding payment to history: $e');
      rethrow;
    }
  }

  static List<Map<String, dynamic>> searchClients(String query) {
    try {
      final clients = getAllClients();
      final lowerQuery = query.toLowerCase();

      return clients
          .where((client) =>
              '${client['name'] ?? ''}'.toLowerCase().contains(lowerQuery) ||
              '${client['phone'] ?? ''}'.toLowerCase().contains(lowerQuery))
          .toList();
    } catch (e) {
      debugPrint('Error searching clients: $e');
      return [];
    }
  }

  static Map<String, dynamic> getClientStats(String clientId) {
    try {
      final tabsMap = SalesService.getClientTabs(clientId);
      int openTabsCount = 0;
      double totalOwed = 0.0;

      for (final tabData in tabsMap.values) {
        if (tabData is Map && tabData['status'] == 'open') {
          openTabsCount++;
          totalOwed += _toDouble(tabData['totalUSD']);
        }
      }
      final totalTabsCount = tabsMap.length;

      return {
        'totalTabs': totalTabsCount,
        'openTabs': openTabsCount,
        'totalOwed': totalOwed,
        'closedTabs': totalTabsCount - openTabsCount,
      };
    } catch (e) {
      debugPrint('Error getting client stats: $e');
      return {
        'totalTabs': 0,
        'openTabs': 0,
        'totalOwed': 0.0,
        'closedTabs': 0,
      };
    }
  }

  static String _historyKey(String clientId) => 'client_${clientId}_history';

  /// Hive returns whatever type was written — an int for a whole-dollar total,
  /// a String once the value has been through an Excel import.
  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }
}
