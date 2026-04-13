import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Frosted glass panel for dashboard cards — subtle blur, light border, readable text.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  /// Backdrop blur strength (sigma); kept modest for clarity and performance.
  final double blur;
  final Color? color;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 12.0,
    this.blur = 10.0,
    this.color,
    this.border,
    this.boxShadow,
    this.padding,
    this.gradient,
  });

  static final LinearGradient _defaultFrost = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withAlpha(18),
      Colors.white.withAlpha(6),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final sigma = (blur * 0.72).clamp(4.0, 12.0);
    final Gradient? effectiveGradient;
    final Color? effectiveColor;
    if (gradient != null) {
      effectiveGradient = gradient;
      effectiveColor = null;
    } else if (color != null) {
      effectiveGradient = null;
      effectiveColor = color;
    } else {
      effectiveGradient = _defaultFrost;
      effectiveColor = null;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: effectiveColor,
            gradient: effectiveGradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(
                  color: Colors.white.withAlpha(42),
                  width: 1.0,
                ),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withAlpha(36),
                    blurRadius: blur,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }
}
