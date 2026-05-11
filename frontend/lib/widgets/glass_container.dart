import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Apple-style liquid glass (glassmorphism) container widget
/// Provides semi-transparent background, backdrop blur, subtle borders, and soft shadows
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final double opacity;
  final double blurSigmaX;
  final double blurSigmaY;
  final Color? borderColor;
  final double borderWidth;
  final List<Color>? gradientColors;
  final AlignmentGeometry gradientBegin;
  final AlignmentGeometry gradientEnd;
  final BoxShadow? shadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 24.0,
    this.opacity = 0.05,
    this.blurSigmaX = 12.0,
    this.blurSigmaY = 12.0,
    this.borderColor,
    this.borderWidth = 1.0,
    this.gradientColors,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
    this.shadow,
    this.padding,
    this.margin,
    this.onTap,
  });

  /// Standard glass container with default Apple-style settings
  factory GlassContainer.standard({
    required Widget child,
    double? width,
    double? height,
    double? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
  }) {
    return GlassContainer(
      width: width,
      height: height,
      borderRadius: borderRadius ?? 24.0,
      opacity: 0.05,
      blurSigmaX: 12.0,
      blurSigmaY: 12.0,
      borderWidth: 0.8,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }

  /// Light glass container (more transparent)
  factory GlassContainer.light({
    required Widget child,
    double? width,
    double? height,
    double? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
  }) {
    return GlassContainer(
      width: width,
      height: height,
      borderRadius: borderRadius ?? 24.0,
      opacity: 0.03,
      blurSigmaX: 8.0,
      blurSigmaY: 8.0,
      borderWidth: 0.6,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }

  /// Heavy glass container (less transparent, more visible)
  factory GlassContainer.heavy({
    required Widget child,
    double? width,
    double? height,
    double? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
  }) {
    return GlassContainer(
      width: width,
      height: height,
      borderRadius: borderRadius ?? 24.0,
      opacity: 0.08,
      blurSigmaX: 14.0,
      blurSigmaY: 14.0,
      borderWidth: 1.0,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? 
        Colors.white.withAlpha(24);
    
    final effectiveGradientColors = gradientColors ?? [
      Colors.white.withAlpha(12),
      Colors.white.withAlpha(6),
    ];

    final effectiveShadow = shadow ?? BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 14,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    );

    final Widget container = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        boxShadow: [effectiveShadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: blurSigmaX,
            sigmaY: blurSigmaY,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: gradientBegin,
                end: gradientEnd,
                colors: effectiveGradientColors,
              ),
              color: Colors.white.withValues(alpha: opacity),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: container,
      );
    }

    return container;
  }
}

/// Glass button with hover effects
class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double borderRadius;
  final double opacity;
  final double blurSigmaX;
  final double blurSigmaY;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.borderRadius = 24.0,
    this.opacity = 0.15,
    this.blurSigmaX = 25.0,
    this.blurSigmaY = 25.0,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool isHovered) {
    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: GlassContainer(
                borderRadius: widget.borderRadius,
                opacity: widget.opacity,
                blurSigmaX: widget.blurSigmaX,
                blurSigmaY: widget.blurSigmaY,
                borderColor: widget.borderColor,
                borderWidth: widget.borderWidth,
                padding: widget.padding,
                margin: widget.margin,
                onTap: widget.onPressed,
                child: widget.child,
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

