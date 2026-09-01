Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Cache Map - ApliBhaji Customer App

This document details the cache tables, synchronization flags, Time-To-Live (TTL) policies, local-first logic, and background revalidation pathways.

---

## 1. Cache Tables and Sync Flags

The local database (`aplibhaji_customers.db`) caches remote data using the following tables:

| SQLite Table | Cache Key | Synchronized Field / Table | Offline Write Support |
| :--- | :--- | :--- | :--- |
| `categories` | `categories` | Supabase `categories` | No (Read-Only Cache) |
| `products` | `products` | Supabase `products` | No (Read-Only Cache) |
| `customers` | `customer_profile` | Supabase `customers` | Yes (Profile details write to both SQLite and Supabase) |
| `orders` | `orders_{phone}` | Supabase `orders` | Yes (Pending orders written with `sync_status = 'pending'`) |
| `settings` | `store_settings` | Supabase `settings` | Yes (Serialized cart items saved locally) |
| `cache_metadata`| N/A | Tracks sync timestamps for keys | N/A |

---

## 2. Time-To-Live (TTL) Configuration

`DatabaseHelper` evaluates cache freshness by comparing the current timestamp against the last synced timestamp stored in the `cache_metadata` table:

```dart
Future<bool> isCacheStale(String key, Duration ttl) async {
  final res = await db.query('cache_metadata', where: 'key = ?', whereArgs: [key]);
  if (res.isEmpty) return true; // Cache miss
  final lastSyncedStr = res.first['last_synced_at'] as String?;
  if (lastSyncedStr == null) return true;
  final lastSynced = DateTime.tryParse(lastSyncedStr);
  if (lastSynced == null) return true;
  return DateTime.now().difference(lastSynced) > ttl;
}
```

The app applies specific TTL durations based on the data type:

- **Categories**: `Duration(hours: 2)`
- **Products Catalog**: `Duration(minutes: 30)`
- **Individual Product Details**: `Duration(minutes: 10)`
- **Store Settings**: `Duration(hours: 1)`
- **Orders History**: `Duration(minutes: 1)`
- **Customer Profile**: `Duration(minutes: 5)`
  - **Self-Healing Condition**: The profile cache is marked as stale if route IDs are configured but their corresponding name labels are missing:
    `hasMissingRouteFields = (area_id != null && area_name == null) || (road_id != null && road_name == null) || (sub_road_id != null && sub_road_name == null)`. This forces a refresh to fetch the missing route names.

---

## 3. Local-First Caching & Revalidation Flow

```text
[Request Data (e.g. getCategories)]
                 │
                 ▼
      [Query SQLite Cache]
                 │
       ┌─────────┴─────────┐
       ▼ (Cache Empty)     ▼ (Cache Present)
   [Block on API]          [Return SQLite Data Immediately]
       │                                   │
       ▼                                   ▼
 [Save to SQLite]                 [Check Cache TTL Stale]
       │                                   │
       ▼                                   ├───────────────┐
  [Return UI]                              ▼ (Stale)       ▼ (Fresh)
                                   [Background API]     [Stop]
                                           │
                                           ▼
                                   [Update SQLite]
                                           │
                                           ▼
                                   [Reload UI state]
```

1. **Immediate Cache Return**: When data is requested, the repository queries the local SQLite table. If data is present, it is returned immediately to keep the UI responsive.
2. **TTL Evaluation**:
   - If the cache is empty (cache miss), the app blocks the UI and fetches the data from the remote API.
   - If the cache contains data but the TTL has expired, the repository triggers a background revalidation request to the remote server.
3. **Background Update**: The background API request fetches the latest data, updates the local SQLite tables, writes the new sync timestamp to `cache_metadata`, and notifies Riverpod to refresh the UI with the updated data.
