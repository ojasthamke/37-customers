Status: Partially Verified
Last Updated: 2026-08-30
Source: Codebase & Test suite audit
Database verification status: Requires Supabase schema verification

# Row Level Security (RLS) Policy Map - ApliBhaji Customer App

This document maps out the expected security rules and access constraints for all remote Supabase tables, based on client queries and verification test suites.

> [!WARNING]
> Database verification status: Requires Supabase schema verification. The policies below represent client-side expectations and test suite assertions. They must be verified against actual PostgreSQL DDL policies.

---

## 1. Summary of RLS Rules by Table

### customers

Tracks customer profiles. Access is restricted by authenticated user IDs.

- **SELECT**: Accessible only by the owner (`auth.uid() = auth_user_id`) or store administrators.
- **INSERT**: Allowed during registration for authenticated signup sessions.
- **UPDATE**: Users can update their own profile details (`name`, `phone`, `address`, `area_id`, `road_id`, `sub_road_id`).
- **DELETE**: Restricted to administrators.
- **Flutter Feature**: Customer profile editing (`profile_screen.dart`), signup (`register_screen.dart`), and login sessions.

---

### products

The master product catalog.

- **SELECT**: Read access is open to all users (both registered and guests) to browse the catalog.
- **INSERT**: Restricted to administrators.
- **UPDATE**: Restricted to administrators.
- **DELETE**: Restricted to administrators.
- **Flutter Feature**: Product browsing and catalog viewing (`product_listing_screen.dart`, `order_now_screen.dart`, `product_details_screen.dart`).

---

### categories

Product category mappings.

- **SELECT**: Read access is open to all users.
- **INSERT**: Restricted to administrators.
- **UPDATE**: Restricted to administrators.
- **DELETE**: Restricted to administrators.
- **Flutter Feature**: Categories slider and catalog filtering (`categories_screen.dart`).

---

### orders

Tracks customer orders. Managed using secure RPC functions to enforce business rules.

- **SELECT**: Customers can read their own orders (`auth.uid() = customer_id`). Guests query orders by phone number. Administrators can read all orders.
- **INSERT**: Direct inserts are blocked for standard users by RLS policies. Order creation must be executed via the `place_order_secure` RPC to validate stock levels and calculate prices on the server.
- **UPDATE**: Standard users cannot modify order columns. Only administrators can update status fields (e.g. transitioning an order to `Confirmed`, `Preparing`, `Out for Delivery`, or `Cancelled`).
- **DELETE**: Blocked for standard users.
- **Flutter Feature**: Order history (`my_orders_screen.dart`), checkout (`checkout_screen.dart`), and order tracking.

---

### order_items

Contains individual items mapped to orders.

- **SELECT**: Customers can read items belonging to their orders.
- **INSERT**: Direct inserts are blocked. Row creation is handled through the `place_order_secure` RPC.
- **UPDATE**: Direct modifications are blocked.
- **DELETE**: Direct deletions are blocked.
- **Flutter Feature**: Checkout processing and order line details (`order_details_screen.dart`).

---

### settings

Stores store configuration settings.

- **SELECT**: Read access is open to all users.
- **INSERT**: Restricted to administrators.
- **UPDATE**: Restricted to administrators.
- **DELETE**: Restricted to administrators.
- **Flutter Feature**: App initialization (`main.dart`), checkouts, and delivery charge calculations.

---

## 2. RLS Access Level Grid

| Table Name | Guest User Access | Registered Customer Access | Administrator Access |
| :--- | :--- | :--- | :--- |
| **`categories`** | Read Only | Read Only | Full Access |
| **`products`** | Read Only | Read Only | Full Access |
| **`customers`** | Read/Update Self | Read/Update Self | Full Access |
| **`orders`** | Read Self (By Phone) | Read Self (By Auth ID) / RPC Write | Full Access |
| **`order_items`**| Read Self (By Phone) | Read Self (By Auth ID) / RPC Write | Full Access |
| **`settings`** | Read Only | Read Only | Full Access |

---

## 3. Policy Verification via Security Test Suite

The verification tests in `test/adversarial_verification_run.dart` and `test/order_integrity_verification_run.dart` confirm that client-side operations are constrained by these RLS rules:

- **Direct Insert Block**: Confirms that direct `INSERT` operations on the `orders` and `order_items` tables are blocked, forcing the use of the `place_order_secure` RPC.
- **Price Manipulation Protection**: Confirms that attempts by a customer to update columns in the `products` table (e.g., modifying prices) are blocked by RLS policies.
- **Order Modification Guard**: Confirms that updates to order columns (such as changing the order `status` or altering order items) are blocked, preventing customers from altering confirmed orders.
- **Deletions Restriction**: Confirms that direct deletions of order history records by customers are blocked.
