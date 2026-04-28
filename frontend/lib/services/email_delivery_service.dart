// ignore_for_file: depend_on_referenced_packages

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/environment.dart';

class EmailDeliveryService {
static String get backendUrl => Environment.apiBaseUrl.replaceAll('/api/v1', '');
  
  // Test email delivery with multiple methods
  static Future<Map<String, dynamic>> testEmailDelivery({
    required String email,
    required String userName,
  }) async {
    // Testing email delivery to: $email
    
    // Method 1: Try backend email service
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/test-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'userName': userName,
          'type': 'verification',
        }),
      );
      
      if (response.statusCode == 200) {
        // Backend email service working
        return {
          'success': true,
          'method': 'backend',
          'message': 'Email sent via backend service',
        };
      }
    } catch (e) {
      // Backend email failed: $e
    }
    
    // Method 2: Try direct SMTP test
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/test-smtp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'userName': userName,
        }),
      );
      
      if (response.statusCode == 200) {
        // Direct SMTP working
        return {
          'success': true,
          'method': 'smtp',
          'message': 'Email sent via direct SMTP',
        };
      }
    } catch (e) {
      // Direct SMTP failed: $e
    }
    
    // Method 3: Try professional email service
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/test-professional-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'userName': userName,
        }),
      );
      
      if (response.statusCode == 200) {
        // Professional email service working
        return {
          'success': true,
          'method': 'professional',
          'message': 'Email sent via professional service',
        };
      }
    } catch (e) {
      // Professional email failed: $e
    }
    
    return {
      'success': false,
      'method': 'none',
      'message': 'All email methods failed',
    };
  }
  
  // Send verification email with fallback
  static Future<bool> sendVerificationEmail({
    required String email,
    required String userName,
  }) async {
    // Sending verification email to: $email
    
    // Try backend first
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/auth/send-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'userName': userName,
        }),
      );
      
      if (response.statusCode == 200) {
        // Verification email sent via backend
        return true;
      }
    } catch (e) {
      // Backend verification email failed: $e
    }
    
    // Try direct email service
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/send-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': email,
          'subject': 'Verify Your Email - Flownet Workspaces',
          'html': _buildVerificationEmailHtml(userName),
        }),
      );
      
      if (response.statusCode == 200) {
        // Verification email sent via direct service
        return true;
      }
    } catch (e) {
      // Direct verification email failed: $e
    }
    
    return false;
  }
  
  static String _buildVerificationEmailHtml(String userName) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Email Verification</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #c41e3a; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background: #f9f9f9; }
            .button { display: inline-block; background: #c41e3a; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
            .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Welcome to Flownet Workspaces!</h1>
            </div>
            <div class="content">
                <h2>Hello $userName,</h2>
                <p>Thank you for registering with Flownet Workspaces. To complete your account setup, please verify your email address.</p>
                <p>This verification helps us ensure the security of your account and enables you to access all features.</p>
                <p>If you have any questions, please don't hesitate to contact our support team.</p>
                <p>Best regards,<br>The Flownet Workspaces Team</p>
            </div>
            <div class="footer">
                <p>This email was sent from Flownet Workspaces. If you didn't request this, please ignore this email.</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }
}
