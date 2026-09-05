import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../core/database/providers.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/auth_rate_limiter.dart';
import '../../core/services/login_tracker_service.dart';
import '../catalog/catalog_provider.dart';
import '../cart/cart_provider.dart';
import '../order/order_provider.dart';
import '../dashboard/home_screen.dart';


class AuthState {
  final Map<String, dynamic>? customer;
  final bool isLoading;
  final String? error;

  AuthState({this.customer, this.isLoading = false, this.error});

  AuthState copyWith({
    Map<String, dynamic>? customer,
    bool? isLoading,
    String? error,
    bool clearCustomer = false,
  }) {
    return AuthState(
      customer: clearCustomer ? null : (customer ?? this.customer),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(AuthState(isLoading: true)) {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession != null) {
        final repo = _ref.read(customerRepositoryProvider);
        final customer = await repo.getLoggedInCustomer(onRefresh: (freshCustomer) {
          state = AuthState(customer: freshCustomer, isLoading: false);
        }).timeout(const Duration(seconds: 3), onTimeout: () => null);

        if (customer != null) {
          state = AuthState(customer: customer, isLoading: false);
          try {
            LoginTrackerService.instance.recordLogin(
              customer: customer,
              loginMethod: 'Session Restore',
            );
          } catch (_) {}
          try {
            final custId = customer['id'].toString();
            final areaId = customer['area_id']?.toString();
            NotificationService.instance.startRealtimeNotificationSync(customerId: custId, areaId: areaId);
            NotificationService.instance.registerFCMToken(custId);
          } catch (_) {}
          _listenToAuthChanges();
          return;
        }
      }
    } catch (e) {
      debugPrint('Initial auth session check error: $e');
    }

    state = AuthState(customer: null, isLoading: false);
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        final event = data.event;
        
        if (session != null) {
          try {
            final repo = _ref.read(customerRepositoryProvider);
            final customer = await repo.getLoggedInCustomer(onRefresh: (freshCustomer) {
              state = AuthState(customer: freshCustomer, isLoading: false);
            });
            if (customer != null) {
              state = AuthState(customer: customer, isLoading: false);
              try {
                LoginTrackerService.instance.recordLogin(
                  customer: customer,
                  loginMethod: 'Auth State Change',
                );
              } catch (_) {}
              try {
                final custId = customer['id'].toString();
                final areaId = customer['area_id']?.toString();
                NotificationService.instance.startRealtimeNotificationSync(customerId: custId, areaId: areaId);
                NotificationService.instance.registerFCMToken(custId);
              } catch (_) {}
              return;
            }

          } catch (_) {
            // Silent fallback on background session updates
          }
        }
        
        if (event == AuthChangeEvent.initialSession || session == null) {
          state = AuthState(customer: null, isLoading: false);
        }
      });
    } catch (_) {
      // Safe fallback for widget tests where Supabase is not initialized
      state = AuthState(customer: null, isLoading: false);
    }
  }


  Future<void> loadCurrentCustomer() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.getLoggedInCustomer(onRefresh: (freshCustomer) {
        state = AuthState(customer: freshCustomer, isLoading: false);
      });
      state = AuthState(customer: customer, isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<bool> login(String phone, String password) async {
    final cleanPhone = phone.trim();
    await AuthRateLimiter.instance.checkServerLockout(cleanPhone);
    if (AuthRateLimiter.instance.isLockedOut()) {
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.getLockoutErrorMessage());
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.login(cleanPhone, password);
      if (customer != null) {
        await AuthRateLimiter.instance.recordSuccessfulLogin(identifier: cleanPhone);
        state = AuthState(customer: customer, isLoading: false);
        try {
          LoginTrackerService.instance.recordLogin(
            customer: customer,
            loginMethod: 'Phone + Password',
          );
        } catch (_) {}
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt(identifier: cleanPhone);
        state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
        return false;
      }
    } catch (e) {
      final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt(identifier: cleanPhone);
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
      return false;
    }
  }

  Future<bool> loginWithCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    await AuthRateLimiter.instance.checkServerLockout(cleanCode);
    if (AuthRateLimiter.instance.isLockedOut()) {
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.getLockoutErrorMessage());
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.loginWithCode(cleanCode);
      if (customer != null) {
        await AuthRateLimiter.instance.recordSuccessfulLogin(identifier: cleanCode);
        state = AuthState(customer: customer, isLoading: false);
        try {
          LoginTrackerService.instance.recordLogin(
            customer: customer,
            loginMethod: 'Customer Code',
          );
        } catch (_) {}
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt(identifier: cleanCode);
        state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
        return false;
      }
    } catch (e) {
      final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt(identifier: cleanCode);
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
      return false;
    }
  }

  /// Login with customer code + password
  Future<bool> loginWithCodeAndPassword(String code, String password) async {
    final cleanCode = code.trim().toUpperCase();
    await AuthRateLimiter.instance.checkServerLockout(cleanCode);
    if (AuthRateLimiter.instance.isLockedOut()) {
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.getLockoutErrorMessage());
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.loginWithCodeAndPassword(cleanCode, password);
      if (customer != null) {
        await AuthRateLimiter.instance.recordSuccessfulLogin(identifier: cleanCode);
        state = AuthState(customer: customer, isLoading: false);
        try {
          LoginTrackerService.instance.recordLogin(
            customer: customer,
            loginMethod: 'Code + Password',
          );
        } catch (_) {}
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt(identifier: cleanCode);
        state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
        return false;
      }
    } catch (e) {
      final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt(identifier: cleanCode);
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
      return false;
    }
  }

  /// Set password for a customer code (first-time setup).
  /// The onboarding PIN is required whenever the backend has a temp_setup_pin_hash configured for that customer.
  Future<bool> setupPassword(String code, String name, String password, {String? pin}) async {
    final cleanCode = code.trim().toUpperCase();
    await AuthRateLimiter.instance.checkServerLockout(cleanCode);
    if (AuthRateLimiter.instance.isLockedOut()) {
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.getLockoutErrorMessage());
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.setupPasswordForCode(cleanCode, name, password, pin: pin);
      if (customer != null) {
        await AuthRateLimiter.instance.recordSuccessfulLogin(identifier: cleanCode);
        state = AuthState(customer: customer, isLoading: false);
        try {
          LoginTrackerService.instance.recordLogin(
            customer: customer,
            loginMethod: 'Password Setup',
          );
        } catch (_) {}
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt(identifier: cleanCode);
        state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
        return false;
      }
    } catch (e) {
      final cleanError = e.toString().replaceAll('Exception: ', '').trim();
      final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt(identifier: cleanCode);
      state = AuthState(
        isLoading: false,
        error: AuthRateLimiter.instance.isLockedOut()
            ? AuthRateLimiter.instance.getLockoutErrorMessage()
            : (cleanError.isNotEmpty ? cleanError : errorMsg),
      );
      return false;
    }
  }

  /// Register as a guest user (name, phone, address, and optional area/road)
  Future<bool> registerGuest({
    required String name,
    required String phone,
    required String address,
    String? areaId,
    String? roadId,
    String? subRoadId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.registerGuest(
        name,
        phone,
        address,
        areaId: areaId,
        roadId: roadId,
        subRoadId: subRoadId,
      );
      if (customer != null) {
        state = AuthState(customer: customer, isLoading: false);
        try {
          LoginTrackerService.instance.recordLogin(
            customer: customer,
            loginMethod: 'Guest',
          );
        } catch (_) {}
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        state = AuthState(isLoading: false, error: 'Guest registration failed. Phone may already be in use.');
        return false;
      }
    } catch (e) {
      final cleanErr = e.toString().replaceAll('Exception: ', '').trim();
      state = AuthState(isLoading: false, error: cleanErr.isNotEmpty ? cleanErr : 'Guest registration failed.');
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    required String address,
    String? areaId,
    String? roadId,
    String? subRoadId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.register(name, phone, password, address, areaId: areaId, roadId: roadId, subRoadId: subRoadId);
      if (customer != null) {
        state = AuthState(customer: customer, isLoading: false);
        try {
          LoginTrackerService.instance.recordLogin(
            customer: customer,
            loginMethod: 'Registration',
          );
        } catch (_) {}
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        state = AuthState(isLoading: false, error: 'Registration failed. The mobile number may be already registered or another error occurred.');
        return false;
      }
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Check if customer profile has required fields complete (Name, Phone, Customer Code, and Password)
  bool isProfileComplete(Map<String, dynamic>? customer) {
    if (customer == null) return false;
    final name = (customer['name'] as String? ?? '').trim();
    final rawPhone = (customer['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '').trim();
    final customerCode = (customer['customer_code'] as String? ?? '').trim();
    final password = (customer['password'] as String? ?? '').trim();

    if (name.isEmpty || name == 'Valued Customer' || name == 'Guest Customer') return false;
    if (rawPhone.isEmpty || rawPhone.length != 10) return false;
    if (customerCode.isEmpty) return false;
    if (password.isEmpty) return false;

    return true;
  }

  /// Sign in with Firebase Verified Phone (SMS OTP)
  Future<Map<String, dynamic>?> loginWithPhoneOtp({
    required String phone,
    String? firebaseUid,
  }) async {
    final cleanPhone = phone.trim();
    await AuthRateLimiter.instance.checkServerLockout(cleanPhone);
    if (AuthRateLimiter.instance.isLockedOut()) {
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.getLockoutErrorMessage());
      return null;
    }

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.loginWithVerifiedPhone(cleanPhone, firebaseUid: firebaseUid);
      if (customer != null) {
        await AuthRateLimiter.instance.recordSuccessfulLogin(identifier: cleanPhone);
        state = AuthState(customer: customer, isLoading: false);
        try {
          LoginTrackerService.instance.recordLogin(
            customer: customer,
            loginMethod: 'Firebase Phone OTP',
          );
        } catch (_) {}
        if (customer['id'] != null) {
          NotificationService.instance.registerFCMToken(customer['id'].toString());
        }
        _ref.invalidate(categoriesProvider);
        _ref.invalidate(popularProductsProvider);
        _ref.invalidate(appSettingsProvider);
        _ref.invalidate(activeCartNotifierProvider);
        return customer;
      } else {
        final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt(identifier: cleanPhone);
        state = AuthState(
          isLoading: false,
          error: AuthRateLimiter.instance.isLockedOut()
              ? AuthRateLimiter.instance.getLockoutErrorMessage()
              : errorMsg,
        );
        return null;
      }
    } catch (e) {
      final cleanError = e.toString().replaceAll('Exception: ', '').trim();
      final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt(identifier: cleanPhone);
      state = AuthState(
        isLoading: false,
        error: AuthRateLimiter.instance.isLockedOut()
            ? AuthRateLimiter.instance.getLockoutErrorMessage()
            : (cleanError.isNotEmpty ? cleanError : errorMsg),
      );
      rethrow;
    }
  }

  /// Sign in with Google (triggers Google Sign-In SDK and links account)
  Future<Map<String, dynamic>?> loginWithGoogle() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.loginWithGoogle();
      if (customer != null) {
        state = AuthState(customer: customer, isLoading: false);
        try {
          LoginTrackerService.instance.recordLogin(
            customer: customer,
            loginMethod: 'Google Sign-In',
          );
        } catch (_) {}
        if (customer['id'] != null) {
          NotificationService.instance.registerFCMToken(customer['id'].toString());
        }
        return customer;
      } else {
        // User canceled sign-in
        state = state.copyWith(isLoading: false);
        return null;
      }
    } catch (e) {
      final cleanError = e.toString().replaceAll('Exception: ', '').trim();
      state = AuthState(
        isLoading: false,
        error: cleanError.isNotEmpty ? cleanError : 'Google Sign-In failed. Please try again.',
      );
      rethrow;
    }
  }

  /// Complete onboarding for Google Sign-In with Name, Phone, 7-character Customer Code and Password
  Future<bool> completeGoogleOnboarding({
    required String name,
    required String phone,
    required String customerCode,
    required String password,
  }) async {
    final currentCust = state.customer;
    if (currentCust == null || currentCust['id'] == null) {
      state = state.copyWith(isLoading: false, error: 'No active session found.');
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final updated = await repo.completeGoogleOnboarding(
        customerId: currentCust['id'].toString(),
        name: name.trim(),
        phone: phone.replaceAll(RegExp(r'\D'), '').trim(),
        customerCode: customerCode.trim().toUpperCase(),
        password: password,
      );

      if (updated != null) {
        state = AuthState(customer: updated, isLoading: false);
        _ref.invalidate(categoriesProvider);
        _ref.invalidate(popularProductsProvider);
        _ref.invalidate(appSettingsProvider);
        _ref.invalidate(activeCartNotifierProvider);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'Could not update profile.');
        return false;
      }
    } catch (e) {
      final cleanErr = e.toString().replaceAll('Exception: ', '').trim();
      state = state.copyWith(isLoading: false, error: cleanErr.isNotEmpty ? cleanErr : 'Failed to save account details.');
      return false;
    }
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String address,
    String? areaId,
    String? roadId,
    String? subRoadId,
  }) async {
    if (state.customer == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final id = state.customer!['id'];
      await repo.updateProfile(id, name, phone, address, areaId: areaId, roadId: roadId, subRoadId: subRoadId);
      
      // Fetch fresh customer details with resolved area and route names, updating local SQLite cache
      final freshCustomer = await repo.getLoggedInCustomer();
      if (freshCustomer != null) {
        state = AuthState(customer: freshCustomer, isLoading: false);
        
        // Invalidate cached providers so area changes reflect immediately
        _ref.invalidate(categoriesProvider);
        _ref.invalidate(popularProductsProvider);
        _ref.invalidate(appSettingsProvider);
        _ref.invalidate(activeCartNotifierProvider);
      } else {
        final updatedCustomer = {
          ...state.customer!,
          'name': name,
          'phone': phone,
          'address': address,
          'area_id': areaId,
          'road_id': roadId,
          'sub_road_id': subRoadId,
        };
        state = AuthState(customer: updatedCustomer, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> changePassword(String newPassword) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      await repo.changePassword(newPassword);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> resetPassword(String phone, String newPassword) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final success = await repo.resetPassword(phone, newPassword);
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>> checkCustomerAuthStatus(String identifier) async {
    try {
      final repo = _ref.read(customerRepositoryProvider);
      return await repo.checkCustomerAuthStatus(identifier);
    } catch (e) {
      return {'exists': false, 'has_password': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetPasswordWithVerification({
    required String identifier,
    required String phoneConfirm,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final res = await repo.resetPasswordWithVerification(identifier, phoneConfirm, newPassword);
      state = state.copyWith(isLoading: false);
      return res;
    } catch (e) {
      final cleanError = e.toString().replaceAll('Exception: ', '').trim();
      state = state.copyWith(isLoading: false, error: cleanError);
      return {'success': false, 'error': cleanError};
    }
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final currentCust = state.customer;
      if (currentCust != null && currentCust['id'] != null) {
        await NotificationService.instance.clearFCMToken(currentCust['id']);
      }
      await repo.deleteAccount();
    } catch (_) {
    } finally {
      NotificationService.instance.stopSync();
      _ref.read(cartProvider.notifier).clear();
      _ref.read(quickCartProvider.notifier).clear();
      _ref.invalidate(categoriesProvider);
      _ref.invalidate(popularProductsProvider);
      _ref.invalidate(appSettingsProvider);
      _ref.invalidate(activeCartNotifierProvider);
      _ref.invalidate(orderListProvider);
      _ref.invalidate(lastOrderProvider);
      _ref.read(activeTabProvider.notifier).state = 0;
      state = AuthState(customer: null, isLoading: false);
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final currentCust = state.customer;
      if (currentCust != null && currentCust['id'] != null) {
        await NotificationService.instance.clearFCMToken(currentCust['id']);
      }
      await repo.logout();
    } catch (e) {
      debugPrint('Logout error (clearing local state anyway): $e');
    } finally {
      NotificationService.instance.stopSync();
      _ref.read(cartProvider.notifier).clear();
      _ref.read(quickCartProvider.notifier).clear();
      _ref.invalidate(allProductsProvider);
      _ref.invalidate(orderNowProductsProvider);
      _ref.invalidate(categoriesProvider);
      _ref.invalidate(popularProductsProvider);
      _ref.invalidate(appSettingsProvider);
      _ref.invalidate(activeCartNotifierProvider);
      _ref.invalidate(orderListProvider);
      _ref.invalidate(lastOrderProvider);
      _ref.read(activeTabProvider.notifier).state = 0;
      state = AuthState(customer: null, isLoading: false);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
