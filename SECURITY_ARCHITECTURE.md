Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Security Architecture - ApliBhaji Customer App

This document details the application's security architecture, encryption standards, session management, rate limiting, and database access controls.

---

## 1. Authentication Architecture

The application uses **Supabase Auth** as its identity provider. 
Customers are authenticated using email and password.
- **Registered Customers**: Authenticated via a generated virtual email format (`${customer_code.toLowerCase()}@aplibhaji.com`) and password.
- **Guest Users**: Registered automatically using their phone number as an email identifier (`${phone}@aplibhaji.com`) and a generated timestamp password.

---

## 2. Password Hashing & Encryption

Passwords are encrypted on the client side before they are sent over the network, ensuring plaintext credentials are never transmitted.

- **Hashing Algorithm**: SHA-256
- **App Salt**: Encoded using a constant app salt: `orderkart_customer_salt_2026_secure`
- **Implementation**:
  ```dart
  class SecurityHelper {
    static const String _salt = 'orderkart_customer_salt_2026_secure';
    
    static String hashPassword(String password) {
      if (password.isEmpty) return '';
      final salted = '$_salt:${password.trim()}';
      final bytes = utf8.encode(salted);
      final digest = sha256.convert(bytes);
      return digest.toString();
    }
  }
  ```
- **Responsibility**: Plaintext passwords are never cached in SQLite or stored in the remote database. Only the SHA-256 hashes are used for login operations.

---

## 3. Session & Secure Storage

Session tokens are stored securely to protect them from unauthorized access or extraction.

- **Storage Engine**: `FlutterSecureStorage`
- **Android Platform**: Configured to use EncryptedSharedPreferences:
  `AndroidOptions(encryptedSharedPreferences: true)`
- **iOS Platform**: Configured with keychain access:
  `KeychainAccessibility.first_unlock`
- **Integration**:
  Passed to Supabase configuration settings during startup to store active session tokens:
  ```dart
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(persistSessionKey: 'aplibhaji_customer_session'),
    ),
  );
  ```

---

## 4. Rate Limiting & Lockout Mechanisms

To prevent brute-force attacks on customer codes, the app uses a persistent rate-limiting system.

```text
[Invalid Login Attempt]
           │
           ▼
[Increment failed attempts in SQLite settings]
           │
           ├─► Attempts >= 10 ──► [Lockout for 1 Hour]
           │                            │
           │                  (If 1-Hour Lockout occurs 8 times)
           │                            ▼
           │                     [Lockout for 3 Days]
           │
           └─► Successful Login ──► [Reset counters to 0]
```

- **Lockout Levels**:
  - **1-Hour Lockout**: Triggered after 10 failed login attempts.
  - **3-Day Lockout**: Escalated if a 1-hour lockout occurs 8 times.
- **Persistence**: Lockout timestamps and attempt counters are saved to the SQLite `settings` table, ensuring the lockout remains active even if the app process is killed or the device is restarted.

---

## 5. Session Expiry & Logout Cleanup

- **Token Refresh**: The Supabase SDK handles session refresh tokens automatically on startup. If a token is expired and cannot be refreshed, the user is redirected to the `LoginScreen`.
- **Database Cleansing**: To protect user privacy, logging out triggers a database cleanup that deletes all local user data:
  ```sql
  DELETE FROM order_items;
  DELETE FROM orders;
  DELETE FROM customers;
  ```
- **Secure Storage Wipe**: Clears the stored session token from `FlutterSecureStorage`.

---

## 6. Supabase Row Level Security (RLS)

Access to database tables is restricted based on Row Level Security (RLS) policies configured in Supabase.

- **Catalog Access**: Public read access is enabled on the `categories` and `products` tables. Write access is restricted to administrator sessions.
- **Customer Access**: Users can only query their own row in the `customers` table matching their authenticated user ID (`auth.uid() = auth_user_id`).
- **Orders Access**: Customers can query or insert orders, but they must match their user ID (`auth.uid() = customer_id`). Customers cannot modify or delete order records directly once submitted.
