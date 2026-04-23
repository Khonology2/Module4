import 'dart:ui';

import 'package:flutter/material.dart';

class BackgroundImage extends StatelessWidget {
  final Widget child;
  final String imagePath;
  final BoxFit fit;
  final bool withGlassEffect;
  final double overlayOpacity;  // Should be between 0.0 and 1.0
  final bool withGradient;
  final AlignmentGeometry gradientBegin;
  final AlignmentGeometry gradientEnd;
  final List<Color>? gradientColors;
  final double blurRadius;
  final Widget? overlayChild;

  const BackgroundImage({
    super.key,
    required this.child,
    this.imagePath = 'assets/Icons/khono_bg.png',
    this.fit = BoxFit.cover,
    this.withGlassEffect = false,
    this.overlayOpacity = 0.06,
    this.withGradient = true,
    this.gradientBegin = Alignment.topCenter,
    this.gradientEnd = Alignment.bottomCenter,
    this.gradientColors,
    this.blurRadius = 3.0,
    this.overlayChild,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            imagePath,
            fit: fit,
            // Render background sharply
            filterQuality: FilterQuality.high,
          ),
        ),
        
        // Gradient overlay
        if (withGradient)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: gradientBegin,
                  end: gradientEnd,
                  colors: gradientColors ?? [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
        
        // Glass effect overlay
        if (withGlassEffect)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: overlayOpacity),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurRadius,
                  sigmaY: blurRadius,
                ),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        
        // Main content
        if (overlayChild != null)
          overlayChild!,
        
        // Child content
        child,
      ],
    );
  }
}
