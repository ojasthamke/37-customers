import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/providers.dart';

Map<String, dynamic> _parseProductDescription(Map<String, dynamic> p) {
  final Map<String, dynamic> mapped = Map.from(p);
  final desc = p['description'] as String? ?? '';
  if (desc.trim().startsWith('{') && desc.trim().endsWith('}')) {
    try {
      final Map<String, dynamic> decoded = json.decode(desc);
      mapped['description'] = decoded['text'] as String? ?? '';
      mapped['cost_price'] = (decoded['cost_price'] as num?)?.toDouble() ?? 0.0;
      mapped['market_price'] = ((decoded['market_price'] ?? decoded['mrp']) as num?)?.toDouble() ?? 0.0;
      mapped['stock'] = (decoded['stock'] as num?)?.toDouble() ?? 0.0;
      mapped['min_stock'] = (decoded['min_stock'] as num?)?.toDouble() ?? 0.0;
      mapped['barcode'] = decoded['barcode'] as String? ?? '';
      mapped['weight_per_piece'] = (decoded['weight_per_piece'] as num?)?.toDouble() ?? 0.25;
      mapped['sequence_no'] = decoded['sequence_no'] as int? ?? decoded['serial_no'] as int? ?? 0;
      mapped['expiry_date'] = decoded['expiry_date'] as String? ?? '';
      mapped['batch_number'] = decoded['batch_number'] as String? ?? '';
      mapped['prescription_required'] = decoded['prescription_required'] as bool? ?? false;
      mapped['dosage_info'] = decoded['dosage_info'] as String? ?? '';
      mapped['best_before'] = decoded['best_before'] as String? ?? '';
      mapped['pack_date'] = decoded['pack_date'] as String? ?? '';
    } catch (_) {
      mapped['description'] = desc;
    }
  } else {
    mapped['description'] = desc;
  }

  // Override from standalone db columns if present
  if (p['mrp'] != null) {
    mapped['market_price'] = (p['mrp'] as num).toDouble();
  }
  if (p['stock'] != null) {
    mapped['stock'] = (p['stock'] as num).toDouble();
  }
  if (p['price'] != null) {
    mapped['price'] = (p['price'] as num).toDouble();
  }
  return mapped;
}

Map<String, dynamic> _parseOrderNowProduct(Map<String, dynamic> p) {
  final mapped = _parseProductDescription(p);
  
  // Store the standard normal price (Home section price) before override
  final normalPrice = (p['price'] as num?)?.toDouble() ?? 0.0;
  mapped['original_standard_price'] = normalPrice;

  final onPrice = (p['order_now_price'] as num?)?.toDouble();
  if (onPrice != null && onPrice > 0) {
    mapped['price'] = onPrice;
    mapped['selling_price'] = onPrice;
  }
  final onMrp = (p['order_now_mrp'] as num?)?.toDouble();
  if (onMrp != null && onMrp > 0) {
    mapped['market_price'] = onMrp;
    mapped['mrp'] = onMrp;
  }

  // ORDER NOW STOCK IS STRICTLY INDEPENDENT OF NORMAL HOME STOCK
  final double onStock = (p['order_now_stock'] as num?)?.toDouble() ?? 0.0;
  mapped['order_now_stock'] = onStock;
  mapped['stock'] = onStock;

  final bool onAvailable = p['order_now_is_available'] == null
      ? true
      : (p['order_now_is_available'] == true || p['order_now_is_available'] == 1);
  mapped['order_now_is_available'] = onAvailable;
  mapped['is_available'] = onAvailable;
  mapped['is_enabled'] = onAvailable;
  mapped['is_order_now'] = true;

  mapped['order_now_price'] = (p['order_now_price'] as num?)?.toDouble() ?? (mapped['price'] as num?)?.toDouble() ?? 0.0;
  mapped['order_now_mrp'] = (p['order_now_mrp'] as num?)?.toDouble() ?? (mapped['market_price'] as num?)?.toDouble() ?? 0.0;

  // Determine the price off percent
  double? manualPercent;
  if (p['price_off_percent'] != null) {
    manualPercent = (p['price_off_percent'] as num).toDouble();
  }
  if (manualPercent == null) {
    final desc = p['description'] as String? ?? '';
    if (desc.trim().startsWith('{') && desc.trim().endsWith('}')) {
      try {
        final Map<String, dynamic> decoded = json.decode(desc);
        if (decoded['price_off_percent'] != null) {
          manualPercent = (decoded['price_off_percent'] as num).toDouble();
        }
      } catch (_) {}
    }
  }

  // Calculate dynamic percent discount if no manual override
  if (manualPercent != null) {
    mapped['price_off_percent'] = manualPercent;
  } else if (normalPrice > 0 && mapped['price'] != null && mapped['price'] < normalPrice) {
    final dynamicPercent = (((normalPrice - mapped['price']) / normalPrice) * 100).roundToDouble();
    mapped['price_off_percent'] = dynamicPercent;
  } else {
    mapped['price_off_percent'] = 0.0;
  }

  return mapped;
}

int _sortProducts(Map<String, dynamic> a, Map<String, dynamic> b) {
  final double aStock = (a['stock'] as num?)?.toDouble() ?? 0.0;
  final double bStock = (b['stock'] as num?)?.toDouble() ?? 0.0;
  
  final bool aOutOfStock = aStock <= 0;
  final bool bOutOfStock = bStock <= 0;
  
  if (aOutOfStock != bOutOfStock) {
    return aOutOfStock ? 1 : -1;
  }
  
  return (a['name'] ?? '').compareTo(b['name'] ?? '');
}

// Categories list provider (Realtime Stream with Future fallback & Polling)
final categoriesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<List<Map<String, dynamic>>>();
  Timer? pollTimer;
  
  Future<void> fetchLatest() async {
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final res = await repo.getCategories(onRefresh: (freshData) {
        final filtered = List<Map<String, dynamic>>.from(freshData)
            .where((c) => c['is_enabled'] == true || c['is_enabled'] == 1)
            .toList();
        if (!controller.isClosed) {
          controller.add(filtered);
        }
      });
      final filtered = List<Map<String, dynamic>>.from(res)
          .where((c) => c['is_enabled'] == true || c['is_enabled'] == 1)
          .toList();
      if (!controller.isClosed) {
        controller.add(filtered);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Fetch immediately
  fetchLatest();

  // Polling fallback every 60 seconds (Realtime subscription handles instant updates)
  pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => fetchLatest());

  // Realtime subscription (Fast Path)
  StreamSubscription? sub;
  try {
    sub = client
        .from('categories')
        .stream(primaryKey: ['id'])
        .map((list) {
          final filtered = list.where((c) => c['is_enabled'] == true || c['is_enabled'] == 1).toList();
          filtered.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
          return filtered;
        })
        .listen(
          (data) {
            if (!controller.isClosed) {
              controller.add(data);
            }
          },
          onError: (err) {
            debugPrint('Realtime categories error (falling back to polling): $err');
          },
          cancelOnError: false,
        );
  } catch (e) {
    debugPrint('Realtime categories setup failed: $e');
  }

  ref.onDispose(() {
    pollTimer?.cancel();
    sub?.cancel();
    controller.close();
  });

  return controller.stream;
});

// Product filter model
class CatalogFilter {
  final String search;
  final String? categoryId;

  CatalogFilter({this.search = '', this.categoryId});

  CatalogFilter copyWith({String? search, String? categoryId, bool clearCategory = false}) {
    return CatalogFilter(
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }
}

class CatalogFilterNotifier extends StateNotifier<CatalogFilter> {
  CatalogFilterNotifier() : super(CatalogFilter());

  void setSearch(String search) {
    state = state.copyWith(search: search);
  }

  void setCategory(String? categoryId) {
    if (categoryId == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(categoryId: categoryId);
    }
  }

  void clear() {
    state = CatalogFilter();
  }
}

final catalogFilterProvider = StateNotifierProvider<CatalogFilterNotifier, CatalogFilter>((ref) {
  return CatalogFilterNotifier();
});

// All products stream provider to preload and cache product catalog in memory
final allProductsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<List<Map<String, dynamic>>>();
  Timer? pollTimer;

  Future<void> fetchLatest() async {
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final res = await repo.getProducts(onRefresh: (freshData) {
        final parsed = List<Map<String, dynamic>>.from(freshData)
            .where((p) => p['is_enabled'] == true || p['is_enabled'] == 1)
            .map((p) => _parseProductDescription(p))
            .toList();
        parsed.sort(_sortProducts);
        if (!controller.isClosed) {
          controller.add(parsed);
        }
      });
      final parsed = List<Map<String, dynamic>>.from(res)
          .where((p) => p['is_enabled'] == true || p['is_enabled'] == 1)
          .map((p) => _parseProductDescription(p))
          .toList();
      parsed.sort(_sortProducts);
      if (!controller.isClosed) {
        controller.add(parsed);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Fetch immediately
  fetchLatest();

  // Polling fallback every 15 seconds
  pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => fetchLatest());

  // Realtime subscription (Fast Path)
  StreamSubscription? sub;
  try {
    sub = client
        .from('products')
        .stream(primaryKey: ['id'])
        .listen(
          (data) {
            ref.read(catalogRepositoryProvider).cacheProducts(data);
            final parsed = data
                .where((p) => p['is_enabled'] == true || p['is_enabled'] == 1)
                .map((p) => _parseProductDescription(p))
                .toList();
            parsed.sort(_sortProducts);
            if (!controller.isClosed) {
              controller.add(parsed);
            }
          },
          onError: (err) {
            debugPrint('Realtime allProducts error (falling back to polling): $err');
          },
          cancelOnError: false,
        );
  } catch (e) {
    debugPrint('Realtime allProducts setup failed: $e');
  }

  ref.onDispose(() {
    pollTimer?.cancel();
    sub?.cancel();
    controller.close();
  });

  return controller.stream;
});

// Product list provider based on catalog filters (Locally filtered from cached allProductsProvider)
final productListProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final allProductsAsync = ref.watch(allProductsProvider);
  final filter = ref.watch(catalogFilterProvider);

  return allProductsAsync.whenData((products) {
    var filtered = products;
    if (filter.categoryId != null) {
      filtered = filtered.where((p) => p['category_id'] == filter.categoryId).toList();
    }
    if (filter.search.isNotEmpty) {
      final searchLower = filter.search.toLowerCase();
      filtered = filtered.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final desc = (p['description'] ?? '').toString().toLowerCase();
        return name.contains(searchLower) || desc.contains(searchLower);
      }).toList();
    }
    return filtered;
  });
});

// Product detail provider family (Realtime Stream with Future fallback & Polling)
final productDetailsProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, productId) {
  final client = Supabase.instance.client;
  final controller = StreamController<Map<String, dynamic>?>();
  Timer? pollTimer;

  Future<void> fetchLatest() async {
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final res = await repo.getProductById(productId);
      final parsed = res != null ? _parseProductDescription(res) : null;
      if (!controller.isClosed) {
        controller.add(parsed);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Fetch immediately
  fetchLatest();

  // Polling fallback every 10 seconds
  pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => fetchLatest());

  // Realtime subscription (Fast Path)
  StreamSubscription? sub;
  try {
    sub = client
        .from('products')
        .stream(primaryKey: ['id'])
        .map((list) {
          final matched = list.where((p) => p['id'] == productId).toList();
          return matched.isNotEmpty ? _parseProductDescription(matched.first) : null;
        })
        .listen(
          (data) {
            if (!controller.isClosed) {
              controller.add(data);
            }
          },
          onError: (err) {
            debugPrint('Realtime productDetails error (falling back to polling): $err');
          },
          cancelOnError: false,
        );
  } catch (e) {
    debugPrint('Realtime productDetails setup failed: $e');
  }

  ref.onDispose(() {
    pollTimer?.cancel();
    sub?.cancel();
    controller.close();
  });

  return controller.stream;
});

// Popular products provider (Realtime Stream with Future fallback & Polling)
final popularProductsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<List<Map<String, dynamic>>>();
  Timer? pollTimer;

  Future<void> fetchLatest() async {
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final res = await repo.getProducts(forceRefresh: true);
      final filtered = List<Map<String, dynamic>>.from(res)
          .where((p) => p['is_enabled'] == true || p['is_enabled'] == 1)
          .toList();
      final parsed = filtered.map((p) => _parseProductDescription(p)).toList();
      parsed.sort(_sortProducts);
      if (!controller.isClosed) {
        controller.add(parsed);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Fetch immediately
  fetchLatest();

  // Polling fallback every 10 seconds
  pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => fetchLatest());

  // Realtime subscription (Fast Path)
  StreamSubscription? sub;
  try {
    sub = client
        .from('products')
        .stream(primaryKey: ['id'])
        .listen(
          (data) {
            ref.read(catalogRepositoryProvider).cacheProducts(data);
            final filtered = data.where((p) => p['is_enabled'] == true || p['is_enabled'] == 1).toList();
            final parsed = filtered.map((p) => _parseProductDescription(p)).toList();
            parsed.sort(_sortProducts);
            if (!controller.isClosed) {
              controller.add(parsed);
            }
          },
          onError: (err) {
            debugPrint('Realtime popularProducts error (falling back to polling): $err');
          },
          cancelOnError: false,
        );
  } catch (e) {
    debugPrint('Realtime popularProducts setup failed: $e');
  }

  ref.onDispose(() {
    pollTimer?.cancel();
    sub?.cancel();
    controller.close();
  });

  return controller.stream;
});

final orderNowProductsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<List<Map<String, dynamic>>>();
  Timer? pollTimer;

  Future<void> fetchLatest() async {
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final res = await repo.getProducts(forceRefresh: true);
      final parsed = List<Map<String, dynamic>>.from(res)
          .map((p) => _parseOrderNowProduct(p))
          .where((p) =>
              (p['order_now_is_available'] == true || p['order_now_is_available'] == 1) &&
              (p['is_enabled'] == null || p['is_enabled'] == true || p['is_enabled'] == 1))
          .toList();
      parsed.sort(_sortProducts);
      if (!controller.isClosed) {
        controller.add(parsed);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  fetchLatest();

  pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => fetchLatest());

  StreamSubscription? sub;
  try {
    sub = client
        .from('products')
        .stream(primaryKey: ['id'])
        .listen((data) {
          ref.read(catalogRepositoryProvider).cacheProducts(data);
          final parsed = List<Map<String, dynamic>>.from(data)
              .map((p) => _parseOrderNowProduct(p))
              .where((p) =>
                  (p['order_now_is_available'] == true || p['order_now_is_available'] == 1) &&
                  (p['is_enabled'] == null || p['is_enabled'] == true || p['is_enabled'] == 1))
              .toList();
          parsed.sort(_sortProducts);
          if (!controller.isClosed) {
            controller.add(parsed);
          }
        }, onError: (err) {
          debugPrint('Realtime Order Now products error (ignored): $err');
        });
  } catch (e) {
    debugPrint('Realtime Order Now stream creation failed: $e');
  }

  ref.onDispose(() {
    pollTimer?.cancel();
    sub?.cancel();
    controller.close();
  });

  return controller.stream;
});

final orderNowProductListProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final allProductsAsync = ref.watch(orderNowProductsProvider);
  final filter = ref.watch(catalogFilterProvider);

  return allProductsAsync.whenData((products) {
    var filtered = products;
    if (filter.categoryId != null) {
      filtered = filtered.where((p) => p['category_id'] == filter.categoryId).toList();
    }
    if (filter.search.isNotEmpty) {
      final searchLower = filter.search.toLowerCase();
      filtered = filtered.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final desc = (p['description'] ?? '').toString().toLowerCase();
        return name.contains(searchLower) || desc.contains(searchLower);
      }).toList();
    }
    return filtered;
  });
});

