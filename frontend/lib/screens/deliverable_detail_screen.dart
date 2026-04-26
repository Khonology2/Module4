// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/deliverable.dart';
import '../services/deliverable_service.dart';
import '../services/backend_api_service.dart';
import '../services/auth_service.dart';
import '../config/environment.dart';
import 'audit_log_detail_screen.dart';

class DeliverableDetailScreen extends StatefulWidget {
  final Deliverable deliverable;

  const DeliverableDetailScreen({
    super.key,
    required this.deliverable,
  });

  @override
  State<DeliverableDetailScreen> createState() => _DeliverableDetailScreenState();
}

class _DeliverableDetailScreenState extends State<DeliverableDetailScreen> {
  late Deliverable _deliverable;
  final DeliverableService _deliverableService = DeliverableService();
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isDragging = false;
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedPriority;
  DateTime? _selectedDueDate;
  String? _selectedProjectId;
  String? _selectedOwnerId;
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _deliverable = widget.deliverable;
    _initControllers();
    _loadDeliverableDetails();
    _loadProjects();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final backendApiService = BackendApiService();
      final response = await backendApiService.getUsers(limit: 100);
      
      if (response.isSuccess && response.data != null) {
        List<dynamic> usersList = [];
        if (response.data is List) {
          usersList = response.data as List;
        } else if (response.data is Map) {
          final data = response.data as Map<String, dynamic>;
          usersList = data['data'] as List? ?? data['users'] as List? ?? [];
        }
        
        setState(() {
          _users = usersList
              .where((u) => u != null)
              .map((u) => u is Map ? Map<String, dynamic>.from(u) : <String, dynamic>{})
              .where((m) => m.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Future<void> _loadProjects() async {
    try {
      final backendApiService = BackendApiService();
      final response = await backendApiService.getProjects();
      
      if (response.isSuccess && response.data != null) {
        List<dynamic> projectsList = [];
        if (response.data is List) {
          projectsList = response.data as List;
        } else if (response.data is Map) {
          final data = response.data as Map<String, dynamic>;
          projectsList = data['data'] as List? ?? data['projects'] as List? ?? [];
        }
        
        setState(() {
          _projects = projectsList
              .where((p) => p != null)
              .map((p) => p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{})
              .where((m) => m.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
    }
  }

  void _initControllers() {
    _titleController = TextEditingController(text: _deliverable.title);
    _descriptionController = TextEditingController(text: _deliverable.description);
    
    // safe-match priority to ensure it exists in dropdown items
    final priorities = ['Low', 'Medium', 'High', 'Critical'];
    _selectedPriority = priorities.firstWhere(
      (p) => p.toLowerCase() == (_deliverable.priority.toLowerCase()),
      orElse: () => 'Medium',
    );
    
    _selectedDueDate = _deliverable.dueDate;
    _selectedProjectId = _deliverable.projectId;
    _selectedOwnerId = _deliverable.ownerId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDeliverableDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await _deliverableService.getDeliverable(_deliverable.id);
      if (response.isSuccess && response.data != null) {
        if (mounted) {
          setState(() {
            _deliverable = response.data['deliverable'] as Deliverable;
            if (!_isEditing) {
              _initControllers();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading deliverable details: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!AuthService().canEditDeliverable()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to edit this deliverable.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final response = await _deliverableService.updateDeliverable(
        id: _deliverable.id,
        title: _titleController.text,
        description: _descriptionController.text,
        priority: _selectedPriority,
        dueDate: _selectedDueDate,
        projectId: _selectedProjectId,
        ownerId: _selectedOwnerId,
      );

      if (response.isSuccess && mounted) {
        // Reload details to get fully populated object (including owner name, etc.)
        await _loadDeliverableDetails();
        
        setState(() {
          _isEditing = false;
          _initControllers();
        });
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes: ${response.error}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _toggleDoDItem(int index, bool? value) async {
    if (value == null) return;

    // Create new list with updated item
    final newDoD = List<DoDItem>.from(_deliverable.definitionOfDone);
    final item = newDoD[index];
    newDoD[index] = DoDItem(text: item.text, isCompleted: value);

    // Optimistic update
    setState(() {
      _deliverable = _deliverable.copyWith(definitionOfDone: newDoD);
    });

    try {
      final response = await _deliverableService.updateDeliverable(
        id: _deliverable.id,
        definitionOfDone: newDoD,
      );

      if (!response.isSuccess) {
        // Revert on failure
        if (mounted) {
          _loadDeliverableDetails(); // Reload to ensure consistency
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to update: ${response.error}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _loadDeliverableDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (!AuthService().canEditDeliverable()) return;
    if (files.isEmpty) return;
    
    setState(() => _isUploading = true);
    
    int successCount = 0;
    final List<String> errors = [];
    
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final response = await _deliverableService.uploadArtifact(
            deliverableId: _deliverable.id,
            filePath: kIsWeb ? '' : file.path,
            fileName: file.name,
            fileBytes: bytes,
        );
        
        if (response.isSuccess) {
          successCount++;
        } else {
          errors.add('${file.name}: ${response.error}');
        }
      } catch (e) {
        errors.add('${file.name}: $e');
      }
    }
    
    if (mounted) {
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Uploaded $successCount artifacts')),
        );
        _loadDeliverableDetails();
      }
      
      if (errors.isNotEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errors: ${errors.take(3).join(", ")}'), backgroundColor: Colors.red),
         );
      }
      
      setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadArtifact() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true, withReadStream: true);

      if (result != null && (result.files.single.path != null || result.files.single.bytes != null)) {
        setState(() => _isUploading = true);
        
        final file = result.files.single;
        List<int>? bytes = file.bytes;
        if ((bytes == null || bytes.isEmpty) && file.readStream != null) {
          final out = <int>[];
          await for (final chunk in file.readStream!) {
            out.addAll(chunk);
          }
          bytes = out;
        }
        final response = await _deliverableService.uploadArtifact(
          deliverableId: _deliverable.id,
          filePath: kIsWeb ? '' : (file.path ?? ''),
          fileName: file.name,
          fileBytes: bytes,
        );

        if (mounted) {
          setState(() => _isUploading = false);
          if (response.isSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Artifact uploaded successfully')),
            );
            _loadDeliverableDetails();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: ${response.error}'), backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteArtifact(String artifactId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Artifact'),
        content: const Text('Are you sure you want to delete this artifact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final response = await _deliverableService.deleteArtifact(_deliverable.id, artifactId);
        if (response.isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Artifact deleted successfully')),
            );
            _loadDeliverableDetails();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Delete failed: ${response.error}'), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting artifact: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _downloadArtifact(DeliverableArtifact artifact) async {
    try {
      // If URL is complete, use it. Otherwise construct it.
      String url = artifact.url;
      if (!url.startsWith('http')) {
         // Assuming uploads are served from /uploads and API base URL includes /api/v1
         // We need to strip /api/v1 to get to root if needed, or use a configured file base URL
         // For now, let's assume standard structure
         final baseUrl = Environment.apiBaseUrl.replaceAll('/api/v1', '');
         url = '$baseUrl/uploads/$url';
      }
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  IconData _getFileIcon(String fileType) {
    final type = fileType.toLowerCase();
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('doc') || type.contains('word')) return Icons.description;
    if (type.contains('xls') || type.contains('sheet')) return Icons.table_chart;
    if (type.contains('ppt') || type.contains('presentation')) return Icons.slideshow;
    if (type.contains('img') || type.contains('png') || type.contains('jpg') || type.contains('jpeg')) return Icons.image;
    if (type.contains('zip') || type.contains('rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Future<void> _exportAuditLogCsv() async {
    try {
      final List<List<dynamic>> rows = [
        ['Timestamp', 'User', 'Action', 'Details'],
      ];

      for (var log in _deliverable.auditLogs) {
        rows.add([
          log.createdAt.toString(),
          log.userName ?? log.userEmail ?? log.userId ?? 'Unknown',
          log.action,
          log.changedFields?.join(', ') ?? '',
        ]);
      }

      final String csvData = const ListToCsvConverter().convert(rows);
      
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV export is not supported on web')),
          );
        }
        return;
      }
      
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Audit Log CSV',
        fileName: 'audit_log_${_deliverable.id}.csv',
        allowedExtensions: ['csv'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(csvData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to $outputFile')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting CSV: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportAuditLogPdf() async {
    try {
      final doc = pw.Document();
      
      final font = await PdfGoogleFonts.nunitoExtraLight();

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Audit Log - ${_deliverable.title}', style: pw.TextStyle(font: font, fontSize: 24)),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              data: <List<String>>[
                <String>['Timestamp', 'User', 'Action', 'Details'],
                ..._deliverable.auditLogs.map((log) => [
                  DateFormat('yyyy-MM-dd HH:mm').format(log.createdAt),
                  log.userName ?? log.userEmail ?? 'Unknown',
                  log.action,
                  log.changedFields?.join(', ') ?? '-',
                ]),
              ],
            ),
          ];
        },
      ));

      await Printing.sharePdf(bytes: await doc.save(), filename: 'audit_log_${_deliverable.id}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAuditLogDetails(AuditLogEntry log) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuditLogDetailScreen(logEntry: log),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = AuthService().canEditDeliverable();
    return Scaffold(
      appBar: AppBar(
        title: _isEditing 
            ? TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter title',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
              )
            : Text(_deliverable.title),
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveChanges,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _initControllers(); // Reset changes
                });
              },
            ),
          ] else ...[
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => setState(() => _isEditing = true),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDeliverableDetails,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildDescription(),
                  const SizedBox(height: 24),
                  _buildDefinitionOfDone(),
                  const SizedBox(height: 24),
                  _buildArtifactsSection(),
                  const SizedBox(height: 24),
                  _buildAuditLogSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(_deliverable.statusDisplayName),
                  // ignore: duplicate_ignore
                  // ignore: deprecated_member_use
                  backgroundColor: _deliverable.statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: _deliverable.statusColor),
                ),
                const Spacer(),
                if (_isEditing)
                  DropdownButton<String>(
                    value: _selectedPriority,
                    items: ['Low', 'Medium', 'High', 'Critical']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedPriority = val),
                  )
                else
                  Text(
                    'Priority: ${_deliverable.priority}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDueDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() => _selectedDueDate = date);
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _selectedDueDate != null 
                          ? DateFormat('MMM d, yyyy').format(_selectedDueDate!)
                          : 'Select Due Date',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Due Date: ${DateFormat('MMM d, yyyy').format(_deliverable.dueDate)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            if (_isEditing)
              DropdownButtonFormField<String>(
                value: _selectedProjectId,
                decoration: const InputDecoration(
                  labelText: 'Project',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(_projects.isEmpty ? 'No projects available' : 'Unassigned'),
                  ),
                  ..._projects.map((p) => DropdownMenuItem<String>(
                    value: p['id'].toString(),
                    child: Text(p['name'] ?? p['key'] ?? 'Unknown'),
                  )),
                ],
                onChanged: (val) => setState(() => _selectedProjectId = val),
              )
            else if (_deliverable.projectName != null)
              Text(
                'Project: ${_deliverable.projectName}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (_deliverable.assignedToName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Assigned to: ${_deliverable.assignedToName}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (_isEditing) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final displayUsers = List<Map<String, dynamic>>.from(_users);
                  // Ensure selected owner is in the list to avoid dropdown crash
                  if (_selectedOwnerId != null && 
                      _selectedOwnerId!.isNotEmpty &&
                      !displayUsers.any((u) => u['id'].toString() == _selectedOwnerId)) {
                    displayUsers.add({
                      'id': _selectedOwnerId,
                      'name': _deliverable.ownerName ?? 'Current Owner',
                      'email': 'Unknown',
                    });
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedOwnerId,
                    decoration: const InputDecoration(
                      labelText: 'Owner',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      ...displayUsers.map((u) {
                        String name = u['name'] ?? '';
                        if (name.isEmpty) {
                          final first = u['first_name'] ?? u['firstName'] ?? '';
                          final last = u['last_name'] ?? u['lastName'] ?? '';
                          if (first.isNotEmpty || last.isNotEmpty) {
                            name = '$first $last'.trim();
                          }
                        }
                        if (name.isEmpty) {
                          name = u['email'] ?? 'Unknown';
                        }
                        
                        return DropdownMenuItem<String>(
                          value: u['id'].toString(),
                          child: Text(name),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedOwnerId = val),
                  );
                }
              ),
            ] else if (_deliverable.ownerName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Owner: ${_deliverable.ownerName}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (_isEditing)
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter description',
            ),
          )
        else
          Text(_deliverable.description),
      ],
    );
  }

  Widget _buildDefinitionOfDone() {
    if (_deliverable.definitionOfDone.isEmpty) return const SizedBox.shrink();

    final canEdit = AuthService().canEditDeliverable();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Definition of Done',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ..._deliverable.definitionOfDone.asMap().entries.map((entry) {
          final index = entry.key;
          final dod = entry.value;
          return CheckboxListTile(
            value: dod.isCompleted,
            title: Text(dod.text),
            onChanged: canEdit ? (val) => _toggleDoDItem(index, val) : null,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          );
        }),
      ],
    );
  }

  Widget _buildArtifactsSection() {
    final canEdit = AuthService().canEditDeliverable();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Artifacts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ElevatedButton.icon(
              onPressed: (!canEdit || _isUploading) ? null : _uploadArtifact,
              icon: _isUploading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.upload_file),
              label: Text(_isUploading ? 'Uploading...' : 'Upload'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropTarget(
          onDragDone: (detail) => _handleDroppedFiles(detail.files),
          onDragEntered: (detail) => setState(() => _isDragging = true),
          onDragExited: (detail) => setState(() => _isDragging = false),
          child: Container(
            constraints: const BoxConstraints(minHeight: 100),
            decoration: BoxDecoration(
              border: Border.all(
                color: _isDragging ? Theme.of(context).primaryColor : Colors.grey.shade300,
                width: _isDragging ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: _isDragging ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
            ),
            child: _deliverable.artifacts.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No artifacts yet. Drag & drop files here or click Upload.'),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _deliverable.artifacts.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final artifact = _deliverable.artifacts[index];
                      return ListTile(
                        leading: Icon(_getFileIcon(artifact.fileType)),
                        title: Text(artifact.originalName),
                        subtitle: Text(
                          'Uploaded by ${artifact.uploaderName ?? artifact.uploadedBy} on ${DateFormat('MMM d, HH:mm').format(artifact.createdAt)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () => _downloadArtifact(artifact),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: canEdit ? () => _deleteArtifact(artifact.id) : null,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogSection() {
    return Card(
      child: ExpansionTile(
        title: Text(
          'Audit Log',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        subtitle: Text('${_deliverable.auditLogs.length} entries'),
        leading: const Icon(Icons.history),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _exportAuditLogCsv,
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Export CSV'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportAuditLogPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                ),
              ],
            ),
          ),
          if (_deliverable.auditLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No audit history available.'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _deliverable.auditLogs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = _deliverable.auditLogs[index];
                return ListTile(
                  leading: const Icon(Icons.edit_note, size: 20),
                  title: Text(
                    log.action.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${log.userName ?? log.userEmail ?? 'Unknown'} • ${DateFormat('yyyy-MM-dd HH:mm').format(log.createdAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showAuditLogDetails(log),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
