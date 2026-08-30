import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories.dart';
import 'caching_repositories.dart';

/// Use caching repositories that wrap Supabase with SQLite fallback.
/// Online: Supabase → cache to SQLite → return
/// Offline: return SQLite cache / queue orders locally
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => CachingCatalogRepository());
final customerRepositoryProvider = Provider<CustomerRepository>((ref) => CachingCustomerRepository());
final orderRepositoryProvider = Provider<OrderRepository>((ref) => CachingOrderRepository());
