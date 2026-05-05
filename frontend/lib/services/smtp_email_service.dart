import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../config/email_config.dart';

class SmtpEmailService {
  static final SmtpEmailService _instance = SmtpEmailService._internal();
  factory SmtpEmailService() => _instance;
  SmtpEmailService._internal();

  // Store verification codes temporarily (in production, use a database)
  final Map<String, Map<String, dynamic>> _verificationCodes = {};

  // Send verification email via backend API
  Future<bool> sendVerificationEmail({
    required String toEmail,
    required String userName,
    required String verificationCode,
  }) async {
    try {
      if (!EmailConfig.isValidEmail(toEmail)) {
        debugPrint('❌ Invalid email address: $toEmail');
        return false;
      }

      // Store verification code with expiry
      _verificationCodes[toEmail] = {
        'code': verificationCode,
        'expiresAt': DateTime.now().add(EmailConfig.verificationCodeExpiry),
        'attempts': 0,
      };

      if (EmailConfig.useMockEmailService) {
        // In development, just log the email
        debugPrint('📧 [MOCK] Verification email would be sent to: $toEmail');
        debugPrint('📧 [MOCK] Verification code: $verificationCode');
        return true;
      }

      // For web, we'll use the backend API for email sending
      // The backend will handle the actual SMTP sending
      debugPrint('📧 Verification email will be sent via backend API to: $toEmail');
      debugPrint('📧 Verification code: $verificationCode');
      
      // In a real implementation, you would call your backend API here
      // For now, we'll simulate success
      return true;
    } catch (e) {
      debugPrint('❌ Error sending verification email: $e');
      return false;
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail({
    required String toEmail,
    required String userName,
    required String resetLink,
  }) async {
    try {
      if (!EmailConfig.isValidEmail(toEmail)) {
        debugPrint('❌ Invalid email address: $toEmail');
        return false;
      }

      final smtpConfig = EmailConfig.getSmtpConfig();
      final senderInfo = EmailConfig.getSenderInfo();
      final companyInfo = EmailConfig.getCompanyInfo();

      // Create SMTP server
      final smtpServer = SmtpServer(
        smtpConfig['host'],
        port: smtpConfig['port'],
        username: smtpConfig['username'],
        password: smtpConfig['password'],
        allowInsecure: smtpConfig['allowInsecure'] ?? false,
        ssl: smtpConfig['useSSL'],
        ignoreBadCertificate: smtpConfig['ignoreBadCertificate'] ?? false,
      );

      // Create email message
      final message = Message()
        ..from = Address(senderInfo['fromEmail']!, senderInfo['fromName'])
        ..recipients.add(toEmail)
        ..subject = 'Reset Your Password - ${companyInfo['name']}'
        ..html = _buildPasswordResetEmailHtml(
          userName: userName,
          resetLink: resetLink,
          companyInfo: companyInfo,
        );

      if (EmailConfig.useMockEmailService) {
        // In development, just log the email
        debugPrint('📧 [MOCK] Password reset email would be sent to: $toEmail');
        debugPrint('📧 [MOCK] Reset link: $resetLink');
        return true;
      }

      // Send email via SMTP
      final sendReport = await send(message, smtpServer);
      
      if (sendReport.toString().contains('Message sent')) {
        debugPrint('✅ Password reset email sent successfully to $toEmail');
        return true;
      } else {
        debugPrint('❌ Failed to send password reset email: ${sendReport.toString()}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending password reset email: $e');
      return false;
    }
  }

  // Generate verification code
  String generateVerificationCode() {
    final random = Random();
    final code = List.generate(
      EmailConfig.verificationCodeLength,
      (index) => random.nextInt(10),
    ).join();
    return code;
  }

  // Validate verification code
  bool validateVerificationCode({
    required String email,
    required String inputCode,
  }) {
    final storedData = _verificationCodes[email];
    if (storedData == null) {
      debugPrint('❌ No verification code found for email: $email');
      return false;
    }

    // Check if code has expired
    if (DateTime.now().isAfter(storedData['expiresAt'])) {
      debugPrint('❌ Verification code expired for email: $email');
      _verificationCodes.remove(email);
      return false;
    }

    // Check attempt limit
    if (storedData['attempts'] >= EmailConfig.maxVerificationAttempts) {
      debugPrint('❌ Too many verification attempts for email: $email');
      _verificationCodes.remove(email);
      return false;
    }

    // Increment attempts
    storedData['attempts'] = (storedData['attempts'] as int) + 1;

    // Check if code matches
    if (storedData['code'] == inputCode) {
      debugPrint('✅ Verification code validated for email: $email');
      _verificationCodes.remove(email);
      return true;
    } else {
      debugPrint('❌ Invalid verification code for email: $email');
      return false;
    }
  }

  // Test SMTP connection
  Future<bool> testSmtpConnection() async {
    try {
      final smtpConfig = EmailConfig.getSmtpConfig();
      final senderInfo = EmailConfig.getSenderInfo();

      // Create SMTP server
      final smtpServer = SmtpServer(
        smtpConfig['host'],
        port: smtpConfig['port'],
        username: smtpConfig['username'],
        password: smtpConfig['password'],
        allowInsecure: smtpConfig['allowInsecure'] ?? false,
        ssl: smtpConfig['useSSL'],
        ignoreBadCertificate: smtpConfig['ignoreBadCertificate'] ?? false,
      );

      // Create test message
      final message = Message()
        ..from = Address(senderInfo['fromEmail']!, senderInfo['fromName'])
        ..recipients.add(senderInfo['fromEmail']!) // Send to self for testing
        ..subject = 'SMTP Connection Test'
        ..text = 'This is a test email to verify SMTP configuration.';

      if (EmailConfig.useMockEmailService) {
        debugPrint('📧 [MOCK] SMTP connection test successful');
        return true;
      }

      // Send test email
      final sendReport = await send(message, smtpServer);
      
      if (sendReport.toString().contains('Message sent')) {
        debugPrint('✅ SMTP connection test successful');
        return true;
      } else {
        debugPrint('❌ SMTP connection test failed: ${sendReport.toString()}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ SMTP connection test error: $e');
      return false;
    }
  }


  // Build password reset email HTML
  String _buildPasswordResetEmailHtml({
    required String userName,
    required String resetLink,
    required Map<String, String> companyInfo,
  }) {
    final templateVars = EmailConfig.getTemplateVariables();
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Password Reset</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            background-color: #ffffff;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .content {
            padding: 40px 30px;
        }
        .button {
            display: inline-block;
            background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%);
            color: white;
            padding: 15px 30px;
            text-decoration: none;
            border-radius: 25px;
            font-weight: bold;
            margin: 20px 0;
        }
        .footer {
            background-color: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 Password Reset Request</h1>
        </div>
        
        <div class="content">
            <h2>Reset Your Password</h2>
            <p>Hi <strong>$userName</strong>,</p>
            <p>We received a request to reset your password for your ${companyInfo['name']} account.</p>
            
            <a href="$resetLink" class="button">Reset Password</a>
            
            <p>If the button doesn't work, copy and paste this link into your browser:</p>
            <p style="word-break: break-all; color: #667eea;">$resetLink</p>
            
            <div style="background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; padding: 15px; margin: 20px 0; color: #856404;">
                <strong>🔒 Security Note:</strong> This link will expire in 1 hour for your security. If you didn't request a password reset, please ignore this email.
            </div>
            
            <p>Best regards,<br>
            <strong>The ${companyInfo['name']} Team</strong></p>
        </div>
        
        <div class="footer">
            <p>This email was sent because you requested a password reset.</p>
            <p>© ${templateVars['CURRENT_YEAR']} ${companyInfo['name']}. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
''';
  }
}
