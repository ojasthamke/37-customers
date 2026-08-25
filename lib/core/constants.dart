import 'package:intl/intl.dart';

/// Shared constants & helpers per docs/architecture.md.

/// Order status flow — use these EXACT strings (shared contract with admin app).
class OrderStatus {
  static const String placed = 'placed';
  static const String confirmed = 'confirmed';
  static const String packed = 'packed';
  static const String outForDelivery = 'out_for_delivery';
  static const String delivered = 'delivered';
  static const String cancelled = 'cancelled';

  /// Steps shown in the customer-facing status timeline (in order).
  static const List<String> flow = [
    placed,
    confirmed,
    packed,
    outForDelivery,
    delivered,
  ];

  static String label(String status) {
    switch (status) {
      case placed:
        return 'Placed';
      case confirmed:
        return 'Confirmed';
      case packed:
        return 'Packed';
      case outForDelivery:
        return 'Out for delivery';
      case delivered:
        return 'Delivered';
      case cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}

/// Currency formatting: ₹ via intl NumberFormat('#,##0.##').
final NumberFormat _priceFormat = NumberFormat('#,##0.##');

String formatPrice(num value) => '₹${_priceFormat.format(value)}';
