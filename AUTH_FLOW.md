Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Authentication Flow - ApliBhaji Customer App

This document details the authentication flows, brute-force protection mechanisms, session management, and guest registration pathways.

---

## 1. Authentication Paths

```text
                        ┌────────────────────────┐
                        │     Login Screen       │
                        └───────────┬────────────┘
                                    │
            ┌───────────────────────┼───────────────────────┐
            ▼                       ▼                       ▼
    [Customer Code]          [Password Setup]         [Guest Register]
           │                        │                       │
           ▼                        ▼                       ▼
 okXXXX@aplibhaji.com       setup_customer_password   signUp(is_guest: true)
           │                        │                       │
           ▼                        ▼                       ▼
signInWithPassword(SHA-256)  signInWithPassword      Upsert SQLite (is_guest=1)
```

The application provides three distinct entry points for users:
1. **Code & Password Login**: For registered customers using their customer code (e.g., `OK1025`) and password.
2. **First-Time Password Setup**: Allows pre-registered store members to set up their password.
3. **Guest Checkout**: For unregistered customers who want to place a quick order.

---

## 2. Code & Password Login Flow

1. **User Action**: The customer enters their Customer Code and Password on the `LoginScreen`.
2. **Brute-Force Check**: The UI queries `AuthRateLimiter.isLockedOut()`. If active, login is blocked and a lockout warning is shown.
3. **Action Trigger**: The UI calls `authProvider.loginWithCodeAndPassword(code, password)`.
4. **Backend Mapping**:
   - The customer code is normalized: `trimmedCode = code.trim().toUpperCase()`.
   - The email is formatted as: `email = ${trimmedCode.toLowerCase()}@aplibhaji.com`.
   - The password is hashed using SHA-256 with a secure salt: `hashedPassword = SecurityHelper.hashPassword(password)`.
5. **Authentication Request**: Calls `Supabase.client.auth.signInWithPassword(email: email, password: hashedPassword)`.
6. **Profile Enrichment**:
   - Fetches the customer's profile record from Supabase, joining the corresponding `areas`, `roads`, and `sub_roads` tables.
7. **Cache Hydration**:
   - The profile is stored in the local SQLite `customers` table with `is_logged_in = 1`.
   - The `AuthRateLimiter` resets failed login attempt counters.
8. **Navigation**: Riverpod updates the application state, and the user is navigated to the `HomeScreen`.

---

## 3. First-Time Password Setup Flow

Pre-registered customers must set up their password before logging in for the first time.

1. **User Action**: The user enters their Customer Code on the Setup Password tab.
2. **Account Check**:
   - Calls `checkCustomerAuthStatus(code)`, which invokes the Supabase RPC `check_customer_auth_status(p_identifier)`.
   - Returns details on whether the account exists and if a password is already configured.
   - If a password exists, the flow redirects the user to the login screen.
3. **Password Configuration**:
   - If no password exists, the user enters a new password.
   - The app calls the Supabase RPC `setup_customer_password(p_code, p_name, p_password)`. This function validates the customer record, creates an auth identity in Supabase, and flags the profile as configured.
4. **Login**:
   - Signs the user in automatically with `signInWithPassword` using the new password.
   - Caches the customer's profile details locally in SQLite.

---

## 4. Guest Registration Flow

Guest registration allows customers to order without setting up an account.

1. **User Action**: The user enters their Name, Phone Number, and Delivery Address.
2. **Registration Trigger**: Calls `authProvider.registerGuest(name, phone, address)`.
3. **Identity Creation**:
   - Formulates a guest email: `${phone}@aplibhaji.com`.
   - Generates a random secure password string: `guest_${DateTime.now().millisecondsSinceEpoch}`.
   - Calls `Supabase.client.auth.signUp(email, password, data: { name, phone, address, is_guest: true })`.
4. **Database Record**:
   - Inserts the guest user profile into the remote `customers` table with `is_guest = true`.
5. **Caching**:
   - Caches the profile in the local SQLite database, setting the guest flag `is_guest = 1`.
6. **Login**: Logs the guest user in and redirects them to the `HomeScreen`.

---

## 5. Persistent Brute-Force Rate Limiting

The `AuthRateLimiter` tracks and limits failed login attempts to protect against brute-force attacks.

```text
[Failed Attempt]
       │
       ▼
[Failed Count + 1] ──► [Count >= 10?] ──► Yes ──► [Lockout for 1 Hour]
                                                         │
                                             (Happens 8 Times?)
                                                         │
                                                         ▼
                                                    [Yes: Lockout for 3 Days]
```

- **Database Storage**: Limiter statistics are stored in the local SQLite `settings` table, ensuring they persist across app restarts.
- **Failures Tracker**: Tracks failed login attempts. On the 10th failure, it locks the account for 1 hour.
- **Escalation**: If a 1-hour lockout occurs 8 times, the lock period escalates to 3 days.
- **Checking Lockouts**: The app checks the lockout timestamp on launch. If active, it blocks authentication requests and calculates the remaining lockout duration.
