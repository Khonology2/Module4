import 'package:flutter/material.dart';
import '../services/signature_service.dart';
import '../services/api_client.dart';
import '../models/user_signature.dart';
import '../widgets/signature_capture_widget.dart';

/// Enhanced signing workflow widget
/// Supports both new signature capture and saved signature selection
class EnhancedSigningWidget extends StatefulWidget {
  final String reportId;
  final String reportTitle;
  final Function(Map<String, dynamic>)? onSigningComplete;
  final Function(String)? onDocuSignRequested;

  const EnhancedSigningWidget({
    super.key,
    required this.reportId,
    required this.reportTitle,
    this.onSigningComplete,
    this.onDocuSignRequested,
  });

  @override
  State<EnhancedSigningWidget> createState() => _EnhancedSigningWidgetState();
}

class _EnhancedSigningWidgetState extends State<EnhancedSigningWidget> {
  bool _isLoading = false;
  bool _showSavedSignatures = false;
  List<UserSignature> _savedSignatures = [];
  UserSignature? _defaultSignature;
  String? _selectedSignatureId;
  final bool _useDocuSign = false;
  late final SignatureService _signatureService;

  @override
  void initState() {
    super.initState();
    _signatureService = SignatureService(ApiClient());
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    try {
      final signatures = await _signatureService.getUserSignatures();
      final defaultSig = await _signatureService.getDefaultSignature();

      setState(() {
        _savedSignatures = signatures;
        _defaultSignature = defaultSig;
        _selectedSignatureId = defaultSig?.id;
      });
    } catch (e) {
      debugPrint('Error loading signatures: $e');
    }
  }

  Future<void> _signWithSavedSignature() async {
    if (_selectedSignatureId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a signature'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _signatureService.signWithSavedSignature(
        widget.reportId,
        _selectedSignatureId!,
        {
          'reportTitle': widget.reportTitle,
          'signedAt': DateTime.now().toIso8601String(),
          'signingMethod': 'saved_signature',
        },
      );

      if (widget.onSigningComplete != null) {
        widget.onSigningComplete!(result);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document signed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAsNewSignature() async {
    // This would open the signature capture dialog
    // and then sign with the newly created signature
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create New Signature',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Signature capture
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SignatureCaptureWidget(
                    onSignatureCaptured: (signatureData) {
                      if (signatureData != null) {
                        Navigator.pop(context, {
                          'signatureData': signatureData,
                          'saveAndSign': true,
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && result['signatureData'] != null) {
      await _saveAndSignWithNewSignature(result['signatureData']);
    }
  }

  Future<void> _saveAndSignWithNewSignature(String signatureData) async {
    setState(() => _isLoading = true);

    try {
      // Save as new signature
      final newSignature = await _signatureService.saveSignature(
        signatureData,
        'drawn',
        false, // Don't set as default automatically
      );

      // Sign with the new signature
      final result = await _signatureService.signWithSavedSignature(
        widget.reportId,
        newSignature.id,
        {
          'reportTitle': widget.reportTitle,
          'signedAt': DateTime.now().toIso8601String(),
          'signingMethod': 'new_signature',
          'newSignatureId': newSignature.id,
        },
      );

      if (widget.onSigningComplete != null) {
        widget.onSigningComplete!(result);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New signature saved and document signed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _requestDocuSign() {
    if (widget.onDocuSignRequested != null) {
      widget.onDocuSignRequested!(widget.reportId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Sign Document: ${widget.reportTitle}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Signing options
          if (_savedSignatures.isNotEmpty) ...[
            // Toggle between saved signatures and new signature
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showSavedSignatures = true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _showSavedSignatures
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_books,
                            color: _showSavedSignatures
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Use Saved Signature',
                            style: TextStyle(
                              color: _showSavedSignatures
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showSavedSignatures = false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !_showSavedSignatures
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.create,
                            color: !_showSavedSignatures
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Create New Signature',
                            style: TextStyle(
                              color: !_showSavedSignatures
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Content based on selection
          if (_showSavedSignatures && _savedSignatures.isNotEmpty) ...[
            _buildSavedSignaturesSection(),
          ] else ...[
            _buildNewSignatureSection(),
          ],

          const SizedBox(height: 16),

          // Action buttons
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Row(
              children: [
                if (_showSavedSignatures && _savedSignatures.isNotEmpty) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedSignatureId != null
                          ? _signWithSavedSignature
                          : null,
                      child: const Text('Sign with Selected Signature'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: _useDocuSign ? null : _requestDocuSign,
                    child: const Text('Use DocuSign Instead'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSavedSignaturesSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _savedSignatures.isEmpty
          ? const Center(
              child: Text('No saved signatures available'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _savedSignatures.length,
              itemBuilder: (context, index) {
                final signature = _savedSignatures[index];
                final isSelected = _selectedSignatureId == signature.id;
                final isDefault = _defaultSignature?.id == signature.id;

                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedSignatureId = signature.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        // Signature preview
                        Container(
                          width: 60,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Image.memory(
                              signature.signatureDataBytes,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error, size: 16),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Signature info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                signature.signatureTypeDisplay,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'DEFAULT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Selection indicator
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNewSignatureSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.create,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'Click below to create a new signature',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveAsNewSignature,
              icon: const Icon(Icons.add),
              label: const Text('Create & Sign'),
            ),
          ],
        ),
      ),
    );
  }
}
