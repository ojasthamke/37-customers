Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Feature File Index - ApliBhaji Customer App

This document categorizes all files in the customer application codebase by feature domain.

---

## 1. Authentication (Auth)

Handles customer login, session validation, password configuration, security checkouts, and guest creation.

- **`lib/features/auth/auth_provider.dart`**
  StateNotifier managing global `AuthState` (login, password settings, profile amendments, session validations).
- **`lib/features/auth/login_screen.dart`**
  Customer login view. Manages credentials entry, password setup, WhatsApp support links, and guest sessions.
- **`lib/features/auth/password_rules_helper.dart`**
   checklist showing password requirements (8+ characters, uppercase, lowercase, numbers, and special characters).
- **`lib/features/auth/register_screen.dart`**
  New account registration screen with cascading address selection (Area $\rightarrow$ Road $\rightarrow$ Sub-road).

---

## 2. Customer Profile

Handles customer details, address verification, and account settings.

- **`lib/features/profile/profile_screen.dart`**
  View displaying profile metadata, cascading routes, password updates, and account sign-out.

---

## 3. Guest Login

Provides checkout access for users without a registered member account.

- **`lib/features/auth/login_screen.dart`**
  Includes the `GuestLoginScreen` widget, which collects guest information (Name, Phone, Address) to create a guest session.
- **`lib/core/database/caching_repositories.dart`**
  `CachingCustomerRepository` caches guest session flags (`is_guest = 1`) in SQLite.
- **`lib/core/database/repositories.dart`**
  `SupabaseCustomerRepository` routes guest details to Supabase Auth with metadata flags set (`is_guest = true`).

---

## 4. Product Catalog

Renders product categories, listings, search results, and item details.

- **`lib/features/catalog/catalog_provider.dart`**
  Provides Riverpod streams mapping real-time catalog changes, search queries, and category filters.
- **`lib/features/catalog/categories_screen.dart`**
  Renders the list of available categories.
- **`lib/features/catalog/product_listing_screen.dart`**
  Grid displaying products with search filters and category tags.
- **`lib/features/catalog/product_details_screen.dart`**
  View showing product parameters, availability status, prescription warnings (Rx), and expiry details.

---

## 5. Quick Order (Order Now)

Dedicated discounted flash-sale catalog with quick delivery options.

- **`lib/features/catalog/order_now_screen.dart`**
  Quick delivery view showing active items, real-time stock limits, discount tags, and the quick cart checkout bar.
- **`lib/features/cart/cart_provider.dart`**
  Manages the separate `quickCartProvider` state and queries Supabase to check if the quick order window is open.

---

## 6. Cart Management

Handles product quantity selections, cart calculations, and delivery charges.

- **`lib/features/cart/cart_provider.dart`**
  Manages cart items in memory, serializes cart state to local storage, and rounds subtotals to the nearest multiple of 5.
- **`lib/features/cart/cart_screen.dart`**
  View displaying cart details, Normal vs Quick order switches, rounding descriptions, and checkout buttons.
- **`lib/core/widgets/quantity_selector.dart`**
  Pill-shaped increment selector and sheet modal supporting custom decimal input and validation against stock levels.

---

## 7. Checkout & Confirmation

Verifies cart pricing/stock, calculates delivery dates, and completes order placement.

- **`lib/features/checkout/checkout_screen.dart`**
  View validating checkout steps, confirming area schedules, and submitting orders.
- **`lib/features/checkout/order_confirmation_screen.dart`**
  Post-order view featuring receipt ticket animations and options to share receipt details to WhatsApp.

---

## 8. Dashboard & Schedules

The central hub of the application, managing user schedules and active orders.

- **`lib/features/dashboard/home_screen.dart`**
  Main tab bar containing order trackers, reorder shortcuts, and catalog sliders.
- **`lib/features/dashboard/schedule_banner.dart`**
  Calculates delivery window cutoffs, displays countdown clocks, and indicates if the store is closed.

---

## 9. Order Management

Displays order history, delivery routes, and tracking progress.

- **`lib/features/order/order_provider.dart`**
  Listens to order updates and synchronizes offline orders once network is available.
- **`lib/features/order/my_orders_screen.dart`**
  Lists previous orders filtered by status (All, Pre-orders, Active, Delivered).
- **`lib/features/order/order_details_screen.dart`**
  Detailed view of an individual order, featuring a status tracker (Placed $\rightarrow$ Preparing $\rightarrow$ Out for Delivery $\rightarrow$ Delivered).

---

## 10. Splash & Boot

Handles startup, auto-login, and initial routing.

- **`lib/features/splash/splash_screen.dart`**
  Initial launch view verifying session validity and routing users accordingly.
- **`lib/main.dart`**
  Main entry point. Restricts orientation, configures status bars, initializes databases, and boots the application.

---

## 11. Core Infrastructure

Shared helpers, theme configurations, widgets, and utility systems.

- **`lib/core/database/database_helper.dart`** (SQLite database controller)
- **`lib/core/database/repositories.dart`** (Abstract data contracts and SQLite/Supabase implementations)
- **`lib/core/database/caching_repositories.dart`** (Cache-Aside sync implementation)
- **`lib/core/database/providers.dart`** (Riverpod database providers)
- **`lib/core/services/auth_rate_limiter.dart`** (Persistent lockout protection)
- **`lib/core/services/notification_service.dart`** (FCM handler)
- **`lib/core/services/secure_local_storage.dart`** (Keychain access)
- **`lib/core/services/sync_service.dart`** (Background order synchronizer)
- **`lib/core/theme/app_theme.dart`** (Material 3 visual configurations)
- **`lib/core/utils/schedule_helper.dart`** (IST schedule calculations)
- **`lib/core/utils/security_helper.dart`** (SHA-256 password hashing)
- **`lib/core/utils/string_utils.dart`** (Customer name sanitizer)
- **`lib/core/widgets/`** (Shared UI widgets: gradients, skeletons, strikethrough text)
