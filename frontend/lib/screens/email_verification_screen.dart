import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/simple_auth_provider.dart';
import '../theme/flownet_theme.dart';
import '../services/error_handler.dart';
import '../services/auth_service.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String? verificationCode;
  
const EmailVerificationScreen({super.key, required this.email, this.verificationCode});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  int _resendCountdown = 0;
  String? _verificationCode;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    _loadVerificationCode();
    if (widget.verificationCode != null && widget.verificationCode!.isNotEmpty) {
      _verificationCode = widget.verificationCode;
      _verifyEmail();
    }
  }

  void _loadVerificationCode() {
    // For testing purposes, get the verification code
    // Verification code handling moved to AuthService
    // final code = _authService.getVerificationCode(widget.email);
    // if (code != null) {
    //   debugPrint('📧 Verification code for ${widget.email}: $code');
    // }
  }

  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 60; // 60 seconds countdown
    });
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendCountdown--;
        });
        return _resendCountdown > 0;
      }
      return false;
    });
  }

  Future<void> _verifyEmail() async {
    if (_verificationCode == null || _verificationCode!.isEmpty) {
      ErrorHandler().showErrorSnackBar(context, 'Please enter the verification code');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      // Use AuthService for proper email verification
      final authService = AuthService();

      // Prefer the email passed via route; if it's empty, fall back to the
      // currently authenticated user's email so the backend always receives
      // a non-empty email value.
      final routeEmail = widget.email.trim();
      final effectiveEmail = routeEmail.isNotEmpty
          ? routeEmail
          : (authService.currentUser?.email ?? '');

      if (effectiveEmail.isEmpty) {
        ErrorHandler().showErrorSnackBar(
          context,
          'Email is missing. Please log in again or restart the verification flow.',
        );
        return;
      }

      final response = await authService.verifyEmail(effectiveEmail, _verificationCode!);
      final success = response.isSuccess;
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully!'),
              backgroundColor: FlownetColors.electricBlue,
            ),
          );
          
          context.go('/login');
        }
      } else {
        if (mounted) {
          ErrorHandler().showErrorSnackBar(
            context,
            response.error ?? 'Verification failed. Please check your code and try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler().showErrorSnackBar(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: FlownetColors.pureWhite,
                    ),
                  ),
                  const Text(
                    'Email Verification',
                    style: TextStyle(
                      color: FlownetColors.pureWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Verification Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: FlownetColors.electricBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: FlownetColors.electricBlue,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    size: 64,
                    color: FlownetColors.electricBlue,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title and Description
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  color: FlownetColors.pureWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              const Text(
                'We\'ve sent a verification code to:',
                style: TextStyle(
                  color: FlownetColors.coolGray,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Center(
                child: Text(
                  widget.email,
                  style: const TextStyle(
                    color: FlownetColors.electricBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Verification Code Input
              TextFormField(
                onChanged: (value) {
                  setState(() {
                    _verificationCode = value;
                  });
                },
                style: const TextStyle(
                  color: FlownetColors.pureWhite,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Enter verification code',
                  hintStyle: const TextStyle(
                    color: FlownetColors.coolGray,
                    letterSpacing: 0,
                  ),
                  filled: true,
                  fillColor: FlownetColors.slate,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: FlownetColors.slate),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: FlownetColors.electricBlue,
                      width: 2,
                    ),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 24),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlownetColors.electricBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: FlownetColors.pureWhite,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify Email',
                          style: TextStyle(
                            color: FlownetColors.pureWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend Section
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Didn\'t receive the email?',
                      style: TextStyle(
                        color: FlownetColors.coolGray,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    if (_resendCountdown > 0)
                      Text(
                        'Resend available in ${_resendCountdown}s',
                        style: const TextStyle(
                          color: FlownetColors.amberOrange,
                          fontSize: 14,
                        ),
                      )
                    else
                      TextButton(
                        onPressed: authState.isLoading ? null : _resendVerification,
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: FlownetColors.electricBlue,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Resend Verification Email',
                                style: TextStyle(
                                  color: FlownetColors.electricBlue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Help Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FlownetColors.slate.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FlownetColors.slate),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Help?',
                      style: TextStyle(
                        color: FlownetColors.pureWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Check your spam/junk folder\n'
                      '• Make sure the email address is correct\n'
                      '• Contact support if you continue having issues',
                      style: TextStyle(
                        color: FlownetColors.coolGray,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Sign Out Link
              Center(
                child: TextButton(
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    await ref.read(authStateProvider.notifier).signOut();
                    if (mounted) {
                      router.go('/');
                    }
                  },
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: FlownetColors.coolGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resendVerification() async {
    try {
      final authService = AuthService();
      final response = await authService.resendVerificationEmail(widget.email);
      
      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email sent! Please check your inbox.'),
              backgroundColor: FlownetColors.electricBlue,
            ),
          );
          _startResendCountdown();
        } else {
          ErrorHandler().showErrorSnackBar(
            context,
            response.error ?? 'Failed to resend verification email. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler().showErrorSnackBar(context, 'Error: $e');
      }
    }
  }
}