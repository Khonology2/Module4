import 'package:flutter/material.dart';

class StyledDropdown<T> extends StatelessWidget {
  final String? label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;

  const StyledDropdown({
    super.key,
    this.label,
    required this.value,
    required this.items,
    this.onChanged,
    this.validator,
    this.borderRadius = 12.0,
    this.contentPadding,
    this.fillColor,
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
          padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            validator: validator,
            dropdownColor: Colors.black.withAlpha((0.8 * 255).round()),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            iconEnabledColor: Colors.white.withAlpha((0.7 * 255).round()),
          ),
        ),
      ],
    );
  }
}
