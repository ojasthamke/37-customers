Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Architectural Map - ApliBhaji Customer App

This document outlines the architecture, data management strategies, state patterns, and security mechanisms of the customer application.

---

## 1. Architectural Style

The application follows a **feature-first, layered architecture** combined with a **cache-aside (offline-first) design** to handle offline operations and network latency.

```text
       +-------------------------------------------------+
       |                    UI Layer                     |
       |  (Screens, Views, Components, Theme Customizer) |
       +-----------------------+-------------------------+
                               |
                        Watches / Reads
                               |
                               v
       +-------------------------------------------------+
       |             State Management Layer              |
       |  (Riverpod Notifiers, Streams, State Providers) |
       +-----------------------+-------------------------+
                               |
                         Delegates to
                               |
                               v
       +-------------------------------------------------+
       |                Repository Layer                 |
       |  (Caching Repositories, Abstract Contracts)     |
       +-------------------+-----------------------------+
                           |
            ┌──────────────┴──────────────┐
            ▼                             ▼
+───────────────────────+     +───────────────────────+
|      Local Cache      |     |      Remote API       |
| (SQLite Database FFI) |     |  (Supabase Backend)   |
+───────────────────────+     +───────────────────────+
```

---

## 2. Key Architectural Patterns

### Cache-Aside (Offline-First) Caching
- Data queries are first evaluated against the local SQLite database.
- If cached data is present, it is returned immediately to keep the UI responsive.
- If the cache's Time-To-Live (TTL) has expired, background revalidation is triggered to fetch fresh data from Supabase.
- Once fresh data is retrieved, the local database is updated, and the UI is updated with the new details.

### Dependency Injection (DI)
- Injects concrete caching repositories via Riverpod, decoupling feature code from underlying data storage mechanisms.

### Persistent Brute-Force Rate Limiting
- Login attempt counters are saved to SQLite.
- Lockout periods (1-hour on 10 failed logins, escalating to 3-day lockout after 8 hourly lockouts) are checked before processing login attempts. This defense survives application restarts and cache clear commands.

### Background Order Synchronization (Sync Queue)
- Transactions executed while offline are queued in SQLite with a `pending` status flag.
- When network connectivity is restored, a background sync service processes the queue, submitting each order via an idempotent Supabase RPC.

---

## 3. Data Storage & Management

### SQLite Local Cache DB
- Database Path:
  - **iOS/Android**: `getApplicationDocumentsDirectory() / aplibhaji_customers.db`
  - **Windows/macOS/Linux**: `CWD / aplibhaji_shared.db`
- Migrations: Uses raw SQL statements inside `_onUpgrade` loops to apply schema updates incrementally.

### Supabase Remote DB
- Connects using the Postgres wire protocol.
- PostgreSQL functions are exposed as RPC endpoints, allowing complex transactional database operations (like stock deductions and profile updates) to run securely on the server.

---

## 4. State Management (Riverpod)

The application uses Riverpod to manage state across three main types of providers:

1. **StateNotifiers**: Manage states that change due to user actions (e.g. `AuthState`, `CartState`).
2. **StreamProviders**: Provide real-time data streams from Supabase table channels (e.g. `allProductsProvider`, `orderNowProductsProvider`).
3. **FutureProviders**: Fetch one-time data values asynchronously (e.g. `lastOrderProvider`).

---

## 5. Security & Session Integrity

- **Encrypted Local Storage**: Session credentials and tokens are saved using `FlutterSecureStorage`, which uses Keychain on iOS and EncryptedSharedPreferences on Android.
- **Credential Hashing**: User passwords are encrypted using SHA-256 with a salt before transmission, preventing plaintext passwords from being exposed or saved.
- **Brute-Force Protection**: Rate limiting is tracked locally in SQLite, preventing brute-force login attempts even if the app process is restarted.
- **Privacy Controls**: When a user logs out, the local SQLite database is cleared of all customer profiles, order history, and queued cart records to protect user data.
