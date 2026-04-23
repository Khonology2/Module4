import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/fixed_footer_version_display.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/Icons/khono_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 140),

                  // Logo / Title
                  Text(
                    'DELIVERABLES & SPRINTS SIGN OFF HUB',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Red subtitle
                  Text(
                    'Your Growth Journey, Simplified',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFC10D00),
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Tagline / description
                  Text(
                    'Build strong habits, build a strong future.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color.fromRGBO(255, 255, 255, 0.85),
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Primary and secondary actions
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: SizedBox(
                          width: 260,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => context.go('/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC10D00),
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              elevation: 0,
                            ),
                            child: const Text(
                              'GET STARTED',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: SizedBox(
                          width: 260,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => context.go('/register'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text(
                              'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ],
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
