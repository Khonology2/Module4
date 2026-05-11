import 'package:flutter/material.dart';
import '../services/signature_service.dart';
import '../services/api_client.dart';
import '../models/user_signature.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../widgets/signature_capture_widget.dart';

/// Screen for managing user signatures
/// Allows users to create, edit, and manage their saved signatures
class SignatureManagementScreen extends StatefulWidget {
  const SignatureManagementScreen({super.key});

  @override
  State<SignatureManagementScreen> createState() =>
      _SignatureManagementScreenState();
}

class _SignatureManagementScreenState extends State<SignatureManagementScreen> {
  List<UserSignature> _signatures = [];
  bool _isLoading = true;
  UserSignature? _defaultSignature;
  bool _isCreatingNew = false;
  late final SignatureService _signatureService;

  @override
  void initState() {
    super.initState();
    _signatureService = SignatureService(ApiClient());
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    setState(() => _isLoading = true);

    try {
      final signatures = await _signatureService.getUserSignatures();
      final defaultSig = await _signatureService.getDefaultSignature();

      setState(() {
        _signatures = signatures;
        _defaultSignature = defaultSig;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading signatures: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createNewSignature() async {
    setState(() => _isCreatingNew = true);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const SignatureCreationDialog(),
    );

    setState(() => _isCreatingNew = false);

    if (result != null && result['signatureData'] != null) {
      try {
        await _signatureService.saveSignature(
          result['signatureData'],
          result['signatureType'] ?? 'drawn',
          result['isDefault'] ?? false,
        );

        await _loadSignatures(); // Refresh list

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signature saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving signature: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _setDefaultSignature(UserSignature signature) async {
    try {
      await _signatureService.setDefaultSignature(signature.id);
      await _loadSignatures(); // Refresh list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default signature updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating default signature: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSignature(UserSignature signature) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Signature'),
        content: const Text('Are you sure you want to delete this signature?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _signatureService.deleteSignature(signature.id);
        await _loadSignatures(); // Refresh list

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signature deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting signature: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Signatures'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with create button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Signatures',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isCreatingNew ? null : _createNewSignature,
                        icon: _isCreatingNew
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: Text(
                            _isCreatingNew ? 'Creating...' : 'New Signature'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Signatures list
                Expanded(
                  child: _signatures.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _signatures.length,
                          itemBuilder: (context, index) {
                            final signature = _signatures[index];
                            final isDefault =
                                _defaultSignature?.id == signature.id;

                            return _buildSignatureCard(signature, isDefault);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.draw,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No saved signatures',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first signature to use it for quick document signing',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewSignature,
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Signature'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard(UserSignature signature, bool isDefault) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with default badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signature ${signature.signatureType}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Created: ${_formatDate(signature.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDefault)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'DEFAULT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Signature preview
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  signature.signatureDataBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[100],
                      child: const Center(
                        child: Text('Preview unavailable'),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                if (!isDefault)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setDefaultSignature(signature),
                      child: const Text('Set as Default'),
                    ),
                  ),
                if (!isDefault) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteSignature(signature),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return app_date_utils.DateUtils.formatDate(date);
  }
}

/// Dialog for creating new signature
class SignatureCreationDialog extends StatefulWidget {
  const SignatureCreationDialog({super.key});

  @override
  State<SignatureCreationDialog> createState() =>
      _SignatureCreationDialogState();
}

class _SignatureCreationDialogState extends State<SignatureCreationDialog> {
  String? _signatureData;
  bool _isDefault = false;
  String _signatureType = 'drawn';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxHeight: 600),
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
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SignatureCaptureWidget(
                      allowSignatureReuse: false,
                      showAuditInfo: false,
                      onSignatureCaptured: (signatureData) {
                        setState(() => _signatureData = signatureData);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Signature type and default options
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _signatureType,
                            decoration: const InputDecoration(
                              labelText: 'Signature Type',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'drawn', child: Text('Drawn')),
                              DropdownMenuItem(
                                  value: 'typed', child: Text('Typed')),
                              DropdownMenuItem(
                                  value: 'uploaded', child: Text('Uploaded')),
                            ],
                            onChanged: (value) {
                              setState(() => _signatureType = value!);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('Set as default signature'),
                            value: _isDefault,
                            onChanged: (value) {
                              setState(() => _isDefault = value!);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _signatureData != null
                        ? () {
                            Navigator.pop(context, {
                              'signatureData': _signatureData,
                              'signatureType': _signatureType,
                              'isDefault': _isDefault,
                            });
                          }
                        : null,
                    child: const Text('Save Signature'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
