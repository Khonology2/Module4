// ignore_for_file: avoid_print

import 'services/backend_api_service.dart';

void main() async {
  print('🔌 Testing Backend Connection...\n');
  
  try {
    final backendService = BackendApiService();
    final response = await backendService.getSystemStats();
    
    print('✅ Backend connection successful!');
    print('📋 Response Status: \${response.statusCode}');
    print('📦 Response Data Type: \${response.data?.runtimeType}');
    
    if (response.isSuccess && response.data != null) {
      print('📊 Data Keys: \${response.data!.keys.toList()}');
      print('🎉 Backend system stats endpoint is working!');
    } else {
      print('❌ Backend returned error: \${response.error}');
    }
    
  } catch (e) {
    print('❌ Error connecting to backend: \$e');
    print('\n⚠️ This might indicate that:');
    print('   - Backend server is not running');
    print('   - Network connectivity issues');
    print('   - CORS or firewall restrictions');
  }
}
