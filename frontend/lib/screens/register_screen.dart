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
