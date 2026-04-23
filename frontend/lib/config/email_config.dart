// Pure Dart configuration without Flutter dependencies

class EmailConfig {
  // SMTP Server Configuration
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;
  static const bool useTLS = true;
  static const bool useSSL = false;

  // Email Credentials (In production, these should be environment variables)
  static const String smtpUsername = 'dhlaminibusisiwe30@gmail.com';
  static const String smtpPassword = 'bplcqegzkspgotfk';
  
  // Sender Information
  static const String fromEmail = 'dhlaminibusisiwe30@gmail.com';
  static const String fromName = 'Flownet Workspaces';
  static const String replyToEmail = 'support@flownet.works';

  // Email Templates Configuration
  static const String companyName = 'Flownet Workspaces';
  static const String companyWebsite = 'https://flownet.works';
  static const String supportEmail = 'support@flownet.works';
  static const String supportPhone = '+1 (555) 123-4567';

  // Verification Code Configuration
  static const int verificationCodeLength = 6;
  static const Duration verificationCodeExpiry = Duration(minutes: 15);
  static const int maxVerificationAttempts = 3;

  // Email Rate Limiting
  static const Duration emailCooldown = Duration(minutes: 1);
  static const int maxEmailsPerHour = 10;
  static const int maxEmailsPerDay = 50;

  // Development vs Production Settings
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
  
  // Enable real email sending (disable mock mode for testing)
  static bool get useMockEmailService => false;
  
  // Email logging for development
  static bool get enableEmailLogging => !isProduction;

  // Get SMTP configuration based on environment
  static Map<String, dynamic> getSmtpConfig() {
    if (useMockEmailService) {
      return {
        'host': 'localhost',
        'port': 1025,
        'username': 'test',
        'password': 'test',
        'useTLS': false,
        'useSSL': false,
      };
    }

    return {
      'host': smtpHost,
      'port': smtpPort,
      'username': smtpUsername,
      'password': smtpPassword,
      'useTLS': useTLS,
      'useSSL': useSSL,
      'allowInsecure': false,
      'ignoreBadCertificate': false,
    };
  }

  // Get sender information
  static Map<String, String> getSenderInfo() {
    return {
      'fromEmail': fromEmail,
      'fromName': fromName,
      'replyTo': replyToEmail,
    };
  }

  // Get company information
  static Map<String, String> getCompanyInfo() {
    return {
      'name': companyName,
      'website': companyWebsite,
      'supportEmail': supportEmail,
      'supportPhone': supportPhone,
    };
  }

  // Email validation
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // Get email template variables
  static Map<String, String> getTemplateVariables() {
    final companyInfo = getCompanyInfo();
    return {
      'COMPANY_NAME': companyInfo['name']!,
      'COMPANY_WEBSITE': companyInfo['website']!,
      'SUPPORT_EMAIL': companyInfo['supportEmail']!,
      'SUPPORT_PHONE': companyInfo['supportPhone']!,
      'CURRENT_YEAR': DateTime.now().year.toString(),
    };
  }
}
