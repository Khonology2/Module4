import 'package:flutter/material.dart';

class StyledInput extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final void Function(String)? onChanged;
  final bool enabled;
  final String? initialValue;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final FocusNode? focusNode;
  final bool readOnly;
  final void Function()? onTap;
  final Color? fillColor;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final TextCapitalization textCapitalization;

  const StyledInput({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.enabled = true,
    this.initialValue,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
    this.readOnly = false,
    this.onTap,
    this.fillColor,
    this.borderRadius = 12.0,
    this.contentPadding,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: fillColor ?? Colors.white.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              width: 1.0,
            ),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            onChanged: onChanged,
            initialValue: initialValue,
            maxLines: maxLines,
            minLines: minLines,
            autofocus: autofocus,
            textInputAction: textInputAction,
            onFieldSubmitted: onFieldSubmitted,
            focusNode: focusNode,
            readOnly: readOnly,
            onTap: onTap,
            textCapitalization: textCapitalization,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Colors.white.withAlpha((0.5 * 255).round()),
                fontSize: 16,
              ),
              contentPadding: contentPadding ??
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
              border: InputBorder.none,
              suffixIcon: suffixIcon,
              prefixIcon: prefixIcon,
              filled: false,
              errorStyle: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.0,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.5,
                ),
              ),
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: const BorderSide(
                  color: Colors.blueAccent,
                  width: 1.5,
                ),
              ),
              disabledBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
