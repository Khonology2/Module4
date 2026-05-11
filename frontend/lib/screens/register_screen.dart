import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../widgets/fixed_footer_version_display.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const double _logoWidth = 360;
  static const double _logoHeight = 78;
  static const double _panelWidth = 420;
  static const double _fieldWidth = 360;
  static const double _inputHeight = 40;
  static const double _buttonHeight = 40;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptTerms = false;
  bool _isLoading = false;
  String? _registerErrorMessage;
  String _selectedRole = 'Developer';

  final List<String> _roles = const [
    'Developer',
    'Project Manager',
    'Scrum Master',
    'QA Engineer',
    'Client',
    'Stakeholder',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.network(
              'https://raw.githubusercontent.com/Khonology2/Module4/Busisiwe/frontend/assets/Icons/khono_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: const Color(0xFF0D0F14));
              },
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    const Color(0xFF090909).withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
          // Content overlay
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo and Title
                            Image.network(
                              'https://raw.githubusercontent.com/Khonology2/Module4/Busisiwe/frontend/assets/Icons/khono.png',
                              height: 60,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.shield_outlined,
                                  size: 52,
                                  color: Colors.white70,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Create Account',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Join Khonology and streamline your delivery process',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Name Fields
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'First Name',
                                      labelStyle: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.3)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFC10D00), width: 2),
                                      ),
                                      filled: true,
                                      fillColor:
                                          Colors.white.withValues(alpha: 0.1),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Last Name',
                                      labelStyle: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.3)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFC10D00), width: 2),
                                      ),
                                      filled: true,
                                      fillColor:
                                          Colors.white.withValues(alpha: 0.1),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFC10D00), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }

                                final email = value.toLowerCase().trim();

                                // Basic email format validation
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(email)) {
                                  return 'Please enter a valid email';
                                }

                                final [username, domain] = email.split('@');

                                // Check for disposable email domains
                                final disposableDomains = [
                                  '10minutemail.com',
                                  'tempmail.org',
                                  'guerrillamail.com',
                                  'mailinator.com',
                                  'yopmail.com',
                                  'temp-mail.org',
                                  'throwaway.email',
                                  'maildrop.cc',
                                  'fakeemail.com',
                                  'tempemail.org',
                                  'sharklasers.com',
                                  'getairmail.com'
                                ];

                                if (disposableDomains.any((disposable) =>
                                    domain.contains(disposable))) {
                                  return 'Disposable email addresses are not allowed';
                                }

                                // Check for valid domain structure
                                if (domain.contains('..') ||
                                    !domain.contains('.')) {
                                  return 'Invalid email domain';
                                }

                                // Enhanced username validation
                                final suspiciousUsernamePatterns = [
                                  RegExp(
                                      r'^(test|fake|dummy|sample|example|demo|user|admin|support|info|contact)',
                                      caseSensitive: false),
                                  RegExp(
                                      r'^[a-z]+\d{3,}$'), // usernames ending with 3+ numbers
                                  RegExp(
                                      r'^[a-z]{1,2}\d{2,}$'), // short usernames with numbers
                                  RegExp(
                                      r'^(no|not|fake|invalid|nonexistent|random|temp|temporal)',
                                      caseSensitive: false),
                                  RegExp(
                                      r'^.{1,3}\d{2,}$'), // very short usernames with numbers
                                  RegExp(
                                      r'^[a-z]{20,}$'), // unusually long usernames
                                  RegExp(r'^(test|demo|sample)\d*@',
                                      caseSensitive: false),
                                ];

                                if (suspiciousUsernamePatterns.any(
                                    (pattern) => pattern.hasMatch(username))) {
                                  return 'This email address appears to be invalid or non-existent';
                                }

                                // Check for obviously fake combinations
                                final fakeCombinations = [
                                  RegExp(
                                      r'^(test|fake|dummy|sample|example|demo)@(gmail|yahoo|outlook|hotmail)\.com$',
                                      caseSensitive: false),
                                  RegExp(
                                      r'^(user|admin|support|info|contact)@(gmail|yahoo|outlook|hotmail)\.com$',
                                      caseSensitive: false),
                                  RegExp(
                                      r'^[a-z]{1,3}\d{2,}@(gmail|yahoo|outlook|hotmail)\.com$',
                                      caseSensitive: false),
                                ];

                                if (fakeCombinations.any(
                                    (pattern) => pattern.hasMatch(email))) {
                                  return 'This email address appears to be invalid or non-existent';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Company Field
                            TextFormField(
                              controller: _companyController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Company',
                                labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFC10D00), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your company';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Role Selection
                            _buildRoleSelection(),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFC10D00), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)')
                                    .hasMatch(value)) {
                                  return 'Password must contain uppercase, lowercase, and number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password Field
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordVisible =
                                          !_isConfirmPasswordVisible;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFC10D00), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Terms and Conditions
                            Row(
                              children: [
                                Checkbox(
                                  value: _acceptTerms,
                                  fillColor:
                                      WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return const Color(0xFFC10D00);
                                    }
                                    return Colors.white.withValues(alpha: 0.1);
                                  }),
                                  checkColor: Colors.white,
                                  onChanged: (value) {
                                    setState(() {
                                      _acceptTerms = value ?? false;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    'I agree to the Terms of Service and Privacy Policy',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Create Account Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC10D00),
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'CREATE ACCOUNT',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Sign In Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7)),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/login'),
                                  child: const Text(
                                    'SIGN IN',
                                    style: TextStyle(
                                      color: Color(0xFFC10D00),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ), // Added closing bracket for SafeArea
          ), // Missing closing for SafeArea
          // Fixed footer version display at bottom
          const FixedFooterVersionDisplay(),
        ], // Stack children
      ), // Stack
    ); // Scaffold
  }

  
  Widget _buildRoleSelection() {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: _selectedRole,
      decoration: InputDecoration(
        labelText: 'Select Your Role',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC10D00), width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
      ),
      dropdownColor: const Color(0xFF8B0000),
      style: const TextStyle(color: Colors.white),
      icon: Icon(
        Icons.arrow_drop_down,
        color: Colors.white.withValues(alpha: 0.7),
      ),
      items: _roles.map((role) {
        return DropdownMenuItem<String>(
          value: role['name'].toString(),
          child: Text(
            role['name'].toString(),
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedRole = value;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a role';
        }
        return null;
      },
    );
  }

  String _friendlyRegisterMessage(String? raw) {
    final msg = (raw ?? '').toLowerCase();
    if (msg.contains('email') && (msg.contains('exist') || msg.contains('taken'))) {
      return 'Email already exists. Please use a different email address.';
    }
    if (msg.contains('invalid') || msg.contains('credential')) {
      return 'Please check your details and try again.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Registration is taking too long. Please try again shortly.';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'We could not connect. Please check your internet and try again.';
    }
    return 'Registration failed. Please try again.';
  }

  Future<void> _handleRegister() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final company = _companyController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _registerErrorMessage = 'Please enter both first and last name.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _registerErrorMessage = 'Please enter your email.');
      return;
    }
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email)) {
      setState(() => _registerErrorMessage = 'Please enter a valid email address.');
      return;
    }
    if (company.isEmpty) {
      setState(() => _registerErrorMessage = 'Please enter your company.');
      return;
    }
    if (password.length < 8) {
      setState(() => _registerErrorMessage = 'Password must be at least 8 characters.');
      return;
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
      setState(() => _registerErrorMessage = 'Password must include uppercase, lowercase, and a number.');
      return;
    }
    if (confirmPassword != password) {
      setState(() => _registerErrorMessage = 'Passwords do not match.');
      return;
    }
    if (!_acceptTerms) {
      setState(() => _registerErrorMessage = 'Please accept the Terms of Service and Privacy Policy.');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      setState(() => _registerErrorMessage = 'Please check your details and try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _registerErrorMessage = null;
    });

    try {
      UserRole userRole;
      switch (_selectedRole.toLowerCase()) {
        case 'project manager':
          userRole = UserRole.deliveryLead;
          break;
        case 'scrum master':
        case 'qa engineer':
        case 'developer':
          userRole = UserRole.teamMember;
          break;
        case 'client':
          userRole = UserRole.clientReviewer;
          break;
        case 'stakeholder':
          userRole = UserRole.systemAdmin;
          break;
        default:
          userRole = UserRole.teamMember;
      }

      final authService = AuthService();
      final result = await authService.signUp(
        email,
        password,
        '$firstName $lastName',
        userRole,
      );

      if (!mounted) return;
      if (result['success'] == true) {
        context.go('/login');
      } else {
        setState(() {
          _registerErrorMessage = _friendlyRegisterMessage(
            result['error']?.toString() ?? result['message']?.toString(),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _registerErrorMessage = _friendlyRegisterMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? const Color(0xFF1F1F26).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.94);
    final fieldFill = isDark ? const Color(0xFF3D3F40) : const Color(0xFFECECEF);
    final fieldText = isDark ? const Color(0xFFA8ABB2) : const Color(0xFF2C2C2C);
    final hintColor = isDark ? const Color(0xFFA8ABB2) : const Color(0xFF6B6B6B);
    final titleColor = isDark ? const Color(0xFFF2F4F8) : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? const Color(0xFFD0D4DB) : const Color(0xFF5C5C5C);
    final panelBorder = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08);
    final panelShadowOpacity = isDark ? 0.45 : 0.12;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/Icons/khono_bg.png'),
                  fit: BoxFit.cover,
                  alignment: Alignment(0.12, 0.0),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: _logoWidth,
                        height: _logoHeight,
                        child: Image.asset(
                          'assets/Icons/khono.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: _panelWidth,
                        decoration: BoxDecoration(
                          color: panelColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: panelBorder, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: panelShadowOpacity),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(17, 19, 17, 18),
                              child: Column(
                                children: [
                                  Text(
                                    'Create Your Account',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: titleColor,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Register to access the Deliverable & Sprint Sign-Off Hub.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: subtitleColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInput(
                                          controller: _firstNameController,
                                          hint: 'First Name',
                                          fillColor: fieldFill,
                                          textColor: fieldText,
                                          hintColor: hintColor,
                                          validator: (value) =>
                                              (value == null || value.trim().isEmpty) ? 'Required' : null,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildInput(
                                          controller: _lastNameController,
                                          hint: 'Last Name',
                                          fillColor: fieldFill,
                                          textColor: fieldText,
                                          hintColor: hintColor,
                                          validator: (value) =>
                                              (value == null || value.trim().isEmpty) ? 'Required' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _buildInput(
                                    controller: _emailController,
                                    hint: 'Email',
                                    fillColor: fieldFill,
                                    textColor: fieldText,
                                    hintColor: hintColor,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) return 'Please enter your email';
                                      if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
                                          .hasMatch(value.trim())) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  _buildInput(
                                    controller: _companyController,
                                    hint: 'Company',
                                    fillColor: fieldFill,
                                    textColor: fieldText,
                                    hintColor: hintColor,
                                    validator: (value) =>
                                        (value == null || value.trim().isEmpty) ? 'Please enter your company' : null,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildRoleDropdown(fieldFill, fieldText, hintColor),
                                  const SizedBox(height: 10),
                                  _buildInput(
                                    controller: _passwordController,
                                    hint: 'Password',
                                    fillColor: fieldFill,
                                    textColor: fieldText,
                                    hintColor: hintColor,
                                    obscure: !_isPasswordVisible,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter a password';
                                      if (value.length < 8) return 'Min 8 characters';
                                      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                                        return 'Use upper, lower and number';
                                      }
                                      return null;
                                    },
                                    suffix: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                                        size: 16,
                                      ),
                                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildInput(
                                    controller: _confirmPasswordController,
                                    hint: 'Confirm Password',
                                    fillColor: fieldFill,
                                    textColor: fieldText,
                                    hintColor: hintColor,
                                    obscure: !_isConfirmPasswordVisible,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please confirm password';
                                      if (value != _passwordController.text) return 'Passwords do not match';
                                      return null;
                                    },
                                    suffix: IconButton(
                                      icon: Icon(
                                        _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                                        size: 16,
                                      ),
                                      onPressed: () => setState(
                                        () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Checkbox(
                                        value: _acceptTerms,
                                        onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                                        activeColor: const Color(0xFFC10D00),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'I agree to the Terms of Service and Privacy Policy',
                                          style: GoogleFonts.poppins(
                                            color: subtitleColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: _fieldWidth,
                                    height: _buttonHeight,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFC10D00),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20.54),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : Text(
                                              'CREATE ACCOUNT',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: GoogleFonts.poppins(
                                          color: isDark ? Colors.white70 : const Color(0xFF5C5C5C),
                                          fontSize: 11,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => context.go('/login'),
                                        child: Text(
                                          'Login',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFFC10D00),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (_registerErrorMessage != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFC10D00),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  _registerErrorMessage!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const FixedFooterVersionDisplay(),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required Color fillColor,
    required Color textColor,
    required Color hintColor,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return SizedBox(
      height: _inputHeight,
      child: TextFormField(
        controller: controller,
        obscureText: obscure == true,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: hintColor,
            fontSize: 8.5,
            fontWeight: FontWeight.w500,
          ),
          suffixIcon: suffix,
          errorStyle: const TextStyle(height: 0, fontSize: 0),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(Color fillColor, Color textColor, Color hintColor) {
    return SizedBox(
      width: _fieldWidth,
      height: _inputHeight,
      child: DropdownButtonFormField<String>(
        value: _selectedRole,
        validator: (value) => (value == null || value.isEmpty) ? 'Please select a role' : null,
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        dropdownColor: const Color(0xFF2B2B2F),
        icon: Icon(Icons.arrow_drop_down, color: textColor),
        decoration: InputDecoration(
          hintText: 'Select Role',
          hintStyle: GoogleFonts.poppins(
            color: hintColor,
            fontSize: 8.5,
            fontWeight: FontWeight.w500,
          ),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        items: _roles
            .map(
              (role) => DropdownMenuItem<String>(
                value: role,
                child: Text(role),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedRole = value);
          }
        },
      ),
    );
  }
}
