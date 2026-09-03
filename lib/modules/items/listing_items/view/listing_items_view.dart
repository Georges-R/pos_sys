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
            child: Row(
              children: [
                Expanded(
                  child: Obx(() => TextField(
                        controller: searchCtrl,
                        onChanged: (v) => searchQuery.value = v,
                        decoration: InputDecoration(
                          hintText: 'Search products...',
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
              ],
            ),
          ),

          // Content
          Expanded(
            child: Obx(() {
              final q = searchQuery.value.trim().toLowerCase();
              // ListView.builder runs its item builder outside this closure,
              // so reads in there are not tracked. Touching the product list
              // here is what makes the screen rebuild after an add or delete.
              final products = controller.allProducts.toList();

              if (controller.categories.isEmpty) {
                return const Center(child: Text('No categories available'));
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: controller.categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final category = controller.categories[index];
                  final rawProducts =
                      products.where((p) => p.category == category).toList();

                  final filteredProducts = rawProducts.where((p) {
                    if (q.isEmpty) return true;
                    return (p.description ?? '').toLowerCase().contains(q);
                  }).toList();

                  return Obx(() {
                    final isExpanded =
                        controller.expandedCategories[category] ?? false;
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () =>
                                controller.toggleCategoryExpanded(category),
                            child: Container(
                              color: Colors.grey[50],
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      category.isNotEmpty
                                          ? category[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        if (filteredProducts.isEmpty)
                                          const SizedBox.shrink()
                                        else
                                          Text(
                                            '${filteredProducts.length} item(s)',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${rawProducts.length}',
                                      style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    isExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: Colors.grey[700],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: ConstrainedBox(
                              constraints: isExpanded
                                  ? const BoxConstraints()
                                  : const BoxConstraints(maxHeight: 0),
                              child: Column(
                                children: [
                                  if (filteredProducts.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Text(
                                        'No items match your search in this category.',
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      itemCount: filteredProducts.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, pi) {
                                        final product = filteredProducts[pi];
                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 6),
                                          leading: const Icon(
                                              Icons.inventory_2_outlined,
                                              color: Colors.blue),
                                          title: Text(
                                            '${product.description ?? 'No Name'} (${product.quantity ?? 0})',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: product.sellingPrice != null
                                              ? Text(
                                                  'Price: ${product.sellingPrice}',
                                                  style: TextStyle(
                                                      color: Colors.grey[600]),
                                                )
                                              : null,
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit',
                                                icon: const Icon(Icons.edit,
                                                    color: Colors.blue),
                                                onPressed: () {
                                                  Get.toNamed(
                                                    Paths.addEditItemScreen,
                                                    arguments: product,
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                tooltip: 'Delete',
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _showDeleteProductDialog(
                                                        context, product),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  });
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
