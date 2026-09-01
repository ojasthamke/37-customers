Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Customer Profile Flow - ApliBhaji Customer App

This document details how the application fetches, caches, updates, and validates customer profile details, including delivery area schedules and cascading routes.

---

## 1. Profile Loading & Caching Flow

```text
                      [App Initialized / Restored]
                                   │
                                   ▼
                   [Read SQLite Local Customer Row]
                                   │
                 ┌─────────────────┴─────────────────┐
                 ▼ (Cache Hit & Fresh)               ▼ (Cache Miss / Stale)
          [Return Cache]                     [Fetch Remote Supabase]
                                                     │
                                                     ▼
                                            [Upsert SQLite Cache]
                                                     │
                                                     ▼
                                            [Notify Riverpod UI]
```

1. **App Startup**: The `SplashScreen` runs `authProvider.loadCurrentCustomer()`.
2. **Local Cache Read**:
   - `CachingCustomerRepository.getLoggedInCustomer()` checks SQLite for a customer record with `is_logged_in = 1`.
   - If found, it returns the cached profile immediately to speed up app loading.
3. **Staleness Evaluation**:
   - The app checks if the cache is stale using `DatabaseHelper.isCacheStale('customer_profile', Duration(minutes: 5))`.
   - **Validation Check**: It also checks if the cached profile is missing name labels for its configured routes:
     `hasMissingRouteFields = (area_id != null && area_name == null) || (road_id != null && road_name == null) || (sub_road_id != null && sub_road_name == null)`.
   - If route names are missing, it flags the cache as stale to force a refresh.
4. **Remote Fetch**:
   - If the cache is stale or missing, the repository queries Supabase:
     `Supabase.client.from('customers').select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)').eq('auth_user_id', current_user_id).single()`.
5. **Cache Update**:
   - The fetched profile, along with the joined route names, is written to SQLite.
   - The `cache_metadata` table is updated with the sync time.
6. **UI Refresh**: Riverpod updates the state, and the UI displays the profile data.

---

## 2. Address & Route Cascades (Registration Flow)

When registering a new customer, the app retrieves and displays address hierarchies from the database.

```text
                  [Load Active Areas]
                           │
                           ▼
                  [Select Area Id]
                           │
                           ▼ (Cascades)
         [Fetch Roads matching Selected Area Id]
                           │
                           ▼
                  [Select Road Id]
                           │
                           ▼ (Cascades)
       [Fetch Sub-Roads matching Selected Road Id]
```

1. **Area Selection**:
   - `RegisterScreen` loads all active areas from Supabase:
     `Supabase.client.from('areas').select('id, name').eq('is_enabled', true).order('name')`.
   - The user selects their delivery Area.
2. **Road Cascade**:
   - Once an area is selected, the app fetches roads mapped to that area:
     `Supabase.client.from('roads').select('id, name').eq('area_id', selectedAreaId).eq('is_enabled', true).order('name')`.
   - The road dropdown is enabled and populated.
3. **Sub-Road Cascade**:
   - Once a road is selected, the app fetches matching sub-roads:
     `Supabase.client.from('sub_roads').select('id, name').eq('road_id', selectedRoadId).eq('is_enabled', true).order('name')`.
   - The sub-road dropdown is populated.
4. **Registration Submission**:
   - The customer's profile is submitted with the IDs: `areaId`, `roadId`, and `subRoadId`.

---

## 3. SQLite Schema Updates (Self-Healing Migrations)

During app updates, the local SQLite database schema is migrated automatically.

- **Startup Migration**:
  `DatabaseHelper.onUpgrade` executes migrations sequentially.
- **Self-Healing Checks**:
  On startup, the helper runs a verification check:
  ```sql
  ALTER TABLE customers ADD COLUMN area_name TEXT;
  ALTER TABLE customers ADD COLUMN road_name TEXT;
  ALTER TABLE customers ADD COLUMN sub_road_name TEXT;
  ```
  If these columns are missing in older versions, they are added automatically, preventing SQL errors when accessing cached data.

---

## 4. Name Sanitization

To keep customer codes out of display fields (e.g. showing `OK1025` instead of `Priya` due to initial setup fallbacks), names are sanitized on load.

- **Sanitization Helper**:
  `string_utils.dart` exports `sanitizeCustomerName(String? name, {String? customerCode})`.
- **Validation Rules**:
  - If the name matches the customer code pattern (e.g. 2-4 letters followed by 2-6 digits like `OK1025`), it maps the display name to `"Customer"`.
  - It strips common suffix codes (like `R`, `L`, `M`, `LD`, `LR`) if they appear at the end of the name.
  - If the name field is empty, it defaults to `"Guest"`.
