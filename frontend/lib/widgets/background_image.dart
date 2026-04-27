import 'dart:ui';

import 'package:flutter/material.dart';

class BackgroundImage extends StatelessWidget {
  final Widget child;
  final String? imagePath;
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
    this.imagePath,
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String resolvedImagePath =
        imagePath ??
        (isDarkMode
            ? 'https://raw.githubusercontent.com/Khonology2/Module4/Busisiwe/frontend/assets/Icons/khono_bg.png'
            : 'https://raw.githubusercontent.com/Khonology2/Module4/Busisiwe/frontend/assets/niice_wrld_white_bg.png');
    final List<Color> resolvedGradientColors =
        gradientColors ??
        (isDarkMode
            ? [
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.35),
              ]
            : [
                Colors.transparent,
                Colors.transparent,
              ]);

    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.network(
            resolvedImagePath,
            fit: fit,
            // Render background sharply
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDarkMode 
                        ? [Colors.black, Colors.black.withValues(alpha: 0.8)]
                        : [Colors.grey.shade100, Colors.grey.shade200],
                  ),
                ),
              );
            },
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
                  colors: resolvedGradientColors,
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
