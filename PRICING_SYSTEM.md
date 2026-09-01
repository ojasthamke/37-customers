Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Pricing & Cart Round-Off System - ApliBhaji Customer App

This document details the pricing structures, description JSON parsing, delivery fees, and dynamic POS ceiling rounding.

---

## 1. Dual Pricing Modes (Catalog vs Quick Order) - Strict Separation

The application enforces a strict separation between Weekly Normal Delivery Orders and Quick Orders (Order Now). **Under no circumstances should the pricing, delivery fee, inventory, or cart calculations of Quick Orders merge with or be calculated according to Weekly Orders.**

| Metric | Normal Delivery (Weekly Catalog Mode) | Quick Order (Order Now Express Mode) |
| :--- | :--- | :--- |
| **Pricing Source** | `price` and `market_price` (from `products` table / JSON) | `order_now_price` (fallback to `price`) and `order_now_mrp` |
| **Stock Source** | `stock` column | `order_now_stock` column |
| **Availability Source** | `is_available` and `is_enabled` | `order_now_is_available` and `is_enabled` |
| **Delivery Fee Rule** | Calculated from settings `delivery_charge` (₹30) / `free_delivery_threshold` (₹300) | Calculated from settings `order_now_delivery_charge` (₹10) / threshold |
| **Cart Repository** | `cartProvider` | `quickCartProvider` (Isolated) |
| **Delivery Timeframe**| Weekly scheduled delivery day & cutoff | Instant (within 1-2 hours) |
| **Order History & Summary** | Calculated strictly from Weekly order items & historical prices | Calculated strictly from Quick Order items & `order_now_price` |
| **Database RPC Contract** | `place_order_secure` with `p_order_type = 'Normal'` | `place_order_secure` with `p_order_type = 'Quick Order'` |

---


## 2. Description JSON Metadata Parsing

To support flexible schemas without frequent migration updates, the application stores additional product metadata inside a single text `description` column.

- **Storage Structure**:
  Stores product details in a JSON-serialized string:
  ```json
  {
    "text": "Fresh organic locally sourced red tomatoes",
    "cost_price": 25.0,
    "market_price": 45.0,
    "mrp": 45.0,
    "stock": 150.0,
    "min_stock": 10.0,
    "barcode": "8901234567890",
    "weight_per_piece": 0.15,
    "sequence_no": 4,
    "expiry_date": "2026-09-05",
    "prescription_required": false
  }
  ```
- **Parsing Engine**:
  `catalog_provider.dart` maps this string to database columns:
  ```dart
  Map<String, dynamic> _parseProductDescription(Map<String, dynamic> p) {
    final Map<String, dynamic> mapped = Map.from(p);
    final desc = p['description'] as String? ?? '';
    if (desc.trim().startsWith('{') && desc.trim().endsWith('}')) {
      try {
        final Map<String, dynamic> decoded = json.decode(desc);
        mapped['description'] = decoded['text'] as String? ?? '';
        mapped['cost_price'] = (decoded['cost_price'] as num?)?.toDouble() ?? 0.0;
        mapped['market_price'] = ((decoded['market_price'] ?? decoded['mrp']) as num?)?.toDouble() ?? 0.0;
        mapped['stock'] = (decoded['stock'] as num?)?.toDouble() ?? 0.0;
        // ... mappings continue
      } catch (_) {}
    }
    return mapped;
  }
  ```

---

## 3. Dynamic Delivery Fees

Delivery fees are calculated dynamically based on store settings.

- **Settings Source**: The app loads configurations from the Supabase `settings` table.
  - `delivery_charge`: Default delivery charge (e.g. ₹30).
  - `free_delivery_threshold`: Threshold for free delivery (e.g. ₹300).
- **Calculation Rules**:
  - If the cart subtotal is less than the `free_delivery_threshold`, the delivery charge is added.
  - If the cart subtotal is greater than or equal to the threshold, the delivery fee is set to ₹0.

---

## 4. POS Ceiling Round-Off (Ceil to Multiples of 5)

To prevent fractional change calculations and ensure smooth cash collections, the app rounds cart totals up to the nearest multiple of 5.

```text
               [Calculate Cart Subtotal + Delivery Fee]
                                  │
                                  ▼
                   [Evaluate Rounded Grand Total]
                                  │
                  (Formula: Math.ceil(Total / 5) * 5)
                                  │
                 ┌────────────────┴────────────────┐
                 ▼ (Total: ₹273.40)                ▼ (Total: ₹151.00)
             [Rounded Total: ₹275]             [Rounded Total: ₹155]
                 │                                 │
             (Round-off: +₹1.60)               (Round-off: +₹4.00)
```

- **Formula**:
  $$\text{Rounded Grand Total} = \lceil\text{Grand Total} / 5\rceil \times 5$$
- **Implementation**:
  ```dart
  double get roundedGrandTotal {
    final double rawTotal = subtotal + deliveryCharge;
    if (rawTotal <= 0) return 0.0;
    return (rawTotal / 5).ceil() * 5.0;
  }
  ```
- **Round-Off Difference**:
  $$\text{Round-off Difference} = \text{Rounded Grand Total} - \text{Raw Total}$$
- **Checkout Display**:
  - The cart displays the round-off difference dynamically (e.g., "+₹1.50").
  - The checkout screens show the final rounded total, matching the billing amount on the invoice.
- **Toggle switch**:
  The system automatically disables rounding if the payment gateway options indicate online digital transactions instead of COD.
