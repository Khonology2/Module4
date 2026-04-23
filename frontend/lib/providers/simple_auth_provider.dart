import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import '../services/api_service.dart';

// Simple auth state for demo purposes
class AuthState {
  final bool isLoading;
  final String? error;
  final String? userEmail;

  AuthState({
    this.isLoading = false,
    this.error,
    this.userEmail,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    String? userEmail,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      userEmail: userEmail ?? this.userEmail,
    );
  }
}

class SimpleAuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState();
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = ref.read(authServiceProvider);
      final ok = await auth.signIn(email, password);
      if (ok) {
        state = state.copyWith(
          isLoading: false,
          userEmail: auth.currentUser?.email ?? email,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid email or password',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sign in failed: $e',
      );
    }
  }

  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String company,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = ref.read(authServiceProvider);
      final result = await ApiService.signUp(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        company: company,
        role: role,
      );
      if (result?['success'] == true) {
        state = state.copyWith(
          isLoading: false,
          userEmail: auth.currentUser?.email ?? email,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: (result?['error']?.toString() ?? 'Registration failed. Please check your details.'),
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: $e',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      state = state.copyWith(
        isLoading: false,
        error: 'Google sign-in is not available',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Google sign-in failed: $e',
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = ref.read(authServiceProvider);
      final ok = await auth.forgotPassword(email);
      state = state.copyWith(
        isLoading: false,
        error: ok ? null : 'Failed to send password reset email',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send password reset email: $e',
      );
    }
  }

  Future<void> resendEmailVerification() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final email = state.userEmail;
      if (email == null || email.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'No email available');
        return;
      }
      final auth = ref.read(authServiceProvider);
      final response = await auth.resendVerificationEmail(email);
      state = state.copyWith(
        isLoading: false,
        error: response.isSuccess ? null : (response.error ?? 'Failed to resend verification email'),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to resend verification email: $e',
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signOut();
      state = state.copyWith(
        isLoading: false,
        userEmail: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sign out failed: $e',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authStateProvider = NotifierProvider<SimpleAuthNotifier, AuthState>(() {
  return SimpleAuthNotifier();
});
