import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos/http_client/data/models/items/add_edit_items_model.dart';
import 'package:pos/core/helpers/money.dart';
import 'package:pos/http_client/local_storage/local_storage_helpers.dart';

class HomeSceenController extends GetxController {
  final RxList<String> categories = <String>[].obs;
  final selectedCategory = ''.obs;
  final RxMap<String, bool> expandedCategories = <String, bool>{}.obs;

  final TextEditingController categoryController = TextEditingController();

  final RxList<AddEditItemModel> allProducts = <AddEditItemModel>[].obs;

  final cart = <AddEditItemModel>[].obs;

  @override
  void onInit() {
    allProducts.clear();
    super.onInit();
    loadCategories();
    loadProducts();
  }

  void loadCategories() {
    final loaded = LocalStorageHelpers.getJsonList('itemsBox', 'categories');
    if (loaded != null) {
      categories.assignAll(loaded.map((c) => c['name'] as String));
      for (var category in categories) {
        expandedCategories[category] = false;
      }
    }
  }

  void loadProducts() {
    final loaded = LocalStorageHelpers.getJsonList('itemsBox', 'products');
    if (loaded != null) {
      allProducts.assignAll(loaded.map((p) => AddEditItemModel.fromJson(p)));
    }
  }

  void addProduct(AddEditItemModel product) {
    allProducts.add(product);
    saveProducts();
  }

  void saveProducts() {
    LocalStorageHelpers.storeJsonList(
        'itemsBox', 'products', allProducts.map((p) => p.toJson()).toList());
  }

  void saveCategories() {
    LocalStorageHelpers.storeJsonList(
        'itemsBox', 'categories', categories.map((c) => {'name': c}).toList());
  }

  void addToCart(AddEditItemModel product) {
    final key = product.identityKey;
    final existingIndex = cart.indexWhere((item) => item.identityKey == key);
    if (existingIndex >= 0) {
      cart[existingIndex].quantity = (cart[existingIndex].quantity ?? 0) + 1;
      cart.refresh();
    } else {
      final cartItem = product.copy();
      cartItem.quantity = 1;
      cart.add(cartItem);
    }
  }

  void showAddCategoryDialog(BuildContext context) {
    categoryController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: categoryController,
          decoration: const InputDecoration(hintText: 'Enter category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final category = categoryController.text.trim();
              if (category.isNotEmpty) {
                addCategory(category);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void updateQuantity(int index, int change) {
    cart[index].quantity = (cart[index].quantity ?? 0) + change;
    if ((cart[index].quantity ?? 0) <= 0) {
      cart.removeAt(index);
    } else {
      cart.refresh();
    }
  }

  void removeItem(int index) => cart.removeAt(index);

  double get total => Money.round(cart.fold<double>(0.0,
      (sum, item) => sum + (item.quantity ?? 0) * (item.sellingPrice ?? 0)));

  /// With no category chosen the till shows the whole catalog. Filtering on an
  /// empty category matched nothing, so the grid opened blank.
  List<AddEditItemModel> get filteredProducts {
    final category = selectedCategory.value;
    if (category.isEmpty) return allProducts.toList();
    return allProducts.where((p) => p.category == category).toList();
  }

  void clearCart() => cart.clear();

  void addCategory(String category) {
    if (!categories.contains(category)) {
      categories.add(category);
      expandedCategories[category] = false;
      saveCategories();
    }
  }

  void deleteProduct(AddEditItemModel product) {
    final key = product.identityKey;
    final index = allProducts.indexWhere((p) => p.identityKey == key);
    if (index >= 0) {
      allProducts.removeAt(index);
      saveProducts();
    }
  }

  /// [original] is the row as it was before editing: the edit may itself have
  /// changed the barcode or the description that identifies it.
  bool updateProduct(AddEditItemModel original, AddEditItemModel updated) {
    final key = original.identityKey;
    final index = allProducts.indexWhere((p) => p.identityKey == key);
    if (index < 0) return false;
    allProducts[index] = updated;
    allProducts.refresh();
    saveProducts();
    return true;
  }

  void deleteCategory(String category) {
    categories.remove(category);
    expandedCategories.remove(category);
    saveCategories();
    allProducts.removeWhere((p) => p.category == category);
    saveProducts();
    // Leaving a deleted category selected left the till filtering on
    // something that no longer exists, showing an empty grid with no way back.
    if (selectedCategory.value == category) {
      selectedCategory.value = '';
    }
  }

  void toggleCategoryExpanded(String category) {
    expandedCategories[category] = !(expandedCategories[category] ?? false);
    expandedCategories.refresh();
  }

  List<AddEditItemModel> getProductsByCategory(String category) {
    return allProducts.where((p) => p.category == category).toList();
  }

  bool findAndAddByBarcode(String code) {
    final query = code.trim();
    if (query.isEmpty) return false;
    for (final p in allProducts) {
      if ((p.barcode?.trim() ?? '') == query) {
        addToCart(p);
        return true;
      }
    }
    return false;
  }
}
