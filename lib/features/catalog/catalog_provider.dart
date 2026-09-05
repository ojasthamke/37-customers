import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/providers.dart';
import '../../core/utils/product_helper.dart';

double? _asDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val.trim());
  return null;
}

Map<String, dynamic> _parseProductDescription(Map<String, dynamic> p) {
  final Map<String, dynamic> mapped = Map.from(p);
  final desc = p['description'] as String? ?? '';
  if (desc.trim().startsWith('{') && desc.trim().endsWith('}')) {
    try {
      final Map<String, dynamic> decoded = json.decode(desc);
      mapped['description'] = decoded['text'] as String? ?? '';
      mapped['cost_price'] = _asDouble(decoded['cost_price']) ?? 0.0;
      mapped['market_price'] = _asDouble(decoded['market_price'] ?? decoded['mrp']) ?? 0.0;
      mapped['stock'] = _asDouble(decoded['stock']) ?? 0.0;
      mapped['min_stock'] = _asDouble(decoded['min_stock']) ?? 0.0;
      mapped['barcode'] = decoded['barcode'] as String? ?? '';
      mapped['weight_per_piece'] = _asDouble(decoded['weight_per_piece']) ?? 0.25;
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
    final v = _asDouble(p['mrp']);
    if (v != null) mapped['market_price'] = v;
  }
  if (p['stock'] != null) {
    final v = _asDouble(p['stock']);
    if (v != null) mapped['stock'] = v;
  }
  if (p['price'] != null) {
    final v = _asDouble(p['price']);
    if (v != null) mapped['price'] = v;
  }

  // Preserve and normalize Order Now specific columns for independent checking
  mapped['order_now_stock'] = _asDouble(p['order_now_stock']) ?? 0.0;
  mapped['order_now_price'] = _asDouble(p['order_now_price']) ?? (_asDouble(mapped['price']) ?? 0.0);
  mapped['order_now_mrp'] = _asDouble(p['order_now_mrp']) ?? (_asDouble(mapped['market_price']) ?? 0.0);
  mapped['order_now_cost_price'] = _asDouble(p['order_now_cost_price']) ?? 0.0;
  mapped['order_now_is_available'] = p['order_now_is_available'] == null
      ? false
      : (p['order_now_is_available'] == true ||
          p['order_now_is_available'] == 1 ||
          p['order_now_is_available']?.toString() == '1' ||
          p['order_now_is_available']?.toString().toLowerCase() == 'true');

  final double homeStock = (mapped['stock'] as num?)?.toDouble() ?? 0.0;
  final bool homeAvailable = (p['is_available'] == null ||
      p['is_available'] == true ||
      p['is_available'] == 1 ||
      p['is_available']?.toString() == '1' ||
      p['is_available']?.toString().toLowerCase() == 'true');
  mapped['is_available'] = homeAvailable && homeStock > 0;
  mapped['is_enabled'] = ProductHelper.isEnabled(p);

  return mapped;
}

Map<String, dynamic> _parseOrderNowProduct(Map<String, dynamic> p) {
  final mapped = _parseProductDescription(p);
  
  // Store the standard normal price (Home section price) before override
  final normalPrice = _asDouble(p['price']) ?? 0.0;
  mapped['original_standard_price'] = normalPrice;

  final onPrice = _asDouble(p['order_now_price']);
  if (onPrice != null && onPrice > 0) {
    mapped['price'] = onPrice;
    mapped['selling_price'] = onPrice;
  }
  final onMrp = _asDouble(p['order_now_mrp']);
  if (onMrp != null && onMrp > 0) {
    mapped['market_price'] = onMrp;
    mapped['mrp'] = onMrp;
  }

  // ORDER NOW STOCK IS STRICTLY INDEPENDENT OF NORMAL HOME STOCK
  final double onStock = _asDouble(p['order_now_stock']) ?? 0.0;
  mapped['order_now_stock'] = onStock;
  mapped['stock'] = onStock;

  final bool parentEnabled = ProductHelper.isEnabled(p);
  final bool onAvailable = p['order_now_is_available'] == null
      ? false
      : (p['order_now_is_available'] == true ||
          p['order_now_is_available'] == 1 ||
          p['order_now_is_available']?.toString() == '1' ||
          p['order_now_is_available']?.toString().toLowerCase() == 'true');
  mapped['order_now_is_available'] = onAvailable;
  mapped['is_available'] = onAvailable && onStock > 0;
  mapped['is_enabled'] = parentEnabled && onAvailable;
  mapped['is_order_now'] = true;

  mapped['order_now_price'] = _asDouble(p['order_now_price']) ?? (_asDouble(mapped['price']) ?? 0.0);
  mapped['order_now_mrp'] = _asDouble(p['order_now_mrp']) ?? (_asDouble(mapped['market_price']) ?? 0.0);

  // Determine the price off percent
  double? manualPercent;
  if (p['price_off_percent'] != null) {
    manualPercent = _asDouble(p['price_off_percent']);
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
  final double? aStockNum = (a['stock'] as num?)?.toDouble() ?? double.tryParse(a['stock']?.toString() ?? '');
  final double? bStockNum = (b['stock'] as num?)?.toDouble() ?? double.tryParse(b['stock']?.toString() ?? '');
  final bool aAvail = (a['is_available'] == null || a['is_available'] == true || a['is_available'] == 1) &&
      (a['is_enabled'] != false && a['is_enabled'] != 0) &&
      (aStockNum == null || aStockNum > 0);
  final bool bAvail = (b['is_available'] == null || b['is_available'] == true || b['is_available'] == 1) &&
      (b['is_enabled'] != false && b['is_enabled'] != 0) &&
      (bStockNum == null || bStockNum > 0);
  
  if (aAvail != bAvail) {
    return aAvail ? -1 : 1;
  }
  
  final String aName = (a['name'] ?? '').toString().toLowerCase();
  final String bName = (b['name'] ?? '').toString().toLowerCase();
  return aName.compareTo(bName);
}

// Categories list provider (Realtime Stream with Future fallback & Polling)
final categoriesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<List<Map<String, dynamic>>>();
  Timer? pollTimer;
  bool hasEmittedData = false;
  int currentSeq = 0;
  int latestCommittedSeq = 0;
  
  Future<void> fetchLatest() async {
    final int mySeq = ++currentSeq;
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final res = await repo.getCategories(onRefresh: (freshData) {
        if (mySeq < latestCommittedSeq) return;
        final filtered = List<Map<String, dynamic>>.from(freshData)
            .where((c) => c['is_enabled'] == true || c['is_enabled'] == 1)
            .toList();
        if (!controller.isClosed) {
          latestCommittedSeq = mySeq;
          hasEmittedData = true;
          controller.add(filtered);
        }
      });
      if (mySeq < latestCommittedSeq) return;
      final filtered = List<Map<String, dynamic>>.from(res)
          .where((c) => c['is_enabled'] == true || c['is_enabled'] == 1)
          .toList();
      if (!controller.isClosed) {
        latestCommittedSeq = mySeq;
        hasEmittedData = true;
        controller.add(filtered);
      }
    } catch (e) {
      if (!controller.isClosed && !hasEmittedData) {
        controller.addError(e);
      } else {
        debugPrint('categoriesProvider: Remote fetch error (preserving cached data): $e');
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
            final int rtSeq = ++currentSeq;
            latestCommittedSeq = rtSeq;
            if (!controller.isClosed) {
              hasEmittedData = true;
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
  bool hasEmittedData = false;
  int currentSeq = 0;
  int latestCommittedSeq = 0;

  Future<void> fetchLatest() async {
    final int mySeq = ++currentSeq;
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final res = await repo.getProducts(onRefresh: (freshData) {
        if (mySeq < latestCommittedSeq) return;
        final parsed = List<Map<String, dynamic>>.from(freshData)
            .where((p) => p['is_enabled'] != false && p['is_enabled'] != 0 && p['is_enabled']?.toString() != '0' && p['is_enabled']?.toString().toLowerCase() != 'false')
            .map((p) => _parseProductDescription(p))
            .toList();
        parsed.sort(_sortProducts);
        if (!controller.isClosed) {
          latestCommittedSeq = mySeq;
          hasEmittedData = true;
          controller.add(parsed);
        }
      });
      if (mySeq < latestCommittedSeq) return;
      final parsed = List<Map<String, dynamic>>.from(res)
          .where((p) => p['is_enabled'] != false && p['is_enabled'] != 0 && p['is_enabled']?.toString() != '0' && p['is_enabled']?.toString().toLowerCase() != 'false')
          .map((p) => _parseProductDescription(p))
          .toList();
      parsed.sort(_sortProducts);
      if (!controller.isClosed) {
        latestCommittedSeq = mySeq;
        hasEmittedData = true;
        controller.add(parsed);
      }
    } catch (e) {
      if (!controller.isClosed && !hasEmittedData) {
        controller.addError(e);
      } else {
        debugPrint('allProductsProvider: Remote fetch error (preserving cached data): $e');
      }
    }
  }

  // Fetch immediately
  fetchLatest();

  // Polling fallback every 60 seconds
  pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => fetchLatest());

  // Realtime subscription (Fast Path)
  StreamSubscription? sub;
  try {
    sub = client
        .from('products')
        .stream(primaryKey: ['id'])
        .listen(
          (data) {
            final int rtSeq = ++currentSeq;
            latestCommittedSeq = rtSeq;
            ref.read(catalogRepositoryProvider).cacheProducts(data);
            final parsed = data
                .where((p) => p['is_enabled'] != false && p['is_enabled'] != 0 && p['is_enabled']?.toString() != '0' && p['is_enabled']?.toString().toLowerCase() != 'false')
                .map((p) => _parseProductDescription(p))
                .toList();
            parsed.sort(_sortProducts);
            if (!controller.isClosed) {
              hasEmittedData = true;
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
final productDetailsProvider = StreamProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, productId) {
  final client = Supabase.instance.client;
  final controller = StreamController<Map<String, dynamic>?>();
  Timer? pollTimer;
  bool hasEmittedData = false;
  int currentSeq = 0;
  int latestCommittedSeq = 0;

  Future<void> fetchLatest() async {
    final int mySeq = ++currentSeq;
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final res = await repo.getProductById(productId);
      if (mySeq < latestCommittedSeq) return;
      final parsed = res != null ? _parseProductDescription(res) : null;
      if (!controller.isClosed) {
        latestCommittedSeq = mySeq;
        if (parsed != null) hasEmittedData = true;
        controller.add(parsed);
      }
    } catch (e) {
      if (!controller.isClosed && !hasEmittedData) {
        controller.addError(e);
      } else {
        debugPrint('productDetailsProvider: Remote fetch error (preserving cached data): $e');
      }
    }
  }

  // Fetch immediately
  fetchLatest();

  // Polling fallback every 60 seconds
  pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => fetchLatest());

  // Realtime subscription (Fast Path)
  StreamSubscription? sub;
  try {
    sub = client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('id', productId)
        .listen(
          (data) {
            final int rtSeq = ++currentSeq;
            latestCommittedSeq = rtSeq;
            if (data.isNotEmpty) {
              final parsed = _parseProductDescription(data.first);
              if (!controller.isClosed) {
                hasEmittedData = true;
                controller.add(parsed);
              }
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
  bool hasEmittedData = false;
  int currentSeq = 0;
  int latestCommittedSeq = 0;

  Future<void> fetchLatest() async {
    final int mySeq = ++currentSeq;
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final res = await repo.getProducts(forceRefresh: true);
      if (mySeq < latestCommittedSeq) return;
      final filtered = List<Map<String, dynamic>>.from(res)
          .where((p) => p['is_enabled'] != false && p['is_enabled'] != 0)
          .toList();
      final parsed = filtered.map((p) => _parseProductDescription(p)).toList();
      parsed.sort(_sortProducts);
      if (!controller.isClosed) {
        latestCommittedSeq = mySeq;
        hasEmittedData = true;
        controller.add(parsed);
      }
    } catch (e) {
      if (!controller.isClosed && !hasEmittedData) {
        controller.addError(e);
      } else {
        debugPrint('popularProductsProvider: Remote fetch error (preserving cached data): $e');
      }
    }
  }

  // Fetch immediately
  fetchLatest();

  // Polling fallback every 60 seconds
  pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => fetchLatest());

  // Realtime subscription (Fast Path)
  StreamSubscription? sub;
  try {
    sub = client
        .from('products')
        .stream(primaryKey: ['id'])
        .listen(
          (data) {
            final int rtSeq = ++currentSeq;
            latestCommittedSeq = rtSeq;
            ref.read(catalogRepositoryProvider).cacheProducts(data);
            final filtered = data.where((p) => p['is_enabled'] != false && p['is_enabled'] != 0).toList();
            final parsed = filtered.map((p) => _parseProductDescription(p)).toList();
            parsed.sort(_sortProducts);
            if (!controller.isClosed) {
              hasEmittedData = true;
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
  bool hasEmittedData = false;
  int currentSeq = 0;
  int latestCommittedSeq = 0;

  Future<void> fetchLatest() async {
    final int mySeq = ++currentSeq;
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final res = await repo.getProducts(forceRefresh: true);
      if (mySeq < latestCommittedSeq) return;
      final parsed = List<Map<String, dynamic>>.from(res)
          .where((p) => ProductHelper.isOrderNowConfigured(p))
          .map((p) => _parseOrderNowProduct(p))
          .toList();
      parsed.sort(_sortProducts);
      if (!controller.isClosed) {
        latestCommittedSeq = mySeq;
        hasEmittedData = true;
        controller.add(parsed);
      }
    } catch (e) {
      if (!controller.isClosed && !hasEmittedData) {
        controller.addError(e);
      } else {
        debugPrint('orderNowProductsProvider: Remote fetch error (preserving cached data): $e');
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
          final int rtSeq = ++currentSeq;
          latestCommittedSeq = rtSeq;
          ref.read(catalogRepositoryProvider).cacheProducts(data);
          final parsed = List<Map<String, dynamic>>.from(data)
              .where((p) => ProductHelper.isOrderNowConfigured(p))
              .map((p) => _parseOrderNowProduct(p))
              .toList();
          parsed.sort(_sortProducts);
          if (!controller.isClosed) {
            hasEmittedData = true;
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

