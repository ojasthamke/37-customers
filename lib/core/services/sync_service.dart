import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/caching_repositories.dart';
import '../database/repositories.dart';

/// Background sync service that monitors connectivity and syncs
/// pending offline orders to Supabase when network is restored.
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  /// Initialize the sync service — call once at app startup
  void init() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && !_isSyncing) {
        syncPendingOrders();
      }
    });

    // Also try syncing immediately on init
    syncPendingOrders();
  }

  /// Sync all pending offline orders to Supabase
  Future<void> syncPendingOrders() async {
    if (_isSyncing) return;
    _isSyncing = true;

    /// Maximum number of sync attempts before permanently failing an order.
    const int maxRetries = 5;

    try {
      final cachingRepo = CachingOrderRepository();
      final remoteRepo = SupabaseOrderRepository();

      final pendingOrders = await cachingRepo.getPendingOrders();
      if (pendingOrders.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('SyncService: Found ${pendingOrders.length} pending orders to sync');

      for (final order in pendingOrders) {
        final orderId = order['id']?.toString() ?? '';

        // Skip orders that have exceeded the retry limit
        final int retryCount = (order['sync_retry_count'] as int?) ?? 0;
        if (retryCount >= maxRetries) {
          debugPrint('SyncService: Order $orderId exceeded max retries ($maxRetries). Marking as permanently_failed.');
          await cachingRepo.markOrderPermanentlyFailed(orderId);
          continue;
        }

        try {
          // Get the local order items
          final items = await cachingRepo.getLocalOrderItems(orderId);

          // Use the ORIGINAL idempotency key stored when the order was queued.
          // Falling back to the local order ID ensures backward compatibility
          // with orders queued before this fix was deployed.
          final storedIdempotencyKey = order['idempotency_key']?.toString();
          final effectiveKey = (storedIdempotencyKey != null && storedIdempotencyKey.isNotEmpty)
              ? storedIdempotencyKey
              : (orderId.isNotEmpty ? orderId : null);

          // Submit to Supabase via the secure RPC
          final result = await remoteRepo.placeOrder(
            customerPhone: order['customer_phone']?.toString() ?? '',
            deliveryAddress: order['delivery_address']?.toString() ?? '',
            totalAmount: (order['total_amount'] as num?)?.toDouble() ?? 0.0,
            items: items,
            deliveryDate: order['delivery_date']?.toString(),
            offlineOrderNo: order['offline_order_no']?.toString(),
            idempotencyKey: effectiveKey,
            orderType: order['order_type']?.toString(),
            orderTakingDate: order['order_taking_date']?.toString(),
          );

          // Mark local order as synced, updating local ID to remote ID and setting canonical order number
          await cachingRepo.markOrderSynced(
            orderId,
            result['id']?.toString() ?? '',
            result['order_number']?.toString() ?? '',
          );

          debugPrint('SyncService: Order ${order['order_number']} synced successfully');
        } catch (e) {
          debugPrint('SyncService: Failed to sync order ${order['order_number']}: $e');
          await cachingRepo.markOrderFailed(orderId, e.toString());
        }
      }
    } catch (e) {
      debugPrint('SyncService: Sync cycle failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Dispose of the connectivity subscription
  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}
