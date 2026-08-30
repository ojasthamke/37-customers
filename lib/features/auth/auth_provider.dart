import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../core/database/providers.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/auth_rate_limiter.dart';

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
    // Listen to authentication state changes to preserve session on refresh
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
              NotificationService.instance.registerFCMToken(customer['id']);
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
    if (AuthRateLimiter.instance.isLockedOut()) {
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.getLockoutErrorMessage());
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.login(phone, password);
      if (customer != null) {
        await AuthRateLimiter.instance.recordSuccessfulLogin();
        state = AuthState(customer: customer, isLoading: false);
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt();
        state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
        return false;
      }
    } catch (e) {
      final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt();
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
      return false;
    }
  }

  Future<bool> loginWithCode(String code) async {
    if (AuthRateLimiter.instance.isLockedOut()) {
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.getLockoutErrorMessage());
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.loginWithCode(code);
      if (customer != null) {
        await AuthRateLimiter.instance.recordSuccessfulLogin();
        state = AuthState(customer: customer, isLoading: false);
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt();
        state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
        return false;
      }
    } catch (e) {
      final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt();
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
      return false;
    }
  }

  /// Login with customer code + password
  Future<bool> loginWithCodeAndPassword(String code, String password) async {
    if (AuthRateLimiter.instance.isLockedOut()) {
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.getLockoutErrorMessage());
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.loginWithCodeAndPassword(code, password);
      if (customer != null) {
        await AuthRateLimiter.instance.recordSuccessfulLogin();
        state = AuthState(customer: customer, isLoading: false);
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt();
        state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
        return false;
      }
    } catch (e) {
      final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt();
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
      return false;
    }
  }

  /// Set password for a customer code (first-time setup).
  /// The onboarding PIN is required whenever the backend has a temp_setup_pin_hash configured for that customer.
  Future<bool> setupPassword(String code, String name, String password, {String? pin}) async {
    if (AuthRateLimiter.instance.isLockedOut()) {
      state = AuthState(isLoading: false, error: AuthRateLimiter.instance.getLockoutErrorMessage());
      return false;
    }

    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.setupPasswordForCode(code, name, password, pin: pin);
      if (customer != null) {
        await AuthRateLimiter.instance.recordSuccessfulLogin();
        state = AuthState(customer: customer, isLoading: false);
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        final errorMsg = await AuthRateLimiter.instance.recordFailedAttempt();
        state = AuthState(isLoading: false, error: AuthRateLimiter.instance.isLockedOut() ? AuthRateLimiter.instance.getLockoutErrorMessage() : errorMsg);
        return false;
      }
    } catch (e) {
      final cleanError = e.toString().replaceAll('Exception: ', '').trim();
      await AuthRateLimiter.instance.recordFailedAttempt();
      state = AuthState(
        isLoading: false,
        error: AuthRateLimiter.instance.isLockedOut()
            ? AuthRateLimiter.instance.getLockoutErrorMessage()
            : (cleanError.isNotEmpty ? cleanError : 'Failed to setup password. Please try again.'),
      );
      return false;
    }
  }

  /// Register as a guest user (name, phone, address only)
  Future<bool> registerGuest({
    required String name,
    required String phone,
    required String address,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final customer = await repo.registerGuest(name, phone, address);
      if (customer != null) {
        state = AuthState(customer: customer, isLoading: false);
        NotificationService.instance.registerFCMToken(customer['id']);
        return true;
      } else {
        state = AuthState(isLoading: false, error: 'Guest registration failed. Phone may already be in use.');
        return false;
      }
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
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

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(customerRepositoryProvider);
      final currentCust = state.customer;
      if (currentCust != null && currentCust['id'] != null) {
        await NotificationService.instance.clearFCMToken(currentCust['id']);
      }
      await repo.logout();
      state = AuthState(customer: null, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
