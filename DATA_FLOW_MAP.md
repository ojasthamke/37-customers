Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Data Flow Map - ApliBhaji Customer App

This document outlines the end-to-end data flows, detailing how user inputs, background synchronizations, database changes, and network states move data through the application.

---

## 1. Authentication Flow (Customer Code & Password)

1. **User Action**: The customer enters their code (e.g. `OK1025`) and password on the `LoginScreen`.
2. **Brute Force Defense**: The UI queries `AuthRateLimiter.isLockedOut()`.
   - **If locked**: Displays a lockout banner containing the remaining time in minutes/seconds.
   - **If open**: Passes parameters to `authProvider.loginWithCodeAndPassword(code, password)`.
3. **Repository Pipeline**:
   - `AuthNotifier` invokes `CachingCustomerRepository.loginWithCodeAndPassword(code, password)`.
   - The caching repository forwards the request to `SupabaseCustomerRepository`.
4. **Supabase Authentication**:
   - The email is formatted as `${code.toLowerCase()}@aplibhaji.com`.
   - The password is encrypted using a secure app-specific SHA-256 helper: `SecurityHelper.hashPassword(password)`.
   - Performs `Supabase.client.auth.signInWithPassword(...)`.
5. **Data Enrichment**:
   - On successful token generation, the customer record is fetched from the Supabase `customers` table with a SQL `JOIN` mapping corresponding `areas`, `roads`, and `sub_roads`.
6. **Local Cache Sync**:
   - The fetched customer profile is written into the SQLite `customers` table, setting `is_logged_in = 1`.
   - `AuthRateLimiter` resets failed counters to `0`.
7. **UI Update**:
   - Riverpod pushes the new state to all listeners of `authProvider`.
   - The user is navigated to the `HomeScreen`.

---

## 2. Dynamic Area Scheduling & Cutoff Flow

```text
[Supabase Area/Customer Metadata] 
               │
               ▼ (Fetched on login or cache revalidation)
       [SQLite Cache] (is_guest, delivery_schedule, cutoff_time)
               │
               ▼ (Loaded by schedule_banner.dart)
   [AreaScheduleHelper.calculateDetails()] 
               │
    ┌──────────┴──────────┐
    ▼ (openToday)         ▼ (closedToday)
[Normal Delivery]     [Pre-Order Mode]
   (Cutoff Countdown)    (Next Open Date)
```

1. **Information Load**: On initialization, `HomeScreen` reads `customer` metadata from `authProvider`.
2. **Parser Execution**: The schedule configuration (e.g. `['Monday', 'Thursday']` and `20:00:00`) is parsed by `AreaScheduleHelper.calculateDetails()`.
3. **Time Correction**: The calculation parses current timezone parameters, converting `DateTime.now()` to the authoritative Indian Standard Time (IST / UTC+5:30) via `getKolkataTime()`.
4. **State Evaluation**:
   - **`openToday`**: If today matches the delivery schedule and the current time is before the cutoff, the banner displays a live ticking countdown of the remaining ordering hours. Orders placed are marked as **Normal**.
   - **`closedToday`**: If today is not in the schedule or the cutoff time has passed, the banner switches to Pre-Order mode, indicating the next order date and delivery date. Orders placed are marked as **Pre-Order**.
   - **`noSchedule`**: If no delivery schedule is defined for the customer's area, ordering capabilities are disabled.

---

## 3. Order Placement & Offline Queuing Flow

1. **Cart Submission**: The customer clicks "Place Order" on `CheckoutScreen`.
2. **Local Validation**: Cart items, delivery addresses, and schedules are loaded.
3. **Price/Stock Pre-check**:
   - The app verifies catalog prices and stock availability on Supabase. If prices changed or stock became insufficient, the checkout halts, updates the cart locally, and requests the user to review the cart.
4. **Network Detection**:
   - **If Online**:
     - The repository calls the Supabase RPC `place_order_secure` with parameters including the cart items list, delivery date, order type, and a unique `idempotency_key` (local UUID).
     - Supabase processes the RPC, writes to `orders` and `order_items` inside PostgreSQL, and returns the server-generated order ID and number.
     - SQLite marks the order as `synced` and saves the server receipt.
   - **If Offline**:
     - SQLite inserts the order with `sync_status = 'pending'`, generating a temporary offline order number prefix (`OLO-YYYYMMDD-XXX`).
     - The local cart database is cleared immediately to prevent double submission.
5. **Celebration Trigger**:
   - The UI redirects the customer to `OrderConfirmationScreen`.
   - Triggers a 2-second confirmation vibration (`HapticFeedback.vibrate()`).
   - Displays the printing ticket receipt animation.

---

## 4. Offline Order Syncing Flow

```text
[Network Offline] ────────► [Save Order to SQLite with sync_status = 'pending']
                                                     │
                                           (Connectivity Restored)
                                                     ▼
[Supabase RPC secure_place_order] ◄─────── [SyncService monitors Connection]
        │
        ├─► Success ──► [Update SQLite sync_status = 'synced', save Server ID]
        └─► Failure ──► [Mark SQLite sync_status = 'failed', record Error]
```

1. **Connectivity Listener**: `SyncService` monitors `Connectivity().onConnectivityChanged`.
2. **Trigger**: When the device regains connection, `syncPendingOrders()` is executed.
3. **Queue Processing**:
   - Fetches all SQLite rows where `sync_status = 'pending'` or `sync_status = 'failed'`.
   - Iterates through the queue, fetching matching order items from SQLite.
4. **Idempotent Submission**:
   - Submits the order via the `placeOrder` Supabase RPC. The local order's UUID is used as the `idempotencyKey`.
   - If the server has already processed this UUID, it returns the existing record rather than creating a duplicate.
5. **Sync Resolution**:
   - **Success**: SQLite marks the local order as `synced`, updating the temporary ID to the database UUID and recording the server-assigned order number.
   - **Failure**: Marks the local record as `failed` with the error description appended for diagnostic checks.

---

## 5. Real-Time Catalog Updates Flow

1. **Backend Event**: An administrator updates a product price or stock count in the Supabase database.
2. **WebSocket Dispatch**: The change triggers a Postgres change event on the Supabase Realtime channel.
3. **Stream Provider Injection**:
   - `orderNowProductsProvider` and `allProductsProvider` listen to the Supabase stream.
   - The incoming stream event parses product parameters (decoding JSON description payloads).
4. **Cache Updates**:
   - The updated catalog is written back to SQLite, updating the `products` cache.
   - The metadata table updates the `last_synced_at` timestamp.
5. **UI Rendering**:
   - Riverpod notifies listeners, triggering a rebuild of listing widgets, detail screens, and discount labels without requiring manual pull-to-refresh action.
2. **Settings Change**:
   - Updates `store_settings` and `order_now_status` from metadata checks.
