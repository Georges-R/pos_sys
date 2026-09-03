class AddEditItemModel {
  String? description, category, barcode;
  int? quantity;
  double? costPrice, tvaPercent, priceAfterTva, profitPercent, sellingPrice;

  AddEditItemModel({
    this.description,
    this.category,
    this.barcode,
    this.quantity,
    this.costPrice,
    this.tvaPercent,
    this.priceAfterTva,
    this.profitPercent,
    this.sellingPrice,
  });

  factory AddEditItemModel.fromJson(Map<String, dynamic> json) {
    return AddEditItemModel(
      description: json['description'],
      category: json['category'],
      barcode: json['barcode'],
      quantity: json['quantity'] != null
          ? int.tryParse(json['quantity'].toString())
          : null,
      costPrice: json['cost_price'] != null
          ? double.tryParse(json['cost_price'].toString())
          : null,
      tvaPercent: json['tva_percent'] != null
          ? double.tryParse(json['tva_percent'].toString())
          : null,
      priceAfterTva: json['price_after_tva'] != null
          ? double.tryParse(json['price_after_tva'].toString())
          : null,
      profitPercent: json['profit_percent'] != null
          ? double.tryParse(json['profit_percent'].toString())
          : null,
      sellingPrice: json['selling_price'] != null
          ? double.tryParse(json['selling_price'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'category': category,
      'barcode': barcode,
      'quantity': quantity,
      'cost_price': costPrice,
      'tva_percent': tvaPercent,
      'price_after_tva': priceAfterTva,
      'profit_percent': profitPercent,
      'selling_price': sellingPrice,
    };
  }

  /// What makes this row a distinct product on the shelf.
  ///
  /// The barcode is the real identifier when the shop uses one. Falling back
  /// to the description alone would merge two genuinely different products
  /// that happen to share a name — a common case when the same article comes
  /// from two suppliers at two prices.
  String get identityKey {
    final code = barcode?.trim() ?? '';
    if (code.isNotEmpty) return 'barcode:$code';
    return 'item:${description?.trim()}|${category?.trim()}|$sellingPrice';
  }

  AddEditItemModel copy() => AddEditItemModel.fromJson(toJson());
}
