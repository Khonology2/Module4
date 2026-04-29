import 'package:flutter/material.dart';

class AppContainer extends StatelessWidget {
  final Widget child;
  final bool showBackground;

  const AppContainer({
    super.key,
    required this.child,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBackground) {
      return child;
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient fallback
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                  Color(0xFF533483),
                ],
              ),
            ),
          ),
          // Background image overlay
          if (showBackground)
            Positioned.fill(
              child: Opacity(
                opacity: 0.3,
                child: Image.network(
                  'https://raw.githubusercontent.com/Khonology2/Module4/Busisiwe/frontend/assets/Icons/khono_bg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback gradient pattern if image fails to load
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.0,
                          colors: [
                            Colors.white.withAlpha(10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          // Content
          child,
        ],
      ),
    );
  }
}
