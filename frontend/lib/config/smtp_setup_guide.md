# SMTP Email Configuration Guide

This guide will help you configure SMTP email settings for sending verification emails in your Flownet Workspaces application.

## 📧 Supported Email Providers

### Gmail (Recommended)
1. **Enable 2-Factor Authentication** on your Google account
2. **Generate an App Password**:
   - Go to Google Account settings
   - Security → 2-Step Verification → App passwords
   - Generate a new app password for "Mail"
3. **Update Configuration**:
   ```dart
   // In lib/config/email_config.dart
   static const String smtpHost = 'smtp.gmail.com';
   static const int smtpPort = 587;
   static const String smtpUsername = 'your-email@gmail.com';
   static const String smtpPassword = 'your-16-character-app-password';
   ```

### Outlook/Hotmail
```dart
static const String smtpHost = 'smtp-mail.outlook.com';
static const int smtpPort = 587;
```

### Yahoo Mail
```dart
static const String smtpHost = 'smtp.mail.yahoo.com';
static const int smtpPort = 587;
```

### Custom SMTP Server
```dart
static const String smtpHost = 'your-smtp-server.com';
static const int smtpPort = 587; // or 465 for SSL
static const bool useSSL = true; // for port 465
```

## 🔧 Configuration Steps

### 1. Update Email Configuration
Edit `lib/config/email_config.dart`:

```dart
class EmailConfig {
  // SMTP Server Configuration
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;
  static const bool useTLS = true;
  static const bool useSSL = false;

  // Email Credentials
  static const String smtpUsername = 'your-email@gmail.com';
  static const String smtpPassword = 'your-app-password';
  
  // Sender Information
  static const String fromEmail = 'your-email@gmail.com';
  static const String fromName = 'Flownet Workspaces';
  static const String replyToEmail = 'support@flownet.works';
}
```

### 2. Environment Variables (Production)
For production, use environment variables instead of hardcoded values:

```dart
// In lib/config/email_config.dart
static String get smtpUsername => 
    const String.fromEnvironment('SMTP_USERNAME', defaultValue: 'your-email@gmail.com');

static String get smtpPassword => 
    const String.fromEnvironment('SMTP_PASSWORD', defaultValue: 'your-app-password');
```

### 3. Test SMTP Connection
Add this to your app initialization:

```dart
// In lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Test SMTP connection
  final emailService = SmtpEmailService();
  final isConnected = await emailService.testSmtpConnection();
  
  if (isConnected) {
    debugPrint('✅ SMTP connection successful');
  } else {
    debugPrint('❌ SMTP connection failed');
  }
  
  runApp(const ProviderScope(child: KhonoApp()));
}
```

## 🛡️ Security Best Practices

### 1. Use App Passwords
- Never use your main account password
- Generate app-specific passwords
- Rotate passwords regularly

### 2. Environment Variables
```bash
# .env file (for development)
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
```

### 3. Production Security
- Use a dedicated email service account
- Enable IP restrictions if possible
- Monitor email sending limits
- Use rate limiting

## 📊 Email Limits

### Gmail Limits
- **Daily**: 500 emails per day
- **Per minute**: 100 emails per minute
- **Recipients per email**: 500 recipients

### Outlook Limits
- **Daily**: 300 emails per day
- **Per minute**: 30 emails per minute

### Yahoo Limits
- **Daily**: 500 emails per day
- **Per minute**: 100 emails per minute

## 🧪 Testing Email Functionality

### 1. Development Testing
```dart
// Test email sending
final emailService = SmtpEmailService();
final success = await emailService.sendVerificationEmail(
  toEmail: 'test@example.com',
  userName: 'Test User',
  verificationCode: '123456',
);
```

### 2. Mock Mode
For development, you can enable mock mode:

```dart
// In lib/config/email_config.dart
static bool get useMockEmailService => !isProduction;
```

## 🚨 Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Check username and password
   - Ensure 2FA is enabled and app password is used
   - Verify SMTP settings

2. **Connection Timeout**
   - Check firewall settings
   - Verify port numbers (587 for TLS, 465 for SSL)
   - Try different SMTP servers

3. **Emails Not Received**
   - Check spam folder
   - Verify recipient email address
   - Check email provider's sending limits

### Debug Mode
Enable debug logging:

```dart
// In lib/services/smtp_email_service.dart
if (EmailConfig.enableEmailLogging) {
  debugPrint('📧 Sending email to: $toEmail');
  debugPrint('📧 Subject: $subject');
}
```

## 📱 Mobile Considerations

### iOS
- Add email permissions in Info.plist
- Test on physical device (simulator may have limitations)

### Android
- Add internet permission in AndroidManifest.xml
- Test on physical device

## 🔄 Production Deployment

### 1. Use Environment Variables
```bash
# Production environment
export SMTP_USERNAME="production-email@company.com"
export SMTP_PASSWORD="secure-app-password"
export SMTP_HOST="smtp.company.com"
export SMTP_PORT="587"
```

### 2. Monitor Email Delivery
- Set up email delivery monitoring
- Track bounce rates
- Monitor spam complaints

### 3. Backup Email Service
Consider using a backup email service provider for redundancy.

## 📞 Support

If you encounter issues:
1. Check the debug logs
2. Test SMTP connection separately
3. Verify email provider settings
4. Contact your email provider's support

---

**Note**: Always test email functionality in a development environment before deploying to production.
