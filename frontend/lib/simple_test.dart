import 'dart:convert';
import 'dart:io';
import 'services/auth_service.dart';
import 'config/environment.dart';

void main() async {
  final authService = AuthService();
  await authService.signIn('admin@flowspace.com', 'password');
  final token = authService.accessToken;

  final httpClient = HttpClient();
  final request = await httpClient.getUrl(Uri.parse('${Environment.apiBaseUrl}/system/stats'));
  request.headers.add('Authorization', 'Bearer $token');
  final response = await request.close();

  await response.transform(utf8.decoder).join();
}
