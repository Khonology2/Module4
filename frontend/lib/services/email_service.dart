import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/environment.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  // Email service configuration
  static final String _baseUrl = Environment.apiBaseUrl;
  
  // Send verification email
  Future<bool> sendVerificationEmail({
    required String to,
    required String verificationCode,
    required String userName,
  }) async {
    try {
      debugPrint('📧 Sending verification email to: $to');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/email/send-verification'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': to,
          'verificationCode': verificationCode,
          'userName': userName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Verification email sent successfully');
          return true;
        }
      }
      
      debugPrint('❌ Failed to send verification email: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Error sending verification email: $e');
      return false;
    }
  }

  // Send welcome email after verification
  Future<bool> sendWelcomeEmail({
    required String to,
    required String userName,
  }) async {
    try {
      debugPrint('📧 Sending welcome email to: $to');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/email/send-welcome'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': to,
          'userName': userName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Welcome email sent successfully');
          return true;
        }
      }
      
      debugPrint('❌ Failed to send welcome email: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Error sending welcome email: $e');
      return false;
    }
  }
}
