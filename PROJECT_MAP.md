Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Codebase Project Map - ApliBhaji Customer App

This document maps out the core directories, source files, classes, and interactions within the `aplibhaji_customer` codebase.

---

## Folder Structure Summary

```text
lib/
├── core/
│   ├── database/     # SQLite local db helper, repositories, cache repository wrappers, DI providers
│   ├── services/     # FCM notifications, rate limiter, secure storage, offline queue sync
│   ├── theme/        # Material 3 light/dark custom theme definitions
│   ├── utils/        # Schedule calculations, security hashing, string sanitizers
│   └── widgets/      # Ambient backgrounds, glassmorphism, pill selectors, skeletons, text painters
├── features/
│   ├── auth/         # Login, registrations, password setup, security checkers
│   ├── cart/         # Normal/Quick order cart manager, POS rounding, list screens
│   ├── catalog/      # Real-time category/product streams, listing, detail screens
│   ├── checkout/     # Pre-validation checkouts, schedule matching, order placement
│   ├── dashboard/    # HomeScreen container, live order trackers, schedule countdown banner
│   ├── order/        # Order history filters, step-by-step progress status tracking
│   ├── profile/      # User info display, area/route details, support help sheets
│   └── splash/       # App initialization, token check, route navigator
└── main.dart         # Global entry point initializing databases and notifications
```

---

## Core Database & Storage Files

### lib/core/database/database_helper.dart

- **Purpose**: Singleton database helper managing local SQLite creation, structural migrations (v1-v9), cache TTL tracking, and database wipes.
- **Main Classes**: `DatabaseHelper`
- **Feature Group**: Core Infrastructure
- **Key Functions**:
  - `database` (Async getter instantiating DB or returning instance)
  - `_initDatabase()` (Differentiates path for FFI Windows desktop vs Documents directory on iOS/Android)
  - `isCacheStale(key, ttl)` (Compares last synced timestamp in `cache_metadata` against current time)
  - `updateLastSynced(key)` (Upserts sync timestamp)
  - `clearDatabase()` (Truncates cached catalog tables and offline queues on user logout)
- **Dependencies**: `sqflite`, `sqflite_common_ffi`, `path_provider`, `path`
- **Interacts With**: `caching_repositories.dart`, `repositories.dart`, `auth_rate_limiter.dart`

---

### lib/core/database/repositories.dart

- **Purpose**: Defines abstract repository contracts for Catalog, Customer, and Order systems along with concrete implementations for SQLite (local cached fallback) and Supabase (remote API/database).
- **Main Classes**:
  - `CatalogRepository` (Abstract)
  - `CustomerRepository` (Abstract)
  - `OrderRepository` (Abstract)
  - `SQLiteCatalogRepository`, `SupabaseCatalogRepository`
  - `SQLiteCustomerRepository`, `SupabaseCustomerRepository`
  - `SQLiteOrderRepository`, `SupabaseOrderRepository`
- **Feature Group**: Core Data Layer
- **Dependencies**: `supabase_flutter`, `uuid`
- **Interacts With**: `caching_repositories.dart`

---

### lib/core/database/caching_repositories.dart

- **Purpose**: Implements the cache-through pattern (Cache-Aside / Repository wrapper). It serves local SQLite data instantly, evaluates cache TTL rules, executes background Supabase queries, updates local tables, and executes callback updates for UI hot-reloading.
- **Main Classes**:
  - `CachingCatalogRepository`
  - `CachingCustomerRepository`
  - `CachingOrderRepository`
- **Feature Group**: Core Caching Layer
- **Key Functions**:
  - `getCategories()` (Served from cache; background revalidated if stale)
  - `getProducts()` (Supports remote search and category filter falls back to local index on failure)
  - `getLoggedInCustomer()` (Fetches and updates route names; forces revalidation if route IDs lack localized road/sub-road names)
  - `placeOrder()` (If network is offline, queues order inside local database with `pending` status)
- **Dependencies**: `connectivity_plus`, `sqflite`, `repositories.dart`, `database_helper.dart`
- **Interacts With**: Providers, State Notifiers, `sync_service.dart`

---

### lib/core/database/providers.dart

- **Purpose**: Acts as the dependency injection registry using Riverpod. Injects concrete caching repositories.
- **Main Classes**: None (Riverpod declarations)
- **Feature Group**: Dependency Injection
- **Providers**: `catalogRepositoryProvider`, `customerRepositoryProvider`, `orderRepositoryProvider`
- **Interacts With**: `catalog_provider.dart`, `auth_provider.dart`, `order_provider.dart`

---

## Core Services Files

### lib/core/services/auth_rate_limiter.dart

- **Purpose**: Implements persistent security lockouts for credentials brute-forcing. Survives application process kills and device restarts.
- **Main Classes**: `AuthRateLimiter`
- **Rules**:
  - 10 failed login attempts $\rightarrow$ 1-Hour Lockout.
  - If 1-Hour Lockout occurs 8 times $\rightarrow$ 3-Day Lockout.
- **Key Functions**:
  - `recordFailedAttempt()` (Increments failed attempts; applies lockouts if threshold met)
  - `recordSuccessfulLogin()` (Resets counters)
  - `isLockedOut()` (Checks timestamp)
- **Dependencies**: `uuid`, `database_helper.dart`
- **Interacts With**: `login_screen.dart`, `auth_provider.dart`

---

### lib/core/services/notification_service.dart

- **Purpose**: Singleton handling background message handlers, APNS/FCM registrations, local timezone calculations, and deep-linking routing to specific screens upon notification taps.
- **Main Classes**: `NotificationService`
- **Key Functions**:
  - `init()` (Initializes FCM background listeners and local channel details)
  - `registerFCMToken(userId)` (Updates Supabase profiles table with active device token)
  - `clearFCMToken(userId)` (Wipes token on logout)
  - `_handleNotificationPayload()` (Extracts `order_number` and routes navigation)
- **Dependencies**: `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `timezone`, `flutter_timezone`
- **Interacts With**: `main.dart`, `auth_provider.dart`, `order_details_screen.dart`

---

### lib/core/services/secure_local_storage.dart

- **Purpose**: Extends Supabase `LocalStorage` base class. Writes credentials to operating system keychain securely.
- **Main Classes**: `SecureLocalStorage`
- **Dependencies**: `supabase_flutter`, `flutter_secure_storage`
- **Interacts With**: `main.dart` (Passed to Supabase initialize configuration options)

---

### lib/core/services/sync_service.dart

- **Purpose**: Connection-monitoring service that triggers automatic flushing of local pending orders once network becomes active.
- **Main Classes**: `SyncService`
- **Key Functions**:
  - `init()` (Subscribes to connectivity updates)
  - `syncPendingOrders()` (Fetches offline rows, submits through `place_order_secure` RPC with idempotency validation, marks as synced)
- **Dependencies**: `connectivity_plus`, `caching_repositories.dart`
- **Interacts With**: `main.dart`

---

## Features Mapping

### Authentication (lib/features/auth/)

- **`auth_provider.dart`**: Implements Riverpod `AuthNotifier` to track session state (`AuthState`). Handles sign-in, guest registration, password updates, and registers push tokens.
- **`login_screen.dart`**: Entry page offering Guest checkout, normal customer code login, reset password links, and support hotline shortcuts.
- **`password_rules_helper.dart`**: Visual rule validator rendering password strength guidelines dynamically.
- **`register_screen.dart`**: Cascading address form showing dynamic Areas, Roads, and Sub-roads fetched from Supabase.

---

### Catalog (lib/features/catalog/)

- **`catalog_provider.dart`**: Contains StreamProviders that listen to remote Supabase channels for categories/products, alongside search/category filters and metadata JSON parser.
- **`product_listing_screen.dart`**: Multi-grid catalog browser page with quick searches and unit indicators.
- **`product_details_screen.dart`**: Displays product specifications, Rx medication warning badges, expiry dates, and dosage fields.
- **`order_now_screen.dart`**: Real-time hot deals catalog (Order Now tab). Updates prices dynamically and triggers count updates.
- **`categories_screen.dart`**: Lists all catalog categories.

---

### Cart & Checkout (lib/features/cart/ & lib/features/checkout/)

- **`cart_provider.dart`**: Separates normal carts and quick delivery carts. Evaluates store status parameters and rounds cart sums up to the nearest multiple of 5.
- **`cart_screen.dart`**: Screen hosting normal/quick cart toggles, dynamic warning banners, and items list.
- **`checkout_screen.dart`**: Validates stock levels, confirms delivery schedule dates, and submits orders.
- **`order_confirmation_screen.dart`**: Order receipt rendering screen. Vibrates on load, displays printer receipt dispenser animation, and launches WhatsApp text receipt sharing.

---

### Dashboard, Orders & Profile (lib/features/dashboard/, lib/features/order/, lib/features/profile/)

- **`home_screen.dart`**: Master Scaffold container. Listens for route notifications, loads active order tracker carousels, and contains categories slides.
- **`schedule_banner.dart`**: Header counting down cutoff times (IST timezone) or notifying of store closure.
- **`order_provider.dart`**: Subscribes to customer order listings via real-time streams and holds offline pending order state.
- **`my_orders_screen.dart`**: Filtered order history listing (All, Pre-orders, Active, Delivered).
- **`order_details_screen.dart`**: Vertical tracker (Placed, Preparing, On the way, Delivered) with items receipt and support actions.
- **`profile_screen.dart`**: Customer profile options, password adjustments, terms sheets, and logout routines.
- **`splash_screen.dart`**: Initialization page restoring storage sessions and checking token expiration.
