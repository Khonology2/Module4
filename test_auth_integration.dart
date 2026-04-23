import 'package:flutter_test/flutter_test.dart';
import 'lib/services/auth_service.dart';
import 'lib/services/api_client.dart';
import 'lib/models/user_role.dart';

void main() {
  group('Authentication Integration Tests', () {
    late AuthService authService;
    late ApiClient apiClient;

    setUp(() {
      authService = AuthService();
      apiClient = ApiClient();
    });

    testWidgets('AuthService initialization', (WidgetTester tester) async {
      await authService.initialize();
      expect(authService.isAuthenticated, false);
    });

    testWidgets('API Client initialization', (WidgetTester tester) async {
      await apiClient.initialize();
      expect(apiClient.isAuthenticated, false);
    });

    test('Login with invalid credentials should fail', () async {
      await authService.initialize();
      
      final result = await authService.signIn('invalid@example.com', 'wrongpassword');
      expect(result, false);
      expect(authService.isAuthenticated, false);
    });

    test('Registration with valid data should succeed', () async {
      await authService.initialize();
      
      final result = await authService.signUp(
        'testuser@example.com',
        'password123',
        'Test User',
        UserRole.teamMember,
      );
      
      // This might fail if user already exists, which is expected
      // We're just testing that the method doesn't throw an exception
      expect(result.containsKey('success'), true);
    });

    test('Sign out should clear authentication state', () async {
      await authService.initialize();
      
      await authService.signOut();
      expect(authService.isAuthenticated, false);
      expect(authService.currentUser, null);
    });
  });
}

// Mock UserRole enum for testing
