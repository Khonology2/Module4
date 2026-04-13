// ignore_for_file: avoid_print

import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

void main() async {
  print('Testing login functionality...');
  
  // Test if backend is running
  try {
    final response = await http.get(Uri.parse('http://localhost:3001/api/v1/health'));
    print('Backend health check: ${response.statusCode} - ${response.body}');
  } catch (e) {
    print('Backend health check failed: $e');
    return;
  }
  
  // Test login endpoint directly
  try {
    final loginResponse = await http.post(
      Uri.parse('http://localhost:3001/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': 'Thabang.Nkabinde@khonology.com',
        'password': 'password123',
      }),
    );
    
    print('Login response: ${loginResponse.statusCode}');
    print('Login response body: ${loginResponse.body}');
    
    if (loginResponse.statusCode == 200) {
      final data = jsonDecode(loginResponse.body);
      print('Login successful!');
      print('User role: ${data['user']?['role']}');
      
      // Check if user has admin privileges
      final userRole = data['user']?['role']?.toString().toLowerCase();
      final isAdmin = userRole == 'clientreviewer' || userRole == 'systemadmin' || userRole == 'admin';
      
      print('User has admin privileges: $isAdmin');
      
      if (isAdmin) {
        print('✓ Admin features should be available in the sidebar');
        print('✓ User can access role management');
        print('✓ User can manage user permissions');
      } else {
        print('✗ User does not have admin privileges');
      }
    } else {
      print('Login failed with status: ${loginResponse.statusCode}');
    }
  } catch (e) {
    print('Login test failed: $e');
  }
}