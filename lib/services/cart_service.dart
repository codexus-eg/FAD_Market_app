import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartService {
  static const String _cartKey = 'fce_cart_items';

  static Future<List<CartItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.product.id > 0 && item.quantity > 0)
          .toList();
    } catch (_) {
      await clear();
      return [];
    }
  }

  static Future<void> _saveItems(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = items
        .where((item) => item.product.id > 0 && item.quantity > 0)
        .toList();

    await prefs.setString(
      _cartKey,
      jsonEncode(cleaned.map((item) => item.toJson()).toList()),
    );
  }

  static Future<int> getItemsCount() async {
    final items = await getItems();
    int count = 0;
    for (final item in items) count += item.quantity;
    return count;
  }

  static Future<void> addProduct(Product product, int quantity) async {
    if (quantity <= 0) return;

    final items = await getItems();
    final index = items.indexWhere(
      (item) => item.product.cartKey == product.cartKey,
    );

    if (index >= 0) {
      final old = items[index];
      final newQuantity = old.quantity + quantity;
      items[index] = old.copyWith(
        product: product,
        quantity: newQuantity > 99 ? 99 : newQuantity,
      );
    } else {
      items.add(CartItem(product: product, quantity: quantity > 99 ? 99 : quantity));
    }

    await _saveItems(items);
  }

  static Future<void> setQuantityByKey(String cartKey, int quantity) async {
    final items = await getItems();

    if (quantity <= 0) {
      items.removeWhere((item) => item.product.cartKey == cartKey);
      await _saveItems(items);
      return;
    }

    final index = items.indexWhere((item) => item.product.cartKey == cartKey);
    if (index >= 0) {
      items[index] = items[index].copyWith(quantity: quantity > 99 ? 99 : quantity);
    }

    await _saveItems(items);
  }

  static Future<void> removeProductByKey(String cartKey) async {
    final items = await getItems();
    items.removeWhere((item) => item.product.cartKey == cartKey);
    await _saveItems(items);
  }

  // Backward compatibility for old screens.
  static Future<void> setQuantity(int productId, int quantity) async {
    final items = await getItems();
    final match = items.where((item) => item.product.id == productId).toList();
    if (match.isEmpty) return;
    await setQuantityByKey(match.first.product.cartKey, quantity);
  }

  static Future<void> removeProduct(int productId) async {
    final items = await getItems();
    final match = items.where((item) => item.product.id == productId).toList();
    if (match.isEmpty) return;
    await removeProductByKey(match.first.product.cartKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  }
}
