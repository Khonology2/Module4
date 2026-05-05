import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/email_setup_helper.dart';
import '../config/email_config.dart';
import '../services/smtp_email_service.dart';
import '../widgets/app_modal.dart';

class SmtpConfigScreen extends StatefulWidget {
  const SmtpConfigScreen({super.key});

  @override
  State<SmtpConfigScreen> createState() => _SmtpConfigScreenState();
}

class _SmtpConfigScreenState extends State<SmtpConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _smtpHostController = TextEditingController(text: 'smtp.gmail.com');
  final _smtpPortController = TextEditingController(text: '587');
  final _smtpUsernameController = TextEditingController();
  final _smtpPasswordController = TextEditingController();
  final _fromEmailController = TextEditingController();
  final _fromNameController = TextEditingController(text: 'Flownet Workspaces');
  
  bool _useTLS = true;
  bool _useSSL = false;
  bool _isLoading = false;
  String _selectedProvider = 'gmail';
  String _testResult = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    _smtpHostController.text = EmailConfig.smtpHost;
    _smtpPortController.text = EmailConfig.smtpPort.toString();
    _smtpUsernameController.text = EmailConfig.smtpUsername;
    _smtpPasswordController.text = EmailConfig.smtpPassword;
    _fromEmailController.text = EmailConfig.fromEmail;
    _fromNameController.text = EmailConfig.fromName;
    _useTLS = EmailConfig.useTLS;
    _useSSL = EmailConfig.useSSL;
  }

  void _onProviderChanged(String provider) {
    setState(() {
      _selectedProvider = provider;
      final settings = EmailSetupHelper.getRecommendedSettings(provider);
      _smtpHostController.text = settings['host'];
      _smtpPortController.text = settings['port'].toString();
      _useTLS = settings['useTLS'];
      _useSSL = settings['useSSL'];
    });
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _testResult = '';
    });

    try {
      // Test the configuration
      final isValid = EmailSetupHelper.testConfiguration(
        smtpHost: _smtpHostController.text,
        smtpPort: int.parse(_smtpPortController.text),
        smtpUsername: _smtpUsernameController.text,
        smtpPassword: _smtpPasswordController.text,
      );

      if (isValid) {
        // Test actual SMTP connection
        final emailService = SmtpEmailService();
        final isConnected = await emailService.testSmtpConnection();
        
        setState(() {
          _testResult = isConnected 
            ? '✅ SMTP connection successful!'
            : '❌ SMTP connection failed. Check your credentials.';
        });
      } else {
        setState(() {
          _testResult = '❌ Configuration validation failed.';
        });
      }
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSetupInstructions() {
    List<String> steps;
    String title;
    
    switch (_selectedProvider) {
      case 'gmail':
        title = 'Gmail Setup Instructions';
        steps = EmailSetupHelper.getGmailSetupSteps();
        break;
      case 'outlook':
        title = 'Outlook Setup Instructions';
        steps = EmailSetupHelper.getOutlookSetupSteps();
        break;
      case 'yahoo':
        title = 'Yahoo Setup Instructions';
        steps = EmailSetupHelper.getYahooSetupSteps();
        break;
      default:
        title = 'Setup Instructions';
        steps = EmailSetupHelper.getGmailSetupSteps();
    }

    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: steps.map((step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(step),
            ),).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _generateConfigCode() {
    final configCode = EmailSetupHelper.generateConfigCode(
      smtpHost: _smtpHostController.text,
      smtpPort: int.parse(_smtpPortController.text),
      smtpUsername: _smtpUsernameController.text,
      smtpPassword: _smtpPasswordController.text,
      fromEmail: _fromEmailController.text,
      fromName: _fromNameController.text,
      useTLS: _useTLS,
      useSSL: _useSSL,
    );

    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration Code'),
        content: SingleChildScrollView(
          child: Text(
            configCode,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: configCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuration code copied to clipboard!')),
              );
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMTP Email Configuration'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email Provider',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedProvider,
                        decoration: const InputDecoration(
                          labelText: 'Select Email Provider',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'gmail', child: Text('Gmail')),
                          DropdownMenuItem(value: 'outlook', child: Text('Outlook/Hotmail')),
                          DropdownMenuItem(value: 'yahoo', child: Text('Yahoo Mail')),
                          DropdownMenuItem(value: 'custom', child: Text('Custom SMTP')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _onProviderChanged(value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showSetupInstructions,
                        icon: const Icon(Icons.help_outline),
                        label: const Text('Setup Instructions'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // SMTP Configuration
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SMTP Configuration',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // SMTP Host
                      TextFormField(
                        controller: _smtpHostController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Host',
                          hintText: 'smtp.gmail.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter SMTP host';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // SMTP Port
                      TextFormField(
                        controller: _smtpPortController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Port',
                          hintText: '587',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter SMTP port';
                          }
                          final port = int.tryParse(value);
                          if (port == null || port <= 0 || port > 65535) {
                            return 'Please enter a valid port number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Security Options
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Use TLS'),
                              value: _useTLS,
                              onChanged: (value) {
                                setState(() {
                                  _useTLS = value ?? false;
                                  if (_useTLS) _useSSL = false;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Use SSL'),
                              value: _useSSL,
                              onChanged: (value) {
                                setState(() {
                                  _useSSL = value ?? false;
                                  if (_useSSL) _useTLS = false;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Email Credentials
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email Credentials',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // Username
                      TextFormField(
                        controller: _smtpUsernameController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'your-email@gmail.com',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email address';
                          }
                          if (!EmailConfig.isValidEmail(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _smtpPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'App Password',
                          hintText: 'Your 16-character app password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter app password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Sender Information
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sender Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // From Email
                      TextFormField(
                        controller: _fromEmailController,
                        decoration: const InputDecoration(
                          labelText: 'From Email',
                          hintText: 'noreply@yourcompany.com',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter from email';
                          }
                          if (!EmailConfig.isValidEmail(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // From Name
                      TextFormField(
                        controller: _fromNameController,
                        decoration: const InputDecoration(
                          labelText: 'From Name',
                          hintText: 'Your Company Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter from name';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Test Connection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Connection',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_testResult.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _testResult.contains('✅') 
                              ? Colors.green.shade50 
                              : Colors.red.shade50,
                            border: Border.all(
                              color: _testResult.contains('✅') 
                                ? Colors.green 
                                : Colors.red,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _testResult,
                            style: TextStyle(
                              color: _testResult.contains('✅') 
                                ? Colors.green.shade800 
                                : Colors.red.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _testConnection,
                              icon: _isLoading 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.wifi_protected_setup),
                              label: Text(_isLoading ? 'Testing...' : 'Test Connection'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _generateConfigCode,
                              icon: const Icon(Icons.code),
                              label: const Text('Generate Code'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Security Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Security Note',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Never use your main account password\n'
                      '• Always use app-specific passwords\n'
                      '• For production, use environment variables\n'
                      '• Keep your credentials secure and private',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUsernameController.dispose();
    _smtpPasswordController.dispose();
    _fromEmailController.dispose();
    _fromNameController.dispose();
    super.dispose();
  }
}

