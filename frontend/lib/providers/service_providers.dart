import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/backend_api_service.dart';
import '../services/api_client.dart';
import '../services/error_handler.dart';
import '../services/realtime_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';

// Service providers for dependency injection
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final backendApiServiceProvider = Provider<BackendApiService>((ref) {
  return BackendApiService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final errorHandlerProvider = Provider<ErrorHandler>((ref) {
  return ErrorHandler();
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService();
});

// User state provider
final currentUserProvider = NotifierProvider<UserNotifier, User?>(() {
  return UserNotifier();
});

final isAuthenticatedProvider = NotifierProvider<AuthNotifier, bool>(() {
  return AuthNotifier();
});

// User state notifier
class UserNotifier extends Notifier<User?> {
  @override
  User? build() => null;
  
  void setUser(User? user) {
    state = user;
  }
  
  void clearUser() {
    state = null;
  }
}

// Auth state notifier
class AuthNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void setAuthenticated(bool isAuthenticated) {
    state = isAuthenticated;
  }
}

// Theme state notifier
class ThemeNotifier extends Notifier<bool> {
  @override
  bool build() => true; // Start in dark mode

  void setDarkTheme() {
    state = true;
  }

  void setLightTheme() {
    state = false;
  }

  void toggleTheme() {
    state = !state;
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, bool>(() {
  return ThemeNotifier();
});