Status: Verified
Last Updated: 2026-08-30
Source: Codebase audit
Database verification status: Requires Supabase schema verification

# Test Coverage Map - ApliBhaji Customer App

This document maps the application's test suites to their corresponding features and lists any uncovered areas.

---

## 1. Authentication (Auth)

Tests covering login validation, options navigation, first-time password setup, and rate-limiting behaviors.

- **Relevant Test Files**:
  - **[`test/login_verification_test.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/test/login_verification_test.dart)**
    - *Scope*: Widget test verifying form elements, customer code input fields, and login screen transitions.
  - **[`test/adversarial_verification_run.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/test/adversarial_verification_run.dart)**
    - *Scope*: Integration audit confirming customer registration, authentication, and token checks.

---

## 2. Customer Profile

Tests covering profile caches, address cascades, and route details.

- **Relevant Test Files**:
  - **[`test/adversarial_verification_run.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/test/adversarial_verification_run.dart)**
    - *Scope*: Verifies customer profile checks and profile creation updates.
- **Missing Coverage**:
  - There are no tests covering cascading dropdown queries (Area $\rightarrow$ Road $\rightarrow$ Sub-road) or SQLite database migrations.

---

## 3. Catalog & Pricing

Tests covering catalog lists, StreamProviders, JSON description parsing, and discount rules.

- **Relevant Test Files**:
  - **[`test/adversarial_verification_run.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/test/adversarial_verification_run.dart)**
    - *Scope*: Verifies catalog loading and tests direct updates to the products table to check RLS compliance.
- **Missing Coverage**:
  - There are no tests verifying POS rounding logic to multiples of 5, delivery fee threshold calculations, or description JSON parsing.

---

## 4. Orders

Tests covering checkout processing, pre-orders, status transitions, offline queuing, background syncs, and idempotency.

- **Relevant Test Files**:
  - **[`test/adversarial_verification_run.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/test/adversarial_verification_run.dart)**
    - *Scope*: Tests order creation, negative quantities, zero quantities, and idempotency checks.
  - **[`test/order_integrity_verification_run.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/test/order_integrity_verification_run.dart)**
    - *Scope*: Verifies order modification, order deletions, and RLS policies on the `orders` and `order_items` tables.
  - **[`test/order_state_machine_run.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/test/order_state_machine_run.dart)**
    - *Scope*: Verifies state machine transitions (e.g. Confirmed $\rightarrow$ Cancelled) and atomic stock restoration.

---

## 5. Guest System

Tests covering guest logins, anonymous accounts, and guest orders.

- **Uncovered Areas**:
  - **No tests are currently present** for the guest registration flows or guest sessions. Guest operations are marked as an uncovered area.

---

## 6. General Layout & Navigation

Tests covering bottom tab bars, back-navigation tracking, and widget loading.

- **Relevant Test Files**:
  - **[`test/cart_navigation_origin_test.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/test/cart_navigation_origin_test.dart)**
    - *Scope*: Riverpod ProviderContainer unit test verifying cart entry and back-navigation tracking.
  - **[`test/widget_test.dart`](file:///C:/Users/ojast/Downloads/37/aplibhaji_customer/test/widget_test.dart)**
    - *Scope*: App startup smoke test.
