import 'dart:convert';

/// Single canonical source of truth for product availability, stock, and pricing.
/// Enforces the invariant:
/// - Order Now NULL = NOT CONFIGURED / NOT AVAILABLE.
/// - Order Now items require explicit order_now_is_available == true AND order_now_stock > 0.
/// - Normal items require is_available == true AND stock > 0.
class ProductHelper {
  ProductHelper._();

  /// Parse double safely from dynamic value
  static double? asDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  /// Check whether product is enabled (active)
  static bool isEnabled(Map<String, dynamic> product) {
    final raw = product['is_enabled'];
    if (raw == null) return true;
    if (raw == true || raw == 1) return true;
    final str = raw.toString().toLowerCase().trim();
    return str != '0' && str != 'false';
  }

  /// Check whether product is explicitly configured for Order Now.
  /// An item not configured for Order Now must NOT appear or be ordered through Order Now.
  static bool isOrderNowConfigured(Map<String, dynamic> product) {
    final rawAvail = product['order_now_is_available'];
    if (rawAvail == null) return false; // NULL = NOT CONFIGURED
    final bool isAvail = (rawAvail == true ||
        rawAvail == 1 ||
        rawAvail.toString() == '1' ||
        rawAvail.toString().toLowerCase() == 'true');
    if (!isAvail) return false;

    // Must have an explicit order_now_stock entry configured
    final rawStock = product['order_now_stock'];
    if (rawStock == null) return false;

    return true;
  }

  /// Canonical availability check across all screens and modes.
  /// Returns true only if product is enabled, is marked available, and has stock > 0.
  static bool isAvailable(Map<String, dynamic> product, {bool isOrderNow = false}) {
    if (!isEnabled(product)) return false;

    if (isOrderNow) {
      final rawAvail = product['order_now_is_available'];
      if (rawAvail == null) return false; // NULL = NOT AVAILABLE for Order Now
      final bool onAvail = (rawAvail == true ||
          rawAvail == 1 ||
          rawAvail.toString() == '1' ||
          rawAvail.toString().toLowerCase() == 'true');
      if (!onAvail) return false;
      return getStock(product, isOrderNow: true) > 0;
    } else {
      final rawAvail = product['is_available'];
      final bool stdAvail = (rawAvail == null ||
          rawAvail == true ||
          rawAvail == 1 ||
          rawAvail.toString() == '1' ||
          rawAvail.toString().toLowerCase() == 'true');
      if (!stdAvail) return false;
      return getStock(product, isOrderNow: false) > 0;
    }
  }

  /// Canonical stock getter
  static double getStock(Map<String, dynamic> product, {bool isOrderNow = false}) {
    if (isOrderNow) {
      final raw = product['order_now_stock'];
      final double? parsed = asDouble(raw);
      if (parsed == null || parsed < 0) return 0.0;
      return parsed;
    } else {
      final raw = product['stock'];
      double? parsed = asDouble(raw);
      if (parsed == null) {
        final desc = product['description']?.toString() ?? '';
        if (desc.trim().startsWith('{') && desc.trim().endsWith('}')) {
          try {
            final obj = jsonDecode(desc);
            if (obj is Map && obj['stock'] != null) {
              parsed = asDouble(obj['stock']);
            }
          } catch (_) {}
        }
      }
      if (parsed == null || parsed < 0) return 0.0;
      return parsed;
    }
  }

  /// Canonical price getter
  static double getPrice(Map<String, dynamic> product, {bool isOrderNow = false}) {
    if (isOrderNow) {
      final onPrice = asDouble(product['order_now_price']) ?? asDouble(product['order_now_selling_price']);
      if (onPrice != null && onPrice > 0) return onPrice;
    }
    return asDouble(product['selling_price']) ?? asDouble(product['price']) ?? 0.0;
  }

  /// Canonical MRP / market price getter
  static double getMrp(Map<String, dynamic> product, {bool isOrderNow = false}) {
    if (isOrderNow) {
      final onMrp = asDouble(product['order_now_mrp']) ?? asDouble(product['order_now_market_price']);
      if (onMrp != null && onMrp > 0) return onMrp;
    }
    return asDouble(product['market_price']) ?? asDouble(product['mrp']) ?? 0.0;
  }
}
