import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/product.dart';

/// A product plus the quantity the customer wants.
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  num get lineTotal => product.price * quantity;
}

/// In-memory session cart (docs/architecture.md section 4:
/// Firestore-persisted cart is PENDING a future phase).
class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList(growable: false);

  int get itemCount => _items.values.fold(0, (sum, e) => sum + e.quantity);

  num get totalAmount => _items.values.fold(0, (sum, e) => sum + e.lineTotal);

  bool get isEmpty => _items.isEmpty;

  int quantityOf(String productId) => _items[productId]?.quantity ?? 0;

  void add(Product product, [int quantity = 1]) {
    final existing = _items[product.id];
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _items[product.id] = CartItem(product: product, quantity: quantity);
    }
    notifyListeners();
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      _items.remove(productId);
    } else {
      _items[productId]?.quantity = quantity;
    }
    notifyListeners();
  }

  void remove(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Snapshot of cart contents as order items (shared-schema maps).
  List<OrderItem> toOrderItems() => _items.values
      .map((e) => OrderItem(
            productId: e.product.id,
            name: e.product.name,
            price: e.product.price,
            quantity: e.quantity,
            unit: e.product.unit,
            imageUrl: e.product.imageUrl,
          ))
      .toList();
}
