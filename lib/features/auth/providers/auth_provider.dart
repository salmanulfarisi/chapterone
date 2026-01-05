import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../services/api/api_service.dart';
import '../../../services/storage/storage_service.dart';
import '../../../services/notifications/notification_service.dart';
import '../../../services/logging/crashlytics_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/logger.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?.isAdmin ?? false;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final Ref? _ref;

  AuthNotifier(this._apiService, this._ref) : super(AuthState()) {
    _loadUserFromStorage();
  }

  Future<void> _loadUserFromStorage() async {
    try {
      final userData = StorageService.getUserData();
      final token = StorageService.getAuthToken();

      if (userData != null && token != null) {
        _apiService.setAuthToken(token);
        try {
          // Ensure all nested maps are properly converted
          final cleanUserData = _cleanUserData(userData);
          final user = UserModel.fromJson(cleanUserData);
          state = state.copyWith(user: user);
          
          // Set user ID in Crashlytics for crash tracking
          await CrashlyticsService.instance.setUserId(user.id);
          
          // Initialize notifications after loading user from storage
          if (_ref != null) {
            _initializeNotificationsAsync();
          }
        } catch (e) {
          Logger.error(
            'Failed to parse user data from storage',
            e,
            null,
            'AuthNotifier',
          );
          // Clear invalid data
          await StorageService.clearUserData();
          await StorageService.clearAuth();
        }
      }
    } catch (e) {
      Logger.error('Failed to load user from storage', e, null, 'AuthNotifier');
    }
  }

  // Helper method to clean user data and ensure proper types
  Map<String, dynamic> _cleanUserData(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Map) {
        // Recursively clean nested maps
        cleaned[key] = Map<String, dynamic>.from(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else if (value is List) {
        cleaned[key] = value;
      } else {
        cleaned[key] = value;
      }
    }

    return cleaned;
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      final token = response.data['token'];
      final refreshToken = response.data['refreshToken'];
      final userData = response.data['user'];

      if (token != null) {
        await StorageService.saveAuthToken(token);
        if (refreshToken != null) {
          await StorageService.saveRefreshToken(refreshToken);
        }
        _apiService.setAuthToken(token);

        final user = UserModel.fromJson(userData);
        await StorageService.saveUserData(user.toJson());

        state = state.copyWith(user: user, isLoading: false);

        // Set user ID in Crashlytics for crash tracking
        await CrashlyticsService.instance.setUserId(user.id);

        // Initialize notifications after successful login (non-blocking)
        if (_ref != null) {
          _initializeNotificationsAsync();
        }

        return true;
      }

      state = state.copyWith(isLoading: false, error: 'Login failed');
      return false;
    } catch (e) {
      Logger.error('Login error', e, null, 'AuthNotifier');
      String errorMessage = 'Login failed. Please try again.';

      if (e is ApiException) {
        errorMessage = e.message;
      } else if (e.toString().contains('401') ||
          e.toString().contains('Invalid')) {
        errorMessage =
            'Invalid credentials. Please check your email and password.';
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Connection error. Please check your internet connection.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<bool> register(
    String email,
    String password, {
    String? username,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          if (username != null) 'username': username,
        },
      );

      final token = response.data['token'];
      final refreshToken = response.data['refreshToken'];
      final userData = response.data['user'];

      if (token != null) {
        await StorageService.saveAuthToken(token);
        if (refreshToken != null) {
          await StorageService.saveRefreshToken(refreshToken);
        }
        _apiService.setAuthToken(token);

        final user = UserModel.fromJson(userData);
        await StorageService.saveUserData(user.toJson());

        state = state.copyWith(user: user, isLoading: false);

        // Set user ID in Crashlytics for crash tracking
        await CrashlyticsService.instance.setUserId(user.id);

        // Initialize notifications after successful registration (non-blocking)
        if (_ref != null) {
          _initializeNotificationsAsync();
        }

        return true;
      }

      state = state.copyWith(isLoading: false, error: 'Registration failed');
      return false;
    } catch (e) {
      Logger.error('Registration error', e, null, 'AuthNotifier');
      String errorMessage = 'Registration failed. Please try again.';

      if (e is ApiException) {
        errorMessage = e.message;
      } else if (e.toString().contains('already exists') ||
          e.toString().contains('400')) {
        errorMessage =
            'Email already registered. Please use a different email.';
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Connection error. Please check your internet connection.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<void> logout() async {
    // Try to invalidate token on server first (while we still have the token)
    // Then clear local data
    try {
      await _apiService.post(ApiConstants.logout);
    } catch (e) {
      // Silently ignore - logout is primarily client-side anyway
      // Token may be expired or invalid, which is fine
      Logger.debug('Logout API call failed (expected if token expired): $e', 'AuthNotifier');
    }

    // Clear local data after attempting server logout
    await StorageService.clearAuth();
    await StorageService.clearUserData();
    _apiService.setAuthToken(null);
    
    // Clear user ID from Crashlytics
    await CrashlyticsService.instance.setUserId('');
    
    state = AuthState();
  }

  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
    StorageService.saveUserData(user.toJson());
  }

  /// Refresh user data from the server
  Future<void> refreshUser() async {
    try {
      final response = await _apiService.get(ApiConstants.userProfile);
      final userData = response.data['user'];
      
      if (userData != null) {
        final cleanUserData = _cleanUserData(userData);
        final user = UserModel.fromJson(cleanUserData);
        state = state.copyWith(user: user);
        await StorageService.saveUserData(user.toJson());
      }
    } catch (e) {
      Logger.error('Failed to refresh user data', e, null, 'AuthNotifier');
    }
  }

  /// Initialize notifications asynchronously (non-blocking)
  void _initializeNotificationsAsync() {
    Future.microtask(() async {
      try {
        Logger.debug('Initializing notifications after auth...', 'AuthNotifier');
        final notificationService = _ref?.read(notificationServiceProvider);
        if (notificationService != null) {
          await notificationService.initialize();
          Logger.info('Notifications initialized', 'AuthNotifier');
        }
      } catch (e, stackTrace) {
        Logger.error(
          'Failed to initialize notifications',
          e,
          stackTrace,
          'AuthNotifier',
        );
        // Silently fail - user can enable notifications from settings
      }
    });
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AuthNotifier(apiService, ref);
});
