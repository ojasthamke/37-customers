Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# AI Context - ApliBhaji Customer App

This document provides a quick reference guide for AI coding agents to navigate the codebase efficiently and maintain system constraints.

---

## 1. Project Identity

- **Framework**: Flutter (Targeting Android and iOS)
- **Backend**: Supabase (PostgreSQL Database, Realtime, Auth, RPC Functions)
- **State Management**: Riverpod (StateNotifierProvider, StreamProvider, FutureProvider)
- **Local Database**: SQLite (`sqflite` for mobile, `sqflite_common_ffi` for desktop)
- **Architecture**: Offline-first caching with background revalidation (Cache-Aside pattern)

---

## 2. Critical Rules

- **Never Use Customer Code as Customer Name**: Customer codes (e.g. `OK1025`) and names must remain separate. Names must be sanitized using `sanitizeCustomerName()` before display.
- **Strict Separation of Quick Orders vs Weekly Orders**: Quick Order pricing (`order_now_price`), stock (`order_now_stock`), delivery fee (`order_now_delivery_charge`), and cart (`quickCartProvider`) MUST NEVER merge or be calculated according to Weekly Orders (`price`, `stock`, `delivery_charge`, `cartProvider`). Both sections are strictly separate in Order Summary, Order History, Database RPC (`place_order_secure`), and Reorder flow.
- **Login Terms & Conditions Checkbox**: Checkboxes across login, setup, and guest tabs MUST start unticked (`false`). If the user clicks submit without checking, the terms section executes a horizontal shake animation (`ShakeWidget`), displays a red glowing border, triggers heavy haptic feedback, and displays an error notification SnackBar.
- **Out-of-Stock Red Glass Glow Warning**: Any out-of-stock item across the entire app (`GlassContainer(isStockOut: true)`) MUST be immediately identifiable with a vibrant red border (`#EF4444`, 1.8px) and a luminous crimson glass glow shadow. In the Cart, out-of-stock items show an alert badge with a direct remove button, a top warning banner, and disable checkout until removed.
- **Do Not Bypass Repository Architecture**: UI components must interact with providers and caching repositories, never directly with SQLite or Supabase database helpers.
- **Centralized Product Pricing**: Product prices must be calculated using catalog-provider mappings that decode JSON descriptions for catalog products, or read `order_now_price` for Quick Order items.
- **Separate Guest Data**: Guest details must be stored with `is_guest = 1` in SQLite and `is_guest = true` on Supabase to keep them separate from registered customer statistics.
- **No Plaintext Passwords**: Passwords must be hashed using SHA-256 with the app salt before transmission or validation. Never store plaintext credentials.
- **POS Ceil Rounding**: Invoice calculations for COD must be rounded up to the nearest multiple of 5 using `(rawTotal / 5).ceil() * 5.0`.


---

## 3. Feature Lookup Table

| Feature | Primary Files to Inspect |
| :--- | :--- |
| **Authentication / Login** | [`lib/features/auth/auth_provider.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/auth/auth_provider.dart), [`lib/features/auth/login_screen.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/auth/login_screen.dart) |
| **Customer Profile** | [`lib/features/profile/profile_screen.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/profile/profile_screen.dart), [`lib/core/database/caching_repositories.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/core/database/caching_repositories.dart) |
| **Product Catalog** | [`lib/features/catalog/catalog_provider.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/catalog/catalog_provider.dart), [`lib/features/catalog/product_listing_screen.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/catalog/product_listing_screen.dart) |
| **Order Now / Flash Sales**| [`lib/features/catalog/order_now_screen.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/catalog/order_now_screen.dart), [`lib/features/catalog/catalog_provider.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/catalog/catalog_provider.dart) |
| **Cart & Pricing** | [`lib/features/cart/cart_provider.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/cart/cart_provider.dart), [`lib/features/cart/cart_screen.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/cart/cart_screen.dart) |
| **Orders & Checkout** | [`lib/features/order/order_provider.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/order/order_provider.dart), [`lib/features/checkout/checkout_screen.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/checkout/checkout_screen.dart) |
| **Guest Login** | [`lib/features/auth/login_screen.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/auth/login_screen.dart) (GuestLoginScreen widget), [`lib/features/auth/auth_provider.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/features/auth/auth_provider.dart) |
| **Offline Sync Queue** | [`lib/core/services/sync_service.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/core/services/sync_service.dart), [`lib/core/database/caching_repositories.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/lib/core/database/caching_repositories.dart) |

---

## 4. Authoritative Data Sources

- **Customer Name**: Supabase user metadata or cached SQLite `customers` name.
- **Customer Code**: Cached SQLite `customers.customer_code` or `user_metadata.customer_code`.
- **Delivery Area**: Caching repository `area_name` mapped from the selected `area_id`.
- **Delivery Route**: Caching repository `road_name` and `sub_road_name`.
- **Product Price**: The `price` column for standard catalog items, or `order_now_price` for Quick Order items.
- **Order Status**: The `status` column in the Supabase `orders` table (streamed in real time).

---

## 5. Cache & Synchronization Rules

| Cache Type | Storage Location | Time-To-Live (TTL) | Realtime Channel | Force-Refresh Trigger |
| :--- | :--- | :--- | :--- | :--- |
| **Categories** | SQLite `categories` | 2 Hours | Yes (`categories` channel) | Pull-to-refresh on catalog views |
| **Products** | SQLite `products` | 30 Minutes | Yes (`products` channel) | Pull-to-refresh on catalog views |
| **Customer Profile**| SQLite `customers` | 5 Minutes | No | Logout/Login or missing route labels |
| **Orders List** | SQLite `orders` | 1 Minute | Yes (`orders` channel) | Pull-to-refresh on my orders screen |
| **Store Settings** | SQLite `settings` | 1 Hour | No | App startup check |

---

## 6. Before Editing Rule (Mandatory Workflow)

When modifying code or implementing features, follow this workflow:

1. **Read `AI_CONTEXT.md`** (this file) to check system constraints and guidelines.
2. **Read `FEATURE_FILE_INDEX.md`** to locate target files.
3. **Open only the relevant files** to conserve context window space.
4. **Read `DATA_FLOW_MAP.md`** if modifying data flows.
5. **Read `DATABASE_MAP.md`** if modifying database schemas or query logic.
6. **Perform global searches** only when file mappings are not identified in the documentation.
7. **Update the relevant documentation files** after completing architectural changes.
