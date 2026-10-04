import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/core/routes/paths.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/modules/home_screen/controller/home_sceen_controller.dart';

class ListingItemsView extends GetView<HomeSceenController> {
  const ListingItemsView({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController searchCtrl = TextEditingController();
    final searchQuery = ''.obs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        backgroundColor: Colors.grey[200],
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Obx(() => TextField(
                  controller: searchCtrl,
                  // A scanner types into whatever has focus, so an item can
                  // be looked up by scanning it as soon as the screen opens.
                  autofocus: true,
                  onChanged: (v) => searchQuery.value = v,
                  decoration: InputDecoration(
                    hintText: 'Search by name or barcode...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchCtrl.clear();
                              searchQuery.value = '';
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                )),
          ),
          Expanded(
            child: Obx(() {
              final q = searchQuery.value.trim().toLowerCase();
              // ListView.builder runs its item builder outside this closure,
              // so reads in there are not tracked. Building the list here is
              // what makes the screen rebuild after an add or delete.
              final products = controller.allProducts.where((p) {
                if (q.isEmpty) return true;
                return (p.description ?? '').toLowerCase().contains(q) ||
                    (p.barcode ?? '').toLowerCase().contains(q);
              }).toList();

              if (products.isEmpty) {
                return Center(
                  child: Text(
                    q.isEmpty ? 'No items yet' : 'No items match "$q"',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    title: Text(
                      product.description ?? 'No Name',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        if ((product.barcode ?? '').isNotEmpty)
                          product.barcode!,
                        'Stock: ${product.quantity ?? 0}',
                      ].join('  ·  '),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => Get.toNamed(
                            Paths.addEditItemScreen,
                            arguments: product,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _showDeleteProductDialog(context, product),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showDeleteProductDialog(
      BuildContext context, AddEditItemModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content:
            Text('Are you sure you want to delete "${product.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.deleteProduct(product);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
