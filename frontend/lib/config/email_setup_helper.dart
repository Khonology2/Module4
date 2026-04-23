// Pure Dart helper without Flutter dependencies
import 'dart:developer' as developer;

/// Helper class to guide users through SMTP email configuration
class EmailSetupHelper {
  
  /// Get step-by-step instructions for Gmail setup
  static List<String> getGmailSetupSteps() {
    return [
      '1. Go to your Google Account settings (https://myaccount.google.com/)',
      '2. Click on \'Security\' in the left sidebar',
      '3. Under \'Signing in to Google\', click \'2-Step Verification\'',
      '4. If not enabled, follow the prompts to enable 2FA',
      '5. Once 2FA is enabled, go back to Security settings',
      '6. Under \'Signing in to Google\', click \'App passwords\'',
      '7. Select \'Mail\' as the app and \'Other\' as the device',
      '8. Enter \'Flutter App\' as the device name',
      '9. Click \'Generate\' and copy the 16-character password',
      '10. Use this password in your email configuration',
    ];
  }

  /// Get step-by-step instructions for Outlook setup
  static List<String> getOutlookSetupSteps() {
    return [
      '1. Go to your Microsoft Account settings',
      '2. Click on \'Security\' in the left sidebar',
      '3. Under \'Security options\', click \'Advanced security options\'',
      '4. Turn on \'Two-step verification\' if not already enabled',
      '5. Under \'App passwords\', click \'Create a new app password\'',
      '6. Enter \'Flutter App\' as the app name',
      '7. Click \'Next\' and copy the generated password',
      '8. Use this password in your email configuration',
    ];
  }

  /// Get step-by-step instructions for Yahoo setup
  static List<String> getYahooSetupSteps() {
    return [
      '1. Go to your Yahoo Account security settings',
      '2. Click on \'Two-step verification\'',
      '3. Enable two-step verification if not already enabled',
      '4. Go to \'App passwords\' section',
      '5. Click \'Generate app password\'',
      '6. Enter \'Flutter App\' as the app name',
      '7. Click \'Generate\' and copy the password',
      '8. Use this password in your email configuration',
    ];
  }

  /// Validate email configuration
  static Map<String, String> validateEmailConfig({
    required String smtpHost,
    required int smtpPort,
    required String smtpUsername,
    required String smtpPassword,
    required String fromEmail,
  }) {
    final errors = <String, String>{};

    // Validate email format
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(smtpUsername)) {
      errors['smtpUsername'] = 'Invalid email format';
    }
    if (!emailRegex.hasMatch(fromEmail)) {
      errors['fromEmail'] = 'Invalid email format';
    }

    // Validate SMTP host
    if (smtpHost.isEmpty) {
      errors['smtpHost'] = 'SMTP host cannot be empty';
    }

    // Validate port
    if (smtpPort <= 0 || smtpPort > 65535) {
      errors['smtpPort'] = 'Invalid port number';
    }

    // Validate password
    if (smtpPassword.isEmpty) {
      errors['smtpPassword'] = 'Password cannot be empty';
    } else if (smtpPassword.length < 8) {
      errors['smtpPassword'] = 'Password too short (minimum 8 characters)';
    }

    return errors;
  }

  /// Get recommended SMTP settings for different providers
  static Map<String, dynamic> getRecommendedSettings(String provider) {
    switch (provider.toLowerCase()) {
      case 'gmail':
        return {
          'host': 'smtp.gmail.com',
          'port': 587,
          'useTLS': true,
          'useSSL': false,
          'description': 'Gmail SMTP with TLS encryption',
        };
      case 'outlook':
      case 'hotmail':
        return {
          'host': 'smtp-mail.outlook.com',
          'port': 587,
          'useTLS': true,
          'useSSL': false,
          'description': 'Outlook/Hotmail SMTP with TLS encryption',
        };
      case 'yahoo':
        return {
          'host': 'smtp.mail.yahoo.com',
          'port': 587,
          'useTLS': true,
          'useSSL': false,
          'description': 'Yahoo Mail SMTP with TLS encryption',
        };
      default:
        return {
          'host': 'smtp.gmail.com',
          'port': 587,
          'useTLS': true,
          'useSSL': false,
          'description': 'Default Gmail settings',
        };
    }
  }

  /// Generate configuration code for the user
  static String generateConfigCode({
    required String smtpHost,
    required int smtpPort,
    required String smtpUsername,
    required String smtpPassword,
    required String fromEmail,
    required String fromName,
    required bool useTLS,
    required bool useSSL,
  }) {
    return '''
// Update your lib/config/email_config.dart file with these values:

class EmailConfig {
  // SMTP Server Configuration
  static const String smtpHost = '$smtpHost';
  static const int smtpPort = $smtpPort;
  static const bool useTLS = $useTLS;
  static const bool useSSL = $useSSL;

  // Email Credentials
  static const String smtpUsername = '$smtpUsername';
  static const String smtpPassword = '$smtpPassword';
  
  // Sender Information
  static const String fromEmail = '$fromEmail';
  static const String fromName = '$fromName';
  // ... rest of your configuration
}
''';
  }

  /// Test configuration with a simple validation
  static bool testConfiguration({
    required String smtpHost,
    required int smtpPort,
    required String smtpUsername,
    required String smtpPassword,
  }) {
    // Basic validation
    final errors = validateEmailConfig(
      smtpHost: smtpHost,
      smtpPort: smtpPort,
      smtpUsername: smtpUsername,
      smtpPassword: smtpPassword,
      fromEmail: smtpUsername, // Use same email for from
    );

    const isDebug = !bool.fromEnvironment('dart.vm.product');
    if (isDebug) {
      if (errors.isEmpty) {
        developer.log('✅ Email configuration validation passed');
      } else {
        developer.log('❌ Email configuration validation failed:');
        errors.forEach((key, value) {
          developer.log('  - $key: $value');
        });
      }
    }

    return errors.isEmpty;
  }
}
