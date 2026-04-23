import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double height;
  final double borderRadius;
  final double elevation;
  final EdgeInsetsGeometry? padding;
  final Widget? icon;
  final Color? color;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool fullWidth;
  final bool hasBorder;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? customShadow;
  final Gradient? gradient;

  const GlassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.height = 50.0,
    this.borderRadius = 12.0,
    this.elevation = 0.0,
    this.padding,
    this.icon,
    this.color,
    this.textColor,
    this.fontSize,
    this.fontWeight = FontWeight.w600,
    this.fullWidth = false,
    this.hasBorder = false,
    this.borderColor,
    this.borderWidth = 1.0,
    this.customShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.primaryColor.withAlpha(51);  // 0.2 * 255 ≈ 51
    final buttonTextColor = textColor ?? theme.colorScheme.onPrimary;
    
    return Container(
      width: fullWidth ? double.infinity : width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient ?? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            buttonColor.withAlpha(204),  // 0.8 * 255 ≈ 204
            buttonColor.withAlpha(153),  // 0.6 * 255 ≈ 153
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: hasBorder
            ? Border.all(
                color: borderColor ?? Colors.white.withAlpha(51),  // 0.2 * 255 ≈ 51
                width: borderWidth,
              )
            : null,
        boxShadow: customShadow ?? [
          if (elevation > 0)
            BoxShadow(
              color: Colors.black.withAlpha(26),  // 0.1 * 255 ≈ 26
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: isDisabled || isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24.0),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          buttonTextColor,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          icon!,
                          const SizedBox(width: 8),
                        ],
                        Text(
                          text,
                          style: TextStyle(
                            color: isDisabled
                                ? buttonTextColor.withAlpha(179)  // 0.7 * 255 ≈ 179
                                : buttonTextColor,
                            fontSize: fontSize ?? 16.0,
                            fontWeight: fontWeight,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// Extension for easy button creation
extension GlassButtonExtension on BuildContext {
  GlassButton glassButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isDisabled = false,
    double? width,
    double height = 50.0,
    double borderRadius = 12.0,
    double elevation = 0.0,
    EdgeInsetsGeometry? padding,
    Widget? icon,
    Color? color,
    Color? textColor,
    double? fontSize,
    FontWeight? fontWeight,
    bool fullWidth = false,
    bool hasBorder = false,
    Color? borderColor,
    double borderWidth = 1.0,
    List<BoxShadow>? customShadow,
    Gradient? gradient,
  }) {
    return GlassButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isDisabled: isDisabled,
      width: width,
      height: height,
      borderRadius: borderRadius,
      elevation: elevation,
      padding: padding,
      icon: icon,
      color: color,
      textColor: textColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fullWidth: fullWidth,
      hasBorder: hasBorder,
      borderColor: borderColor,
      borderWidth: borderWidth,
      customShadow: customShadow,
      gradient: gradient,
    );
  }
}
