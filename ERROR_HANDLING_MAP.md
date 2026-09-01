Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Error Handling Map - ApliBhaji Customer App

This document maps error categories in the application to their handling locations, user-facing behavior, and retry mechanisms.

---

## 1. Error Categories & Resolution Strategies

### Network Failures

Occur when network requests fail due to connectivity loss or timeout issues.

- **Source**: HTTP/WebSocket clients, Supabase database connections.
- **Handling Location**: `caching_repositories.dart` and `sync_service.dart`.
- **User-Facing Behavior**:
  - The app displays cached data immediately to remain functional.
  - A subtle offline banner is shown at the top of the screen to notify the user.
- **Retry Behavior**:
  - `SyncService` monitors network changes.
  - When connection is restored, the sync service automatically retries background catalog updates and syncs pending orders.

---

### Supabase API Failures

Occur when database requests fail due to permission issues or database timeouts.

- **Source**: Supabase database queries and secure RPC calls.
- **Handling Location**: State notifier handlers (`auth_provider.dart`, `order_provider.dart`).
- **User-Facing Behavior**: Displays an error banner using a `SnackBar` with the server error message (e.g. "Registration failed. Phone number may already be in use").
- **Retry Behavior**: The user can tap a "Retry" button on the screen to trigger the request again.

---

### Authentication Failures

Occur when login attempts fail due to incorrect passwords or invalid customer codes.

- **Source**: `Supabase.client.auth.signInWithPassword(...)`.
- **Handling Location**: `AuthNotifier.loginWithCodeAndPassword(...)` and `login_screen.dart`.
- **User-Facing Behavior**:
  - Shows an error message indicating invalid credentials.
  - Displays the number of remaining login attempts before the account is locked (e.g. "5 attempts remaining before lockout").
  - If rate limits are exceeded, a red lockout banner is displayed showing a countdown timer.
- **Retry Behavior**: The user can re-enter credentials once the lockout period expires.

---

### Session Expiry

Occurs when auth session tokens expire and cannot be refreshed.

- **Source**: Supabase auth token validation on startup.
- **Handling Location**: `splash_screen.dart` and `auth_provider.dart`.
- **User-Facing Behavior**: The app redirects the user to the `LoginScreen` and displays a session expired notification.
- **Retry Behavior**: The user must log in again with their code and password.

---

### SQLite Cache Failures

Occur when local SQLite queries fail due to database corruption or disk space limitations.

- **Source**: SQLite helper queries (`database_helper.dart`).
- **Handling Location**: Try-catch blocks inside database queries (`caching_repositories.dart`).
- **User-Facing Behavior**:
  - Local database exceptions are caught and logged silently to prevent app crashes.
  - The repository bypasses the local cache and queries Supabase directly.
- **Retry Behavior**: The app retries the query on the next page reload or navigation event.

---

### Order Submission Errors

Occur when checkouts fail due to out-of-stock items, pricing mismatches, or network drops.

- **Source**: The `place_order_secure` RPC call.
- **Handling Location**: `checkout_screen.dart` and `order_provider.dart`.
- **User-Facing Behavior**:
  - **Stock/Price Validation Failure**: Displays an alert prompting the user to review their cart, and updates the cart values automatically.
  - **Connection Failure**: Queues the order locally with a `pending` status, clears the cart, and redirects the user to the confirmation screen.
- **Retry Behavior**: Offline orders are retried automatically by the background sync service once the device regains connection.

---

### Product Loading Errors

Occur when catalog streams fail to fetch products or categories.

- **Source**: Catalog provider streams (`catalog_provider.dart`).
- **Handling Location**: Provider listeners (`product_listing_screen.dart`, `order_now_screen.dart`).
- **User-Facing Behavior**: Displays a centered error message (e.g., "Error loading categories: [error_text]").
- **Retry Behavior**: Users can pull to refresh the catalog, which clears the local cache key and refetches data from Supabase.
