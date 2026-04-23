import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/jira_service.dart';
import '../services/auth_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/flownet_logo.dart';

class JiraConfigScreen extends StatefulWidget {
  const JiraConfigScreen({super.key});

  @override
  State<JiraConfigScreen> createState() => _JiraConfigScreenState();
}

class _JiraConfigScreenState extends State<JiraConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _domainController = TextEditingController();
  final _emailController = TextEditingController();
  final _apiTokenController = TextEditingController();
  
  final JiraService _jiraService = JiraService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isConnected = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _domainController.text = prefs.getString('jira_domain') ?? '';
      _emailController.text = prefs.getString('jira_email') ?? '';
      _apiTokenController.text = prefs.getString('jira_api_token') ?? '';
    });
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jira_domain', _domainController.text.trim());
    await prefs.setString('jira_email', _emailController.text.trim());
    await prefs.setString('jira_api_token', _apiTokenController.text.trim());
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _connectionStatus = null;
    });

    try {
      _jiraService.initialize(
        domain: _domainController.text.trim(),
        email: _emailController.text.trim(),
        apiToken: _apiTokenController.text.trim(),
        userId: _authService.currentUser?.id ?? 'unknown-user',
      );

      final isConnected = await _jiraService.testConnection();
      
      setState(() {
        _isConnected = isConnected;
        _isLoading = false;
        _connectionStatus = isConnected 
            ? '✅ Successfully connected to Jira!' 
            : '❌ Failed to connect. Please check your credentials.';
      });

      if (isConnected) {
        await _saveCredentials();
        _showSnackBar('Jira connection successful!', isError: false);
      } else {
        _showSnackBar('Jira connection failed. Please check your credentials.', isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _connectionStatus = '❌ Connection error: $e';
      });
      _showSnackBar('Error testing connection: $e', isError: true);
    }
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jira_domain');
    await prefs.remove('jira_email');
    await prefs.remove('jira_api_token');
    
    setState(() {
      _domainController.clear();
      _emailController.clear();
      _apiTokenController.clear();
      _isConnected = false;
      _connectionStatus = null;
    });
    
    _showSnackBar('Jira credentials cleared', isError: false);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: FlownetColors.charcoalBlack,
        foregroundColor: FlownetColors.pureWhite,
        title: const Text('Jira Configuration'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearCredentials,
              tooltip: 'Clear credentials',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FlownetLogo(),
              const SizedBox(height: 32),
              
              Text(
                'Jira Integration',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: FlownetColors.pureWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Connect your Jira instance to manage sprints, issues, and team collaboration.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: FlownetColors.pureWhite.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 32),

              // Connection Status
              if (_connectionStatus != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isConnected 
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isConnected ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _connectionStatus!,
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              
              if (_connectionStatus != null) const SizedBox(height: 24),

              // Domain Field
              _buildTextField(
                controller: _domainController,
                label: 'Jira Domain',
                hint: 'your-domain (without .atlassian.net)',
                icon: Icons.domain,
                validator: (value) => value?.isEmpty == true ? 'Domain is required' : null,
              ),
              const SizedBox(height: 16),

              // Email Field
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                hint: 'your-email@company.com',
                icon: Icons.email,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Email is required';
                  if (!value!.contains('@')) return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // API Token Field
              _buildTextField(
                controller: _apiTokenController,
                label: 'API Token',
                hint: 'Your Jira API token',
                icon: Icons.key,
                isPassword: true,
                validator: (value) => value?.isEmpty == true ? 'API Token is required' : null,
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _testConnection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlownetColors.electricBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Test Connection',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Setup Instructions
              _buildSetupInstructions(),
              const SizedBox(height: 24),

              // Features List
              _buildFeaturesList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: FlownetColors.pureWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          validator: validator,
          style: const TextStyle(color: FlownetColors.pureWhite),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: FlownetColors.pureWhite.withValues(alpha: 0.6)),
            prefixIcon: Icon(icon, color: FlownetColors.electricBlue),
            filled: true,
            fillColor: FlownetColors.charcoalBlack.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: FlownetColors.pureWhite.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: FlownetColors.pureWhite.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: FlownetColors.electricBlue),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupInstructions() {
    return Card(
      color: FlownetColors.charcoalBlack.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: FlownetColors.electricBlue),
                const SizedBox(width: 8),
                Text(
                  'How to get your Jira API Token',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: FlownetColors.pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Go to https://id.atlassian.com/manage-profile/security/api-tokens\n'
              '2. Click "Create API token"\n'
              '3. Give it a label (e.g., "Flow-Space")\n'
              '4. Copy the generated token\n'
              '5. Use your Jira email and the token above',
              style: TextStyle(
                color: FlownetColors.pureWhite,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FlownetColors.electricBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FlownetColors.electricBlue.withValues(alpha: 0.3)),
              ),
              child: const Text(
                '💡 Tip: Your domain should be just the part before .atlassian.net. '
                'For example, if your Jira URL is "company.atlassian.net", enter "company".',
                style: TextStyle(
                  color: FlownetColors.electricBlue,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    return Card(
      color: FlownetColors.charcoalBlack.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: FlownetColors.electricBlue),
                const SizedBox(width: 8),
                Text(
                  'Jira Integration Features',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: FlownetColors.pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFeatureItem('Create and manage sprints', Icons.timer),
            _buildFeatureItem('View and assign issues', Icons.bug_report),
            _buildFeatureItem('Track team members', Icons.people),
            _buildFeatureItem('Monitor sprint progress', Icons.timeline),
            _buildFeatureItem('Import existing projects', Icons.folder_open),
            _buildFeatureItem('Real-time synchronization', Icons.sync),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: FlownetColors.electricBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: FlownetColors.pureWhite,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
