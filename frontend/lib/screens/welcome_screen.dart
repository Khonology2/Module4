import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/fixed_footer_version_display.dart';
import '../services/auth_service.dart';
import '../services/backend_api_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const bool showManualSsoTokenField = false;

  final TextEditingController _tokenController = TextEditingController();
  bool _isSsoLoading = false;
  String? _errorMessage;
  String? _pendingSsoToken;
  String? _pendingAccessToken;
  String? _pendingRefreshToken;
  String _pendingDashboard = '/dashboard';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeTokenFromUrl());
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _consumeTokenFromUrl() async {
    final appAccessToken = Uri.base.queryParameters['access_token'];
    if (appAccessToken != null && appAccessToken.trim().isNotEmpty) {
      setState(() {
        _pendingAccessToken = appAccessToken.trim();
        _pendingRefreshToken = (Uri.base.queryParameters['refresh_token'] ?? '').trim();
        _pendingDashboard = Uri.base.queryParameters['dashboard'] ?? '/dashboard';
      });
      return;
    }

    final token = Uri.base.queryParameters['token'] ?? Uri.base.queryParameters['ssoToken'];
    if (token != null && token.trim().isNotEmpty) {
      setState(() {
        _pendingSsoToken = token.trim();
        _tokenController.text = token.trim();
      });
    }
  }

  Future<void> _onGetStartedPressed() async {
    if (_isSsoLoading) return;

    if (_pendingAccessToken != null && _pendingAccessToken!.isNotEmpty) {
      setState(() {
        _isSsoLoading = true;
        _errorMessage = null;
      });
      await BackendApiService().saveTokens(
        _pendingAccessToken!,
        _pendingRefreshToken ?? '',
        DateTime.now().add(const Duration(minutes: 15)),
      );
      await AuthService().refreshCurrentUser();
      if (!mounted) return;
      context.go(_pendingDashboard);
      return;
    }

    final tokenFromField = _tokenController.text.trim();
    final token = _pendingSsoToken ?? tokenFromField;
    if (token.isNotEmpty) {
      await _handleSsoLogin(token);
      return;
    }

    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _handleSsoLogin(String token) async {
    if (_isSsoLoading) return;
    setState(() {
      _isSsoLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService().loginWithSsoToken(token);
    if (!mounted) return;

    if (result['success'] == true) {
      final dashboard = result['dashboard']?.toString() ?? '/dashboard';
      context.go(dashboard);
      return;
    }

    setState(() {
      _errorMessage = result['error']?.toString() ?? 'SSO login failed';
      _isSsoLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                    Colors.black.withValues(alpha: 0.28),
                    const Color(0xFF090909).withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://raw.githubusercontent.com/Khonology2/Module4/Busisiwe/frontend/assets/khono_logo.png',
                          width: 360,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              'K H O N O L O G Y',
                              style: textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFFE2173F),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 9,
                              ),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Deliverable & Sprint Sign-Off Hub',
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bring clarity, control, and confident sign-off to every milestone.',
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),
                        if (showManualSsoTokenField) ...[
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: TextField(
                              controller: _tokenController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Paste SSO token',
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.45),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2173F)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 220,
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isSsoLoading
                                  ? null
                                  : () => _handleSsoLogin(_tokenController.text.trim()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE2173F),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                elevation: 0,
                              ),
                              child: Text(
                                _isSsoLoading ? 'LOGGING IN...' : 'LOGIN WITH TOKEN',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            SizedBox(
                              width: 180,
                              height: 42,
                              child: ElevatedButton(
                                onPressed: _isSsoLoading ? null : _onGetStartedPressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC10D00),
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'GET STARTED',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              height: 42,
                              child: OutlinedButton(
                                onPressed: () => context.go('/register'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    width: 1.4,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text(
                                  'LEARN MORE',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 64),
                        Image.network(
                          'https://raw.githubusercontent.com/Khonology2/Module4/Busisiwe/frontend/assets/white_discs.png',
                          width: 120,
                          height: 44,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 34,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Fixed footer version display at bottom
          const FixedFooterVersionDisplay(),
        ],
      ),
    );
  }

}
