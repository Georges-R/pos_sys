import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/core/helpers/notify.dart';
import '../controller/clients_controller.dart';

class ClientsView extends GetView<ClientsController> {
  const ClientsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients & Tabs'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddClientDialog(context),
          ),
        ],
      ),
      body: Obx(
        () => controller.clients.isEmpty
            ? const Center(
                child: Text('No clients yet. Add one to get started!'),
              )
            : ListView.builder(
                itemCount: controller.clients.length,
                itemBuilder: (context, index) {
                  final client = controller.clients[index];

                  if (client.isEmpty) {
                    return const Card(
                      child: ListTile(
                        title: Text('Invalid Client Data'),
                        subtitle: Text('Client information is missing'),
                      ),
                    );
                  }

                  final clientId = client['id'];

                  if (clientId == null) {
                    return const Card(
                      child: ListTile(
                        title: Text('Invalid Client ID'),
                        subtitle: Text('Client ID is missing'),
                      ),
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ExpansionTile(
                      title: Text(
                        client['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(client['phone'] ?? 'No phone'),
                          // Rows are built lazily by the list, outside the
                          // outer Obx, so the balance needs its own Obx to
                          // pick up ledgerRevision and update on its own.
                          Obx(() {
                            final balance =
                                controller.getClientBalance(clientId);
                            return Text(
                              'Balance: \$${balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: balance > 0 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }),
                        ],
                      ),
                      leading: const Icon(Icons.person),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Text('Edit'),
                            onTap: () => _showEditClientDialog(context, client),
                          ),
                          PopupMenuItem(
                            child: const Text('Delete'),
                            onTap: () =>
                                _confirmDeleteClient(context, clientId),
                          ),
                        ],
                      ),
                      onExpansionChanged: (expanded) {
                        if (expanded) {
                          controller.loadClientTabs(clientId);
                        }
                      },
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Obx(
                            () => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatCard(
                                      'Total Tabs',
                                      (controller.statsOf(
                                                  clientId)['totalTabs'] ??
                                              0)
                                          .toString(),
                                    ),
                                    _buildStatCard(
                                      'Open Tabs',
                                      (controller.statsOf(
                                                  clientId)['openTabs'] ??
                                              0)
                                          .toString(),
                                    ),
                                    _buildStatCard(
                                      'Total Owed',
                                      '\$${(controller.statsOf(clientId)['totalOwed'] ?? 0.0).toStringAsFixed(2)}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                // Tabs List
                                if (controller.openTabsOf(clientId).isEmpty)
                                  const Text('No open tabs')
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount:
                                        controller.openTabsOf(clientId).length,
                                    itemBuilder: (context, tabIndex) {
                                      // This used to index with the client's
                                      // row number, which showed the wrong tab
                                      // and crashed for every client past the
                                      // first.
                                      final tab = controller
                                          .openTabsOf(clientId)[tabIndex];

                                      return Card(
                                        child: ListTile(
                                          title: Text(
                                              'Tab #${tab['id'] ?? 'Unknown'}'),
                                          subtitle: Text(
                                            'Total: \$${(tab['totalUSD'] ?? 0.0).toStringAsFixed(2)} (${(tab['totalLBP'] ?? 0.0).toStringAsFixed(0)} LBP)\nCreated: ${tab['date'] ?? 'Unknown'}',
                                          ),
                                          isThreeLine: true,
                                          trailing: PopupMenuButton(
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                child: const Text(
                                                    'Convert to Sale'),
                                                onTap: () =>
                                                    controller.convertTabToSale(
                                                        tab['id']?.toString() ??
                                                            ''),
                                              ),
                                              PopupMenuItem(
                                                child: const Text('Delete Tab'),
                                                onTap: () =>
                                                    controller.deleteTab(
                                                        tab['id']?.toString() ??
                                                            ''),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  void _showAddClientDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                controller.addNewClient(
                  nameController.text,
                  phoneController.text,
                );
                Get.back();
              } else {
                Notify.error('Error', 'Please enter client name');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditClientDialog(
      BuildContext context, Map<String, dynamic> client) {
    final nameController = TextEditingController(text: client['name']);
    final phoneController = TextEditingController(text: client['phone']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.updateClient(
                client['id'],
                nameController.text,
                phoneController.text,
              );
              Get.back();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClient(BuildContext context, String clientId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client'),
        content: const Text('Are you sure you want to delete this client?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteClient(clientId);
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
