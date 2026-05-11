import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/backend_settings_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/app_modal.dart';
import '../widgets/fixed_footer_version_display.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const double _logoWidth = 360;
  static const double _logoHeight = 78;
  static const double _panelWidth = 360;
  static const double _fieldWidth = 310;
  static const double _titleBlockHeight = 52;
  static const double _subtitleBlockHeight = 44;
  static const double _inputHeight = 38;
  static const double _buttonHeight = 38;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _keyboardFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _loginErrorMessage;

  String _friendlyLoginMessage(String? raw) {
    final msg = (raw ?? '').toLowerCase();
    if (msg.contains('credential') ||
        msg.contains('invalid') ||
        msg.contains('incorrect') ||
        msg.contains('password') ||
        msg.contains('email')) {
      return 'Email or password is incorrect. Please try again.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Login is taking too long. Please try again in a moment.';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'We could not connect. Please check your internet and try again.';
    }
    return 'Something is wrong. Please try again.';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() {
        _loginErrorMessage = 'Please enter your email.';
      });
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _loginErrorMessage = 'Please enter a valid email address.';
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _loginErrorMessage = 'Please enter your password.';
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _loginErrorMessage = 'Password must be at least 6 characters.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _loginErrorMessage = 'Please check your details and try again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loginErrorMessage = null;
    });

    try {
      final authService = AuthService();
      final success = await authService.signIn(
        email,
        password,
      );

      if (success && mounted) {
        final user = authService.currentUser;
        if (user != null) {
          await BackendSettingsService.saveUserId(user.id);
        }
        setState(() => _loginErrorMessage = null);
        if (mounted) {
          context.go('/dashboard');
        }
      } else if (mounted) {
        setState(() {
          _loginErrorMessage = _friendlyLoginMessage(authService.lastAuthError);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loginErrorMessage = _friendlyLoginMessage(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
<<<<<<< HEAD
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
=======
>>>>>>> d298aafc654f6952b2ec2426386821c30aaddb83
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
                child: KeyboardListener(
                  focusNode: _keyboardFocusNode,
                  onKeyEvent: (KeyEvent event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !_isLoading) {
                      _handleLogin();
                    }
                  },
                  child: Form(
                    key: _formKey,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.network(
                            'https://raw.githubusercontent.com/Khonology2/Module4/Busisiwe/frontend/assets/Icons/khono.png',
                            height: 80,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.shield_outlined,
                                size: 56,
                                color: Colors.white70,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome Back',
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
                            'Sign in to manage your projects',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                          const SizedBox(height: 32),

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
                                    color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3)),
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
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (value) {
                              // This will be called when user presses "Done" on keyboard
                              if (!_isLoading) {
                                _handleLogin();
                              }
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3)),
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
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                _showForgotPasswordDialog();
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(color: Color(0xFFC10D00)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Sign In Button
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
                                      SizedBox(
                                        width: _fieldWidth,
                                        height: _titleBlockHeight,
                                        child: Center(
                                          child: Text(
                                            'Deliverable & Sprint Sign-Off Hub',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              color: titleColor,
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w600,
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: _fieldWidth,
                                        height: _subtitleBlockHeight,
                                        child: Text(
                                          'Enter your user details to sign in as directed below.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            color: subtitleColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _buildInput(
                                        controller: _emailController,
                                        hint: 'Email',
                                        action: TextInputAction.next,
                                        fillColor: fieldFill,
                                        textColor: fieldText,
                                        hintColor: hintColor,
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                              .hasMatch(value)) {
                                            return 'Please enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      _buildInput(
                                        controller: _passwordController,
                                        hint: 'Password',
                                        action: TextInputAction.done,
                                        obscure: _obscurePassword,
                                        fillColor: fieldFill,
                                        textColor: fieldText,
                                        hintColor: hintColor,
                                        onSubmitted: (_) {
                                          if (!_isLoading) {
                                            _handleLogin();
                                          }
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          if (value.length < 6) {
                                            return 'Password must be at least 6 characters';
                                          }
                                          return null;
                                        },
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.grey.shade600,
                                            size: 16,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: _fieldWidth,
                                        height: _buttonHeight,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _handleLogin,
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
                                                    valueColor:
                                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : Text(
                                                  'LOGIN',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _socialCircle(
                                            icon: Image.asset(
                                              'assets/Icons/Google_Icon.png',
                                              width: 16,
                                              height: 16,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                Icons.g_mobiledata_rounded,
                                                size: 18,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            onTap: null,
                                          ),
                                          const SizedBox(width: 10),
                                          _socialCircle(
                                            icon: const Icon(
                                              Icons.window_rounded,
                                              size: 16,
                                              color: Colors.black87,
                                            ),
                                            onTap: null,
                                          ),
                                          const SizedBox(width: 10),
                                          _socialCircle(
                                            icon: Image.asset(
                                              'assets/Icons/github_icon_2.png',
                                              width: 16,
                                              height: 16,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                Icons.code_rounded,
                                                size: 15,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            onTap: null,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 34),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: 32,
                                              child: ElevatedButton(
                                                onPressed: () => Navigator.of(context).maybePop(),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isDark
                                                      ? Colors.white54
                                                      : Colors.grey.shade300,
                                                  foregroundColor: Colors.black87,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                child: Text(
                                                  'BACK',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: SizedBox(
                                              height: 32,
                                              child: OutlinedButton(
                                                onPressed: _showForgotPasswordDialog,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1A1A1A),
                                                  side: BorderSide(
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black45,
                                                    width: 1.1,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                child: Text(
                                                  'FORGOT PASSWORD',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10.2,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Don't have an account? ",
                                            style: GoogleFonts.poppins(
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF5C5C5C),
                                              fontSize: 11,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => context.go('/register'),
                                            child: Text(
                                              'Register',
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
                                if (_loginErrorMessage != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFC10D00),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      _loginErrorMessage!,
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
            ),
          const FixedFooterVersionDisplay(),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required TextInputAction action,
    required Color fillColor,
    required Color textColor,
    required Color hintColor,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return SizedBox(
      width: _fieldWidth,
      height: _inputHeight,
      child: TextFormField(
        controller: controller,
        obscureText: obscure == true,
        autocorrect: obscure ? false : true,
        enableSuggestions: obscure ? false : true,
        textInputAction: action,
        keyboardType: keyboardType,
        onFieldSubmitted: onSubmitted,
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

  Widget _socialCircle({required Widget icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 31,
        height: 31,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.charcoalBlack,
        title: const Text(
          'Reset Password',
          style: TextStyle(color: FlownetColors.pureWhite),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(color: FlownetColors.coolGray),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              style: const TextStyle(color: FlownetColors.pureWhite),
              decoration: const InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: FlownetColors.coolGray),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: FlownetColors.slate),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: FlownetColors.electricBlue),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FlownetColors.coolGray),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty) {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                try {
                  final authService = AuthService();
                  await authService.forgotPassword(emailController.text);

                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Password reset email sent!'),
                        backgroundColor: FlownetColors.electricBlue,
                      ),
                    );
                    navigator.pop();
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: FlownetColors.crimsonRed,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FlownetColors.electricBlue,
            ),
            child: const Text(
              'Send Reset Link',
              style: TextStyle(color: FlownetColors.pureWhite),
            ),
          ),
        ],
      ),
    );
  }
}
