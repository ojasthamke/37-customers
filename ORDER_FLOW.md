Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Order Lifecycle & Placement Flow - ApliBhaji Customer App

This document details the step-by-step lifecycle of an order, from cart checkout validation to receipt generation, pre-orders, and background sync queues.

---

## 1. Checkout Validation Flow

```text
[Click Place Order] ──► [Pre-validate Stock/Price on Supabase]
                                       │
                     ┌─────────────────┴─────────────────┐
                     ▼ (Validation Fails)                ▼ (Validation Passes)
             [Cart Auto-Updated]                 [Retrieve Area Schedule]
                     │                                   │
             [Display Alert Screen]                      ▼
                                              [Calculate Delivery Date]
                                                         │
                                             ┌───────────┴───────────┐
                                             ▼ (openToday)           ▼ (closedToday)
                                      [Normal Order]          [Pre-Order]
                                             │                       │
                                             └───────────┬───────────┘
                                                         ▼
                                                [Submit Order RPC]
```

1. **Submit Order**: The user clicks the "Place Order" button.
2. **Stock & Pricing Validation**:
   - The app verifies catalog prices and stock availability on Supabase before submitting the order.
   - If a price has changed or stock is insufficient, the checkout process stops. The app updates the local cart values and alerts the user to review the changes.
3. **Schedule Calculation**:
   - The app retrieves the customer's delivery schedule (`delivery_schedule` and `cutoff_time`) from the active profile.
   - Calculates the order and delivery dates using `AreaScheduleHelper`.
   - **Normal Order**: If the store is open today and the cutoff time has not passed, the order type is set to `Normal`.
   - **Pre-Order**: If the store is closed today or the cutoff time has passed, the order type is set to `Pre-Order` and the next scheduled delivery date is used.

---

## 2. Order Submission (Supabase RPC)

To prevent data mismatch issues (like pricing mismatches or incomplete records), orders are submitted through a secure database RPC.

- **RPC Name**: `place_order_secure`
- **Arguments**:
  - `p_delivery_address` (TEXT)
  - `p_customer_phone` (TEXT)
  - `p_items` (JSONB list of `product_id` and `quantity`)
  - `p_idempotency_key` (TEXT - local UUID)
  - `p_delivery_date` (TEXT)
  - `p_offline_order_no` (TEXT - if synced from offline state)
  - `p_order_type` (TEXT - `Normal` or `Pre-Order`)
  - `p_order_taking_date` (TEXT)
- **Execution**: The database function processes the order inside a transaction: verifies stock limits, writes to the `orders` and `order_items` tables, updates inventory levels, and returns the generated receipt details.

---

## 3. Idempotency & Safety Measures

To prevent duplicate orders from network glitches or repeated taps, the app uses unique idempotency keys.

- **Key Generation**: When starting the checkout process, the app generates a UUID: `final String _idempotencyKey = const Uuid().v4();`.
- **Database Tracking**: This key is passed to the Supabase RPC and written to the `idempotency_key` column in the database.
- **Server Guard**: If the server receives a request with an existing `idempotency_key`, it returns the original order receipt instead of creating a duplicate order.
- **Cart Cleanup**: Once the order is submitted, the cart is cleared immediately in memory and in the local SQLite cache database.

---

## 4. Offline Queuing & Background Sync

If network connectivity is lost during checkout, the app queues the order locally.

```text
[Network Offline] ──► [Insert into SQLite: sync_status = 'pending']
                                        │
                               (Network Restored)
                                        ▼
                  [SyncService processes Offline Queue]
                                        │
                                        ▼
                  [place_order_secure using original UUID PK]
                                        │
                               ┌────────┴────────┐
                               ▼ (Success)       ▼ (Failure)
                   [Update status: 'synced']    [Mark status: 'failed']
```

1. **Local Queue Write**:
   - SQLite writes the order with `sync_status = 'pending'` and a temporary offline order number (e.g. `OLO-20260830-015`).
   - The local cart is cleared to allow continued use.
2. **Connectivity Listener**:
   - `SyncService` listens for connection restoration.
3. **Queue Sync**:
   - Iterates through pending offline orders.
   - Submits the order details to the Supabase RPC, using the local order UUID as the `p_idempotency_key`.
   - **If successful**: Updates the local SQLite record to `synced` and records the server-generated order ID and number.
   - **If failed**: Marks the local record as `failed` and saves the error description.

---

## 5. Live Tracking Status

Customers can track their orders in real time.

- **Status States**:
  - `Pending`: Order is placed and awaiting review.
  - `Confirmed`: Order is approved by the store admin.
  - `Preparing`: Items are being packed.
  - `Out for Delivery` (renders as "On The Way"): The delivery driver has departed.
  - `Delivered`: The order has been delivered.
  - `Cancelled`: The order was cancelled.
- **Update Streams**: The app listens for updates using `Supabase.client.from('orders').stream(primaryKey: ['id'])` to refresh status indicators instantly.
- **Reordering**: Users can copy items from a previous order back into their cart via `order_details_screen.dart`.

---

## 6. Receipt Generation & Share

- **Receipt Generator**:
  `order_details_screen.dart` compiles the order metadata, customer profile details, delivery route, and items list into a text receipt.
- **WhatsApp Share**:
  Uses `url_launcher` to share the receipt with the store support team:
  `whatsapp://send?phone=919021107009&text=urlencodedReceiptContent`.
- **System Sound Alerts**:
  When an order is successfully placed, the app plays a notification sound to confirm completion.

---

## 7. Strict Separation of Quick Order vs Weekly Orders

1. **Isolation of Calculation & Pricing**:
   - Quick Orders and Weekly Orders operate on completely decoupled calculations, inventories, and pricing pipelines.
   - **Quick Orders**: Item price = `coalesce(nullif(order_now_price, 0), price)`, stock = `order_now_stock`, availability = `order_now_is_available`, delivery charge = `order_now_delivery_charge` (₹10 default), delivered within 1-2 hours.
   - **Weekly Orders**: Item price = `price`, stock = `stock`, availability = `is_available`, delivery charge = `delivery_charge` (₹30 default), delivered on weekly schedule days.
   - In Order Summary and Order History, calculations strictly maintain this separation.
2. **Reordering Flow**:
   - Reordering a Quick Order populates `quickCartProvider` with `order_now_price` and sets `isViewingQuickOrderCartProvider = true`.
   - Reordering a Weekly Order populates `cartProvider` with standard `price` and sets `isViewingQuickOrderCartProvider = false`.

---

## 8. UX Compliance & Safety Specifications

1. **Login Terms & Conditions Requirement**:
   - Checkbox is **unticked by default** across all login/setup tabs (Sign In, Password Setup, Guest).
   - If the user attempts submission without checking:
     - The terms box executes a horizontal shake animation (`ShakeWidget`).
     - A glowing red border (`#EF4444`) with crimson alert background is displayed.
     - Heavy haptic feedback is triggered (`HapticFeedback.heavyImpact()`).
     - An error SnackBar notification prompts the user to accept the Terms & Conditions and Privacy Policy.
2. **Out-of-Stock Warning with Red Glass Glow Effect**:
   - Out-of-stock items across the entire app (`HomeScreen`, `OrderNowScreen`, `ProductListingScreen`, `ProductDetailsScreen`, `CartScreen`, `CheckoutScreen`) are highlighted instantly.
   - Container applies `GlassContainer(isStockOut: true)` rendering a solid red border (`#EF4444`, 1.8px) with a glowing crimson glass shadow.
   - In Cart: A top warning banner alerts the user, items display `⚠️ OUT OF STOCK` with direct delete action, and the Checkout button is disabled until out-of-stock items are removed.

