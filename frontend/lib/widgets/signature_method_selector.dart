import 'package:flutter/material.dart';
import '../theme/flownet_theme.dart';

/// Signature method types
enum SignatureMethod {
  manual,
  docusign;

  String get displayName {
    switch (this) {
      case SignatureMethod.manual:
        return 'Manual Signature';
      case SignatureMethod.docusign:
        return 'DocuSign (Certified)';
    }
  }

  String get description {
    switch (this) {
      case SignatureMethod.manual:
        return 'Quick signature using mouse/touch. Free and instant.';
      case SignatureMethod.docusign:
        return 'Legally binding e-signature with audit trail. Industry standard.';
    }
  }

  IconData get icon {
    switch (this) {
      case SignatureMethod.manual:
        return Icons.edit;
      case SignatureMethod.docusign:
        return Icons.verified_user;
    }
  }

  Color get color {
    switch (this) {
      case SignatureMethod.manual:
        return FlownetColors.electricBlue;
      case SignatureMethod.docusign:
        return Colors.green;
    }
  }
}

/// Widget for selecting signature method (Manual or DocuSign)
class SignatureMethodSelector extends StatefulWidget {
  final SignatureMethod initialMethod;
  final Function(SignatureMethod) onMethodChanged;
  final bool docusignAvailable;
  final String? docusignUnavailableReason;
  
  const SignatureMethodSelector({
    super.key,
    this.initialMethod = SignatureMethod.manual,
    required this.onMethodChanged,
    this.docusignAvailable = false,
    this.docusignUnavailableReason,
  });

  @override
  State<SignatureMethodSelector> createState() => _SignatureMethodSelectorState();
}

class _SignatureMethodSelectorState extends State<SignatureMethodSelector> {
  late SignatureMethod _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialMethod;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Signature Method',
          style: TextStyle(
            color: FlownetColors.pureWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Manual Signature Option
        _buildMethodCard(
          method: SignatureMethod.manual,
          isSelected: _selectedMethod == SignatureMethod.manual,
          isEnabled: true,
        ),
        
        const SizedBox(height: 12),
        
        // DocuSign Option
        _buildMethodCard(
          method: SignatureMethod.docusign,
          isSelected: _selectedMethod == SignatureMethod.docusign,
          isEnabled: widget.docusignAvailable,
        ),
        
        // DocuSign unavailable message
        if (!widget.docusignAvailable && widget.docusignUnavailableReason != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.docusignUnavailableReason!,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMethodCard({
    required SignatureMethod method,
    required bool isSelected,
    required bool isEnabled,
  }) {
    return GestureDetector(
      onTap: isEnabled
          ? () {
              setState(() {
                _selectedMethod = method;
              });
              widget.onMethodChanged(method);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? method.color.withValues(alpha: 0.2)
              : FlownetColors.graphiteGray.withValues(alpha: isEnabled ? 1.0 : 0.5),
          border: Border.all(
            color: isSelected 
                ? method.color
                : FlownetColors.coolGray.withValues(alpha: isEnabled ? 1.0 : 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isEnabled
                    ? method.color.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                method.icon,
                color: isEnabled ? method.color : Colors.grey,
                size: 28,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        method.displayName,
                        style: TextStyle(
                          color: isEnabled 
                              ? FlownetColors.pureWhite
                              : FlownetColors.coolGray,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (method == SignatureMethod.manual)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (method == SignatureMethod.docusign)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: const Text(
                            'PREMIUM',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    method.description,
                    style: TextStyle(
                      color: isEnabled 
                          ? FlownetColors.coolGray
                          : FlownetColors.coolGray.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: method.color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact signature method indicator
class SignatureMethodBadge extends StatelessWidget {
  final SignatureMethod method;
  
  const SignatureMethodBadge({
    super.key,
    required this.method,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: method.color.withValues(alpha: 0.2),
        border: Border.all(color: method.color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(method.icon, color: method.color, size: 14),
          const SizedBox(width: 4),
          Text(
            method.displayName,
            style: TextStyle(
              color: method.color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

