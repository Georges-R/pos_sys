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

  /// Renames [from] everywhere it is used: the category list, every product
  /// filed under it and the lines already rung up for them.
  ///
  /// Products are changed in place rather than replaced. A product without a
  /// barcode is identified partly by its category, and the item screens hold
  /// on to the very row they opened; a replaced row would leave them unable
  /// to find it again when they save.
  ///
  /// Returns false when [to] is blank, unchanged, or already another
  /// category's name: fixing a typo should never merge two categories.
  bool renameCategory(String from, String to) {
    final name = to.trim();
    final index = categories.indexOf(from);
    if (index < 0 || name.isEmpty || name == from) return false;
    if (categories.contains(name)) return false;

    categories[index] = name;
    expandedCategories[name] = expandedCategories.remove(from) ?? false;
    saveCategories();

    for (final p in allProducts) {
      if (p.category == from) p.category = name;
    }
    allProducts.refresh();
    saveProducts();

    for (final line in cart) {
      if (line.category == from) line.category = name;
    }
    cart.refresh();

    if (selectedCategory.value == from) selectedCategory.value = name;
    return true;
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
  ///
  /// A line already rung up for this product takes the new name and price
  /// but keeps the count being sold, so the total on screen stays the one the
  /// customer will be charged.
  bool updateProduct(AddEditItemModel original, AddEditItemModel updated) {
    final key = original.identityKey;
    final index = allProducts.indexWhere((p) => p.identityKey == key);
    if (index < 0) return false;
    allProducts[index] = updated;
    allProducts.refresh();
    saveProducts();

    for (var i = 0; i < cart.length; i++) {
      if (cart[i].identityKey == key) {
        cart[i] = updated.copy()..quantity = cart[i].quantity;
      }
    }
    return true;
  }

  /// The catalog row a cart line was rung up from, or null if it has since
  /// been deleted. The line itself is a copy whose quantity is the count
  /// being sold, not the stock.
  AddEditItemModel? catalogProductFor(AddEditItemModel cartItem) {
    final key = cartItem.identityKey;
    final index = allProducts.indexWhere((p) => p.identityKey == key);
    return index < 0 ? null : allProducts[index];
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

  AddEditItemModel? findByBarcode(String code) {
    final query = code.trim();
    if (query.isEmpty) return null;
    for (final p in allProducts) {
      if ((p.barcode?.trim() ?? '') == query) return p;
    }
    return null;
  }

  bool findAndAddByBarcode(String code) {
    final match = findByBarcode(code);
    if (match == null) return false;
    addToCart(match);
    return true;
  }

  /// Creates a catalog row from the till with only what it takes to ring the
  /// item up now: a name, a category, a price and the stock on the shelf,
  /// with the level to warn at.
  /// Cost, TVA and profit stay unset for the item screen to fill in later — a
  /// cashier with a customer waiting cannot stop to work out margins.
  ///
  /// Returns null when [barcode] already belongs to another product: two rows
  /// sharing a barcode share an [AddEditItemModel.identityKey], and every
  /// later edit or delete would then land on whichever one was found first.
  AddEditItemModel? quickCreateProduct({
    required String description,
    required String barcode,
    required double sellingPrice,
    String? category,
    int quantity = 0,
    int? lowStockWarning,
  }) {
    final code = barcode.trim();
    if (code.isNotEmpty && findByBarcode(code) != null) return null;

    final trimmedCategory = category?.trim();
    if (trimmedCategory != null && trimmedCategory.isNotEmpty) {
      addCategory(trimmedCategory);
    }

    final product = AddEditItemModel(
      description: description.trim(),
      category: trimmedCategory,
      barcode: code,
      quantity: quantity,
      lowStockWarning: lowStockWarning,
      sellingPrice: Money.round(sellingPrice),
    );
    addProduct(product);
    return product;
  }
}
