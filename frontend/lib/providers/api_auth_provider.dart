import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ApiAuthProvider with ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  // Initialize the provider
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await ApiService.initialize();
    } catch (e) {
      _setError('Failed to initialize API service: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Sign up method
  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String company,
    required String role,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await ApiService.signUp(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        company: company,
        role: role,
      );

      if (response != null && response['user'] != null) {
        _user = response['user'];
        notifyListeners();
        return true;
      } else if (response != null && response['error'] != null) {
        // Handle error response from API
        _setError(response['message'] ?? response['error'] ?? 'Failed to create account');
        return false;
      } else {
        _setError('Failed to create account');
        return false;
      }
    } catch (e) {
      _setError('Sign up failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in method
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await ApiService.signIn(
        email: email,
        password: password,
      );

      if (response != null && response['user'] != null) {
        _user = response['user'];
        notifyListeners();
        return true;
      } else {
        _setError('Invalid email or password');
        return false;
      }
    } catch (e) {
      _setError('Sign in failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out method
  Future<void> signOut() async {
    _user = null;
    _clearError();
    notifyListeners();
  }

  // Get user profile
  Map<String, dynamic>? get userProfile {
    if (_user == null) return null;
    
    return {
      'id': _user!['id'],
      'email': _user!['email'],
      'first_name': _user!['user_metadata']['first_name'],
      'last_name': _user!['user_metadata']['last_name'],
      'company': _user!['user_metadata']['company'],
      'role': _user!['user_metadata']['role'],
      'created_at': _user!['created_at'],
    };
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
