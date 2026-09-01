Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# State Management Map - ApliBhaji Customer App

This document maps out the Riverpod state providers, their lifecycles, and their interactions across features.

---

## 1. Authentication State Provider

### `authProvider`

Manages customer session state.

```text
                  +--------------------------------+
                  |         authProvider           |
                  +---------------+----------------+
                                  |
                                  | Observes / Subscribes
                                  v
                  +--------------------------------+
                  | Supabase.auth.onAuthStateChange|
                  +---------------+----------------+
                                  |
                  ┌───────────────┼───────────────┐
                  ▼ (Sign In)     ▼ (Sign Out)    ▼ (Token Expired)
             [Load Profile]    [Wipe Storage]   [Force Login]
```

- **Type**: `StateNotifierProvider<AuthNotifier, AuthState>`
- **Responsibilities**:
  - Subscribes to `Supabase.instance.client.auth.onAuthStateChange` to monitor sessions.
  - Updates profile data and route details in SQLite when authentication states change.
  - Registers FCM tokens on login and clears them on logout.
  - Provides session data to other providers (e.g. `orderListProvider`, `cartProvider`).

---

## 2. Catalog Stream Providers

Provide real-time updates for product catalogs and categories.

```text
                  [allProductsProvider] ──► [Real-time Supabase Stream]
                           │
                           ▼ (Cascades)
                 [productListProvider]
                           │
                   (Applies filters)
                           ▼
                  [catalogFilterProvider]
```

- **`categoriesProvider`**
  - **Type**: `StreamProvider<List<Map<String, dynamic>>>`
  - **Source**: Listens to the remote `categories` table and falls back to SQLite if offline.
- **`allProductsProvider`**
  - **Type**: `StreamProvider<List<Map<String, dynamic>>>`
  - **Source**: Listens to the remote `products` table, parses JSON metadata descriptions, and caches results in SQLite.
- **`catalogFilterProvider`**
  - **Type**: `StateNotifierProvider<CatalogFilterNotifier, CatalogFilter>`
  - **Source**: Stores search filters and category tags.
- **`productListProvider`**
  - **Type**: `Provider<AsyncValue<List<Map<String, dynamic>>>>`
  - **Source**: Combines `allProductsProvider` and `catalogFilterProvider` to return a filtered list of products.
- **`orderNowProductsProvider`**
  - **Type**: `StreamProvider<List<Map<String, dynamic>>>`
  - **Source**: Listens for updates in the `products` table, returning items with active quick-order flags.

---

## 3. Cart State Providers

Manage cart items, quantities, and delivery types (Normal vs Quick Order).

- **`cartProvider`**
  - **Type**: `StateNotifierProvider<CartNotifier, CartState>`
  - **Source**: Manages normal cart items, serializes cart state to SQLite, and recalculates grand totals.
- **`quickCartProvider`**
  - **Type**: `StateNotifierProvider<CartNotifier, CartState>`
  - **Source**: Manages items added via the "Order Now" flash-sale view.
- **`isViewingQuickOrderCartProvider`**
  - **Type**: `StateProvider<bool>`
  - **Source**: Tracks which cart (Normal or Quick Order) the user is currently viewing.
- **`activeCartProvider`**
  - **Type**: `Provider<CartState>`
  - **Source**: Returns the active cart state based on the value of `isViewingQuickOrderCartProvider`.
- **`activeCartNotifierProvider`**
  - **Type**: `Provider<CartNotifier>`
  - **Source**: Returns the active cart controller.

---

## 4. Order State Providers

Manage order history and real-time status updates.

- **`orderListProvider`**
  - **Type**: `StateNotifierProvider<OrderListNotifier, AsyncValue<List<Map<String, dynamic>>>>`
  - **Source**:
    - Listens to order updates for the active customer ID.
    - Synchronizes offline pending orders with the remote database once connection is restored.
- **`orderDetailsProvider(orderId)`**
  - **Type**: `StreamProvider<OrderFullDetails>`
  - **Source**: Listens to changes in individual order records and returns item lines, delivery coordinates, and status updates.
