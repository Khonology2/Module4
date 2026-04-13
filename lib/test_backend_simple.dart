// ignore_for_file: avoid_print

import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

void main() async {
  print('🔌 Testing Backend Connection...\n');
  
  try {
    // Test basic backend connectivity
    print('🌐 Testing backend health check...');
    final healthResponse = await http.get(Uri.parse('http://localhost:3001/api/v1/health'));
    print('✅ Health check: ${healthResponse.statusCode} - ${healthResponse.body}');
    
    // Test authentication endpoint
    print('\n🔐 Testing authentication endpoint...');
    final loginResponse = await http.post(
      Uri.parse('http://localhost:3001/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': 'admin@flowspace.com',
        'password': 'password',
      }),
    );
    
    print('✅ Login response: ${loginResponse.statusCode}');
    
    if (loginResponse.statusCode == 200) {
      final data = jsonDecode(loginResponse.body);
      print('✅ Login successful!');
      print('   User: ${data['user']?['name']}');
      print('   Role: ${data['user']?['role']}');
      print('   Token: ${data['token']?.toString().substring(0, 20)}...');
      
      // Test system stats endpoint with the token
      final token = data['token'] ?? data['access_token'];
      if (token != null) {
        print('\n📊 Testing system stats endpoint...');
        final statsResponse = await http.get(
          Uri.parse('http://localhost:3001/api/v1/system/stats'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        
        print('✅ System stats response: ${statsResponse.statusCode}');
        if (statsResponse.statusCode == 200) {
          print('🎉 System stats endpoint is working!');
        } else {
          print('⚠️  System stats endpoint returned: ${statsResponse.body}');
        }
      }
    } else {
      print('❌ Login failed: ${loginResponse.body}');
    }
    
  } catch (e) {
    print('❌ Backend connection test failed: $e');
    print('\n💡 Troubleshooting tips:');
    print('   - Make sure backend server is running on port 3001');
    print('   - Check if admin user exists in database');
    print('   - Verify database connection');
  }
}