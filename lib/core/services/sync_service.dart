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
        try {
          // Get the local order items
          final items = await cachingRepo.getLocalOrderItems(order['id'] as String);

          // Submit to Supabase via the secure RPC
          final result = await remoteRepo.placeOrder(
            customerPhone: order['customer_phone'] as String? ?? '',
            deliveryAddress: order['delivery_address'] as String? ?? '',
            totalAmount: (order['total_amount'] as num?)?.toDouble() ?? 0.0,
            items: items,
            deliveryDate: order['delivery_date'] as String?,
            offlineOrderNo: order['offline_order_no'] as String?,
            idempotencyKey: order['id'] as String?, // Pass local order UUID as idempotency key
            orderType: order['order_type'] as String?,
            orderTakingDate: order['order_taking_date'] as String?,
          );

          // Mark local order as synced, updating local ID to remote ID and setting canonical order number
          await cachingRepo.markOrderSynced(
            order['id'] as String,
            result['id'] as String,
            result['order_number'] as String,
          );

          debugPrint('SyncService: Order ${order['order_number']} synced successfully');
        } catch (e) {
          debugPrint('SyncService: Failed to sync order ${order['order_number']}: $e');
          await cachingRepo.markOrderFailed(order['id'] as String, e.toString());
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
