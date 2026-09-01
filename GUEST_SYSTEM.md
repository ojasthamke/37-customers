Status: Verified
Last Updated: 2026-08-30
Source: Codebase inspection
Database verification status: Requires Supabase schema verification

# Guest Login & Customer System - ApliBhaji Customer App

This document details the architecture, data structures, and processes governing Guest Users in the ApliBhaji ecosystem.

---

## 1. Guest System Architecture Map

```text
Guest Data (Name, Phone, Address entered in UI)
        ↓
Guest Authentication (Anonymous signUp on Supabase with placeholder credentials)
        ↓
Guest Customer Record (Inserted into customers table with is_guest = true)
        ↓
Guest Orders (Placed with customer_phone and customer_id matching the guest user)
```

Guests are treated as authenticated identities within Supabase Auth, but they lack passwords and do not belong to the normal registered customer base.

---

## 2. Guest Login Flow

1. **User Input**: The user enters their Name, 10-digit Phone Number, and Delivery Address in the `GuestLoginScreen` widget.
2. **Registration Request**: The UI executes `ref.read(authProvider.notifier).registerGuest(...)`.
3. **Email Formatting**: Since Supabase requires an email or phone structure, the app creates a virtual email using the format: `${phone}@aplibhaji.com`.
4. **Credential Setup**: Because guests do not have password credentials, the app generates a one-time random password:
   `final guestPassword = 'guest_${DateTime.now().millisecondsSinceEpoch}';`
5. **Supabase SignUp**:
   Calls `Supabase.client.auth.signUp(email, guestPassword, data: { name, phone, address, is_guest: true })`.
6. **Customer Record Updates**:
   - The trigger on user creation generates a profile record in the remote `customers` table.
   - The app updates the `customers` table to set `is_guest = true` for the new record.
7. **Local Storage**:
   The caching layer writes the profile details to the local SQLite database, setting `is_guest = 1` and `is_logged_in = 1`.

---

## 3. Registered Customer vs. Guest User Comparison

| Metric | Registered Customer | Guest User |
| :--- | :--- | :--- |
| **Authentication Type** | Email & Password (SHA-256 Hashed) | Generated Email & Random Timestamp Password |
| **Login Input** | Customer Code (e.g. `OK1025`) & Password | Name, Phone, and Address (Requires registration on every session) |
| **Database Flag (`is_guest`)** | `false` (Supabase) / `0` (SQLite) | `true` (Supabase) / `1` (SQLite) |
| **Address Boundaries** | Cascading Area $\rightarrow$ Road $\rightarrow$ Sub-road IDs | Plaintext Address String (no specific Area/Road IDs) |
| **Order Schedule** | Area-specific delivery schedule and cutoff check | Default schedule (Typically Pre-Order or Next Day Delivery) |
| **Session Persistence** | Preserved on restart via `SecureLocalStorage` | Wiped on logout, requiring re-entry |

---

## 4. Key Files & Components Involved

- **`lib/features/auth/login_screen.dart`**: Contains the `GuestLoginScreen` UI widget and form validation rules.
- **`lib/features/auth/auth_provider.dart`**: Contains `AuthNotifier.registerGuest()`, which initiates the registration and local session setup.
- **`lib/core/database/repositories.dart`**: Contains `SupabaseCustomerRepository.registerGuest()`, which calls the Supabase signUp and update queries.
- **`lib/core/database/caching_repositories.dart`**: Contains `CachingCustomerRepository._cacheCustomer()`, which writes the profile details to SQLite with `is_guest = 1`.

---

## 5. Database & Query Operations

### Supabase Signup & Profile Creation
```dart
final AuthResponse res = await _client.auth.signUp(
  email: '$phone@aplibhaji.com',
  password: guestPassword,
  data: {
    'name': name,
    'phone': phone,
    'address': address,
    'is_guest': true,
  },
);
```

### Guest Flags Update
```dart
await _client
    .from('customers')
    .update({
      'name': name,
      'phone': phone,
      'address': address,
      'is_guest': true,
    })
    .eq('id', res.user!.id);
```

### SQLite Storage Insertion
```dart
final Map<String, dynamic> row = {
  'id': customer['id'],
  'name': customer['name'],
  'phone': customer['phone'],
  'address': customer['address'],
  'is_logged_in': 1,
  'is_guest': 1, // Sets the guest flag to 1
  // ... Other metadata columns are set to null
};
await db.insert('customers', row, conflictAlgorithm: ConflictAlgorithm.replace);
```

### Guest Orders Fetch
When retrieving order history, guest users are queried by their phone number instead of their account ID since their auth session is temporary:
```dart
var query = _client.from('orders').select('*, order_items(*)');
if (user != null && !isGuest) {
  query = query.eq('customer_id', user.id);
} else {
  query = query.eq('customer_phone', customerPhone);
}
```

---

## 6. Admin App Integration & Separation

In the Admin App (`aplibhaji_admin`), guest customer records and their orders are strictly separated from regular business operations to avoid skewing analytics and member-only lists.

### Database Segregation (SQLite)
All default queries for lists (customers, area/street details, outstanding balances) filter out guest accounts:
```sql
is_guest = 0 OR is_guest IS NULL
```
Conversely, guest customers are retrieved via dedicated methods:
- `CustomerDao.getGuestCustomers()`
- `CustomerDao.searchGuestCustomers(...)`
- `CustomerDao.getAllGuestCustomers()`

For orders and analytics calculations:
- `OrderDao.getAllOrders()` accepts a `showGuestsOnly` parameter (default `false`) which appends `c.is_guest = 1` when true, or `(c.is_guest = 0 OR c.is_guest IS NULL)` when false.
- `OrderDao.getAnalyticsSummary()` updates all sales totals, order counts, pending payments, cash/online payments, customer counts, and COGS calculations to exclude guest data using `customer_id IN (SELECT id FROM customers WHERE is_guest = 0 OR is_guest IS NULL)`.

### Dedicated Guest Hub
A dedicated **Guest Hub** screen is registered under route `AppRoutes.guestHub` (`/guest-hub`) and accessible via the main App Drawer. It is backed by:
- `guestCustomersProvider`: Feeds the list and search of guest customers.
- `guestOrdersProvider`: Feeds the guest order history (passing `showGuestsOnly: true`).
- The Guest Hub UI partitions information into three tabs:
  1. **Guest Customers**: Searchable list of all active guest accounts.
  2. **Guest Orders**: Real-time listing of orders placed by guests with status tags.
  3. **Guest Stats**: Calculated metrics of guest engagement (total guest logins, guest revenue, total orders, average ticket value, status breakdown).
