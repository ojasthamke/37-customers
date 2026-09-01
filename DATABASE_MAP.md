Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Database Schema & API Map - ApliBhaji Customer App

This document outlines the SQLite local database schema, table definitions, constraints, relationships, and remote Supabase tables and RPC functions.

---

## 1. Local SQLite Schema Map

The local database file is named `aplibhaji_customers.db` on mobile devices and `aplibhaji_shared.db` on desktop environments. It runs on schema version `9`.

### SQLite Schema Diagram

```text
  +-------------------------+          +-------------------------+
  |       categories        |          |        settings         |
  +-------------------------+          +-------------------------+
  | id TEXT (PK)            |          | key TEXT (PK)           |
  | name TEXT (UNIQUE)      |          | value TEXT              |
  | is_enabled INTEGER      |          +-------------------------+
  | created_at TEXT         |
  +------------+------------+          +-------------------------+
               | 1                     |     cache_metadata      |
               |                       +-------------------------+
               | N                     | key TEXT (PK)           |
  +------------v------------+          | last_synced_at TEXT     |
  |        products         |          +-------------------------+
  +-------------------------+
  | id TEXT (PK)            |          +-------------------------+
  | name TEXT               |          |        customers        |
  | category_id TEXT (FK)   |          +-------------------------+
  | image_path TEXT         |          | id TEXT (PK)            |
  | description TEXT        |          | name TEXT               |
  | price REAL              |          | phone TEXT (UNIQUE)     |
  | unit TEXT               |          | email TEXT              |
  | is_available INTEGER    |          | address TEXT            |
  | is_enabled INTEGER      |          | is_logged_in INTEGER    |
  | order_now_stock REAL    |          | customer_code TEXT      |
  | order_now_price REAL    |          | is_guest INTEGER        |
  | order_now_mrp REAL      |          | area_id TEXT            |
  | order_now_cost REAL     |          | road_id TEXT            |
  | order_now_is_avail INT  |          | sub_road_id TEXT        |
  | created_at TEXT         |          | area_name TEXT          |
  +------------+------------+          | road_name TEXT          |
               | 1                     | sub_road_name TEXT      |
               |                       | delivery_schedule TEXT  |
               | N                     | cutoff_time TEXT        |
  +------------v------------+          | created_at TEXT         |
  |       order_items       |          +------------+------------+
  +-------------------------+                       | 1
  | id TEXT (PK)            |                       |
  | order_id TEXT (FK)      |                       | N
  | product_id TEXT (FK)    |          +------------v------------+
  | product_name TEXT       |          |         orders          |
  | quantity REAL           |          +-------------------------+
  | price REAL              |          | id TEXT (PK)            |
  | unit TEXT               |          | order_number TEXT       |
  | created_at TEXT         |          | customer_id TEXT (FK)   |
  +-------------------------+          | customer_phone TEXT     |
               ^                       | customer_name TEXT      |
               | N                     | delivery_address TEXT   |
               |                       | order_date TEXT         |
               | 1                     | status TEXT             |
  +------------+------------+          | total_amount REAL       |
  |         orders          |          | delivery_date TEXT      |
  +-------------------------+          | area_id TEXT            |
  | id TEXT (PK)            |          | area_name TEXT          |
  | order_number TEXT       |          | road_id TEXT            |
  | customer_id TEXT (FK)   |          | road_name TEXT          |
  | ... [metadata]          |          | sub_road_id TEXT        |
  | sync_status TEXT        |          | sub_road_name TEXT      |
  | created_at TEXT         |          | offline_order_no TEXT   |
  +-------------------------+          | order_type TEXT         |
                                       | order_taking_date TEXT  |
                                       | sync_status TEXT        |
                                       | created_at TEXT         |
                                       +-------------------------+
```

---

## 2. Table Schemas & Configurations

### categories

Tracks product categories locally for offline catalog rendering.

```sql
CREATE TABLE categories (
    id TEXT PRIMARY KEY,
    name TEXT UNIQUE,
    is_enabled INTEGER DEFAULT 1,
    created_at TEXT
);
```

### products

Stores the main product details. Extends standard columns with specific attributes for flash-sales ("Order Now") and metadata.

```sql
CREATE TABLE products (
    id TEXT PRIMARY KEY,
    name TEXT,
    category_id TEXT,
    image_path TEXT,
    description TEXT, -- JSON-string or Plaintext
    price REAL,
    unit TEXT,
    is_available INTEGER DEFAULT 1,
    is_enabled INTEGER DEFAULT 1,
    order_now_stock REAL DEFAULT 0.0,
    order_now_price REAL DEFAULT 0.0,
    order_now_mrp REAL DEFAULT 0.0,
    order_now_cost_price REAL DEFAULT 0.0,
    order_now_is_available INTEGER DEFAULT 1,
    created_at TEXT,
    FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
);
```

### customers

Caches the active authenticated customer profile, permissions, and delivery schedule metadata.

```sql
CREATE TABLE customers (
    id TEXT PRIMARY KEY,
    name TEXT,
    phone TEXT UNIQUE,
    email TEXT,
    address TEXT,
    is_logged_in INTEGER DEFAULT 0,
    customer_code TEXT,
    is_guest INTEGER DEFAULT 0,
    area_id TEXT,
    road_id TEXT,
    sub_road_id TEXT,
    area_name TEXT,
    road_name TEXT,
    sub_road_name TEXT,
    delivery_schedule TEXT, -- Stringified JSON array (e.g. '["Monday", "Wednesday"]')
    cutoff_time TEXT DEFAULT '23:59',
    created_at TEXT
);
```

### orders

Maintains the local order queue, tracking whether entries have successfully synced with Supabase.

```sql
CREATE TABLE orders (
    id TEXT PRIMARY KEY,
    order_number TEXT UNIQUE,
    customer_id TEXT,
    customer_phone TEXT,
    customer_name TEXT,
    delivery_address TEXT,
    order_date TEXT,
    status TEXT DEFAULT 'pending',
    total_amount REAL,
    delivery_date TEXT,
    area_id TEXT,
    area_name TEXT,
    road_id TEXT,
    road_name TEXT,
    sub_road_id TEXT,
    sub_road_name TEXT,
    offline_order_no TEXT,
    order_type TEXT DEFAULT 'Normal',
    order_taking_date TEXT,
    sync_status TEXT DEFAULT 'synced', -- 'synced' | 'pending' | 'failed'
    created_at TEXT,
    FOREIGN KEY(customer_id) REFERENCES customers(id)
);
```

### order_items

Contains the itemized product list for each order.

```sql
CREATE TABLE order_items (
    id TEXT PRIMARY KEY,
    order_id TEXT,
    product_id TEXT,
    product_name TEXT,
    quantity REAL,
    price REAL,
    unit TEXT,
    created_at TEXT,
    FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
);
```

### settings

Stores key-value pairs for system settings, including cached cart serialized JSON and rate limiter status flags.

```sql
CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT
);
```

### cache_metadata

Manages API cache synchronization intervals.

```sql
CREATE TABLE cache_metadata (
    key TEXT PRIMARY KEY,
    last_synced_at TEXT -- ISO 8601 Timestamp
);
```

---

## 3. Remote Supabase Database (PostgreSQL)

### Remote Tables
- **`customers`**: Holds core profile records, customer codes, verification states, and foreign keys mapping to areas, roads, and sub-roads.
- **`categories`**: Stores product categories.
- **`products`**: Contains product listings, stock metrics, units, and availability flags.
- **`orders`**: Stores final customer orders.
- **`order_items`**: Stores item lines mapped to each order.
- **`settings`**: Holds global configuration metrics (e.g. delivery fee, order now status).
- **`areas`**, **`roads`**, **`sub_roads`**: Address hierarchy configuration tables.

### Supabase Remote Procedure Calls (RPC)

1. **`setup_customer_password`**
   - **Parameters**: `p_code` (TEXT), `p_name` (TEXT), `p_password` (TEXT)
   - **Action**: Initializes password details for a customer code.
2. **`check_customer_auth_status`** (aliased as `check_customer_authStatus` inside database wrappers)
   - **Parameters**: `p_identifier` (TEXT - Customer Code or Phone)
   - **Action**: Returns check metadata: `{ exists: true, has_password: true, name: '...', phone: '...' }`.
3. **`reset_customer_password`**
   - **Parameters**: `p_identifier` (TEXT), `p_phone_confirm` (TEXT), `p_new_password` (TEXT)
   - **Action**: Validates phone confirmation matches account and updates password.
4. **`place_order_secure`**
   - **Parameters**:
     - `p_delivery_address` (TEXT)
     - `p_customer_phone` (TEXT)
     - `p_items` (JSONB - `[{product_id: '...', quantity: 2.0}]`)
     - `p_idempotency_key` (TEXT - UUID)
     - `p_delivery_date` (TEXT)
     - `p_offline_order_no` (TEXT)
     - `p_order_type` (TEXT)
     - `p_order_taking_date` (TEXT)
   - **Action**: Validates quantities, updates stock levels, inserts order rows, and returns the generated receipt details.
