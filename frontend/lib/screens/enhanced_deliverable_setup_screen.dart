// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../models/release_readiness.dart';
import '../theme/flownet_theme.dart';
import '../widgets/ai_readiness_gate_widget.dart';
import '../services/deliverable_service.dart';
import '../services/sprint_database_service.dart';
import '../services/project_service.dart';
import '../services/backend_api_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../models/dod_item.dart';

class EnhancedDeliverableSetupScreen extends ConsumerStatefulWidget {
  const EnhancedDeliverableSetupScreen({super.key});

  @override
  ConsumerState<EnhancedDeliverableSetupScreen> createState() =>
      _EnhancedDeliverableSetupScreenState();
}

class _EnhancedDeliverableSetupScreenState
    extends ConsumerState<EnhancedDeliverableSetupScreen> {
  static const Color _brandRed = Color(0xFFD70E0E);
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _evidenceController = TextEditingController();

  DateTime? _dueDate;
  final List<String> _selectedSprints = [];
  String? _pendingSprintId;
  final List<DoDItem> _definitionOfDone = [];
  final List<String> _evidenceLinks = [];
  final List<PlatformFile> _artifactFiles = [];
  final TextEditingController _artifactDescriptionController = TextEditingController();
  final List<ReadinessItem> _readinessItems = [];
  final DeliverableService _deliverableService = DeliverableService();
  final SprintDatabaseService _sprintService = SprintDatabaseService();

  ReadinessStatus _currentReadinessStatus = ReadinessStatus.red;
  bool _hasInternalApproval = false;

  String? _selectedProjectId;
  String? _ownerId;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _availableSprints = [];
  bool _isLoadingSprints = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _projects = [];
  bool _isUploadingArtifacts = false;

  @override
  void initState() {
    super.initState();
    try {
      final ri = GoRouter.of(context).routeInformationProvider.value;
      final Uri uri = ri.uri;
      final sprintId = uri.queryParameters['sprintId'];
      final projectId = uri.queryParameters['projectId'];
      if (sprintId != null &&
          sprintId.isNotEmpty &&
          !_selectedSprints.contains(sprintId)) {
        _selectedSprints.add(sprintId);
      }
      if (projectId != null && projectId.isNotEmpty) {
        _selectedProjectId = projectId;
      }
    } catch (_) {}
    final me = AuthService().currentUser;
    if ((_ownerId == null || _ownerId!.trim().isEmpty) && me?.id != null) {
      _ownerId = me!.id.toString();
    }
    _initializeReadinessItems();
    _loadSprints();
    _loadUsers();
    _loadProjects();
  }

  Future<void> _loadUsers() async {
    try {
      final backend = BackendApiService();
      final response = await backend.getUsers();
      if (mounted && response.isSuccess && response.data != null) {
        setState(() {
          if (response.data is List) {
            _users = List<Map<String, dynamic>>.from(response.data);
          } else if (response.data is Map && response.data['users'] != null) {
            _users = List<Map<String, dynamic>>.from(response.data['users']);
          } else if (response.data is Map && response.data['data'] != null) {
            _users = List<Map<String, dynamic>>.from(response.data['data']);
          }
        });
      }
      if (!mounted) return;
      final me = AuthService().currentUser;
      if (me?.id != null) {
        final myId = me!.id.toString();
        setState(() {
          if (!_users.any((u) => u['id']?.toString() == myId)) {
            _users = [
              {
                'id': myId,
                'name': me.name,
                'email': me.email,
              },
              ..._users,
            ];
          }
          if ((_ownerId == null || _ownerId!.trim().isEmpty) && myId.isNotEmpty) {
            _ownerId = myId;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await ProjectService.getAllProjects();
      if (mounted) {
        setState(() {
          _projects = projects
              .map((p) => {
                    'id': p.id,
                    'name': p.name,
                  })
              .toList();

          // If _selectedProjectId is set but not in list, check if we need to clear it or if it's valid
          // But since we want to pre-select, we should ensure the type matches
          if (_selectedProjectId != null &&
              !_projects
                  .any((p) => p['id']?.toString() == _selectedProjectId)) {
            debugPrint(
                '⚠️ Selected project ID $_selectedProjectId not found in loaded projects');
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
    }
  }

  Future<void> _loadSprints() async {
    setState(() => _isLoadingSprints = true);
    try {
      // Add timeout to prevent infinite loading
      final sprints = await _sprintService.getSprints().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Sprint loading timed out, using empty list');
          return <Map<String, dynamic>>[];
        },
      );
      setState(() {
        _availableSprints = sprints;
        _isLoadingSprints = false;
      });
    } catch (e) {
      debugPrint('Error loading sprints: $e');
      setState(() {
        _availableSprints = []; // Ensure we have a fallback
        _isLoadingSprints = false;
      });
    }
  }

  void _initializeReadinessItems() {
    _readinessItems.addAll([
      const ReadinessItem(
        id: 'dod-complete',
        category: 'Definition of Done',
        description: 'All DoD items are completed',
        isRequired: true,
        isCompleted: false,
      ),
      const ReadinessItem(
        id: 'evidence-attached',
        category: 'Evidence',
        description: 'Demo links, repos, and test summaries are attached',
        isRequired: true,
        isCompleted: false,
      ),
      const ReadinessItem(
        id: 'sprint-metrics',
        category: 'Sprint Performance',
        description: 'Sprint metrics are captured and reviewed',
        isRequired: true,
        isCompleted: false,
      ),
      const ReadinessItem(
        id: 'quality-gates',
        category: 'Quality Gates',
        description: 'Test pass rate > 90% and critical defects resolved',
        isRequired: true,
        isCompleted: false,
      ),
      const ReadinessItem(
        id: 'documentation',
        category: 'Documentation',
        description: 'User guides and technical documentation are complete',
        isRequired: false,
        isCompleted: false,
      ),
    ]);
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  void _addDoDItem() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: FlownetColors.graphiteGray,
          title: const Text('Add Definition of Done Item'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter DoD item...',
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _definitionOfDone.add(DoDItem(text: controller.text));
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addEvidenceLink() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: FlownetColors.graphiteGray,
          title: const Text('Add Evidence Link'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter evidence URL...',
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _evidenceLinks.add(controller.text);
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestInternalApproval(String comment) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: const Text('Request Internal Approval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You are requesting internal approval to proceed despite readiness issues. '
              'An internal approver will review and decide whether to allow submission.',
            ),
            const SizedBox(height: 16),
            Text(
              comment,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Request Approval'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (!mounted) return;
      setState(() {
        _hasInternalApproval = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Internal approval requested. You can now proceed with submission.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _submitDeliverable() async {
    // Validate form first - check if form key is initialized
    if (_formKey.currentState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Form not initialized. Please refresh the page.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please fill in all required fields correctly'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Additional validation: title must not be empty or just whitespace
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Title cannot be empty'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      // Focus on title field
      FocusScope.of(context).requestFocus(FocusNode());
      return;
    }

    // Additional validation: description must not be empty or just whitespace
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Description cannot be empty'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Amber and red both require explicit internal approval before proceeding.
    if ((_currentReadinessStatus == ReadinessStatus.red ||
            _currentReadinessStatus == ReadinessStatus.amber) &&
        !_hasInternalApproval) {
      _showReadinessDialog();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Use trimmed values
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();

      debugPrint('📦 Creating deliverable: $title');

      // Final validation before API call
      if (title.isEmpty) {
        throw Exception('Title cannot be empty');
      }
      if (description.isEmpty) {
        throw Exception('Description cannot be empty');
      }

      // Convert arrays to JSON strings for backend
      // Send definition_of_done as a JSON array (not a joined string)
      // The backend expects JSON format for the JSON column

      // Use DeliverableService to create deliverable
      final response = await _deliverableService.createDeliverable(
        title: title,
        description: description.isEmpty ? null : description,
        definitionOfDone: _definitionOfDone.isEmpty ? null : _definitionOfDone,
        priority: 'Medium',
        status: 'Draft',
        dueDate: _dueDate,
        sprintId: _selectedSprints.isNotEmpty ? _selectedSprints.first : null,
        sprintIds: _selectedSprints,
        assignedTo: _ownerId,
        projectId: _selectedProjectId,
      );
      
      if (!mounted) return;

      if (!response.isSuccess) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to create deliverable: ${response.error ?? "Unknown error"}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      String deliverableId = '';
      try {
        final raw = response.data;
        if (raw is Map) {
          final d = raw['deliverable'];
          if (d is Map) {
            deliverableId = (d['id'] ?? d['uuid'] ?? '').toString();
          } else if (d != null) {
            deliverableId = (d.id ?? '').toString();
          }
          if (deliverableId.isEmpty) {
            deliverableId = (raw['id'] ?? raw['uuid'] ?? '').toString();
          }
        }
      } catch (_) {}

      if (_artifactFiles.isNotEmpty && deliverableId.isNotEmpty) {
        await _uploadSelectedArtifacts(deliverableId);
      }

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      try {
        RealtimeService().emitLocal('deliverable_created', {
          'id': deliverableId,
          'title': title,
          'owner_id': _ownerId,
          'created_by': AuthService().currentUser?.id,
        });
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Deliverable "$title" created successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.go('/dashboard');
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating deliverable: $e');
      debugPrint('📚 Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error creating deliverable: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _pickArtifactFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: true,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.where((f) {
        final name = (f.name).toLowerCase();
        return !name.endsWith('.json');
      }).toList();

      if (picked.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('JSON files cannot be uploaded.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        for (final f in picked) {
          final key = '${f.name}|${f.size}';
          final exists = _artifactFiles.any((e) => '${e.name}|${e.size}' == key);
          if (!exists) _artifactFiles.add(f);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick files: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _uploadSelectedArtifacts(String deliverableId) async {
    if (_isUploadingArtifacts) return;
    setState(() => _isUploadingArtifacts = true);
    try {
      final backend = BackendApiService();
      final description = _artifactDescriptionController.text.trim();
      int ok = 0;
      int failed = 0;
      for (final f in List<PlatformFile>.from(_artifactFiles)) {
        List<int>? bytes = f.bytes;
        if ((bytes == null || bytes.isEmpty) && f.readStream != null) {
          final out = <int>[];
          await for (final chunk in f.readStream!) {
            out.addAll(chunk);
          }
          bytes = out;
        }
        if (bytes == null || bytes.isEmpty) {
          failed += 1;
          continue;
        }
        final resp = await backend.uploadDeliverableArtifact(
          deliverableId,
          bytes,
          f.name,
          title: f.name,
          description: description.isEmpty ? null : description,
        );
        if (resp.isSuccess) {
          ok += 1;
        } else {
          failed += 1;
        }
      }
      if (!mounted) return;
      if (failed == 0 && ok > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded $ok document(s)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (ok > 0 && failed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded $ok document(s), $failed failed'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (failed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$failed document upload(s) failed'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingArtifacts = false);
    }
  }

  void _showReadinessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: const Text('Release Readiness Check'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This deliverable needs internal approval before it can be created. Complete the missing items or request an override:'),
            const SizedBox(height: 16),
            ..._readinessItems
                .where((item) => item.isRequired && !item.isCompleted)
                .map(
                  (item) => ListTile(
                    leading: const Icon(Icons.warning, color: Colors.red),
                    title: Text(item.description),
                    subtitle: Text(item.category),
                  ),
                ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestInternalApproval(
                _currentReadinessStatus == ReadinessStatus.red
                    ? 'Requesting internal approval because critical readiness issues remain.'
                    : 'Requesting internal approval because acknowledged readiness issues remain.',
              );
            },
            child: const Text('Request Internal Approval'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/deliverables-overview');
            }
          },
        ),
        title: const Text('Create Deliverable'),
        backgroundColor: Colors.transparent,
        foregroundColor: FlownetColors.pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme.copyWith(
                  bodyLarge: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  bodyMedium: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFF3F4146),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _brandRed, width: 1.4),
                  ),
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  floatingLabelStyle: const TextStyle(
                    color: _brandRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 14,
                  ),
                  prefixIconColor: Colors.white70,
                  suffixIconColor: Colors.white70,
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Deliverable Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                onChanged: (value) {
                  // Trigger rebuild so AI widget can analyze
                  setState(() {});
                  // Trigger AI analysis when title changes
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && value.trim().isNotEmpty) {
                      setState(
                          () {}); // Force widget rebuild to trigger AI analysis
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                minLines: 2,
                maxLines: 2,
                onChanged: (value) {
                  debugPrint('📝 Title changed to: "$value"');
                  // Trigger rebuild so AI widget can analyze
                  setState(() {
                    // Force rebuild with new key
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Owner Dropdown
              DropdownButtonFormField<String?>(
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                value: _users.any((u) => u['id']?.toString() == _ownerId)
                    ? _ownerId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Owner',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Unassigned')),
                  ..._users.map((user) {
                    final name = user['name'] ?? user['email'] ?? 'Unknown';
                    return DropdownMenuItem(
                      value: user['id']?.toString(),
                      child: Text(name),
                    );
                  }),
                ],
                onChanged: (value) => setState(() => _ownerId = value),
              ),
              const SizedBox(height: 16),

              // Project Dropdown
              DropdownButtonFormField<String?>(
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                value: _projects
                        .any((p) => p['id']?.toString() == _selectedProjectId)
                    ? _selectedProjectId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Project',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Select Project')),
                  ..._projects.map((project) {
                    final name = project['name'] ?? 'Unknown Project';
                    return DropdownMenuItem(
                      value: project['id']?.toString(),
                      child: Text(name),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProjectId = value;
                    if (value != null && value.trim().isNotEmpty) {
                      _selectedSprints.removeWhere((sid) {
                        final s = _availableSprints.firstWhere(
                          (sp) => (sp['id']?.toString() ?? '') == sid,
                          orElse: () => <String, dynamic>{},
                        );
                        final pid = (s['project_id'] ?? s['projectId'])?.toString() ?? '';
                        return pid.isNotEmpty && pid != value;
                      });
                      _pendingSprintId = null;
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Project is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Due Date
              InkWell(
                onTap: _selectDueDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _dueDate != null
                        ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                        : 'Select due date',
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Sprint Selection
              _buildSectionHeader('Contributing Sprints'),
              const SizedBox(height: 8),
              Text(
                'Select the sprint(s) that contributed to this deliverable',
                style: TextStyle(
                    color: FlownetColors.pureWhite.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),

              if (_isLoadingSprints)
                const Center(child: CircularProgressIndicator())
              else if (_availableSprints.isEmpty)
                const Card(
                  color: FlownetColors.graphiteGray,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No sprints available. Create a sprint first.'),
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final projectId = (_selectedProjectId ?? '').trim();
                    final available = projectId.isEmpty
                        ? _availableSprints
                        : _availableSprints.where((s) {
                            final pid = (s['project_id'] ?? s['projectId'])?.toString() ?? '';
                            return pid == projectId;
                          }).toList();

                    final remaining = available.where((s) {
                      final sid = s['id']?.toString() ?? '';
                      return sid.isNotEmpty && !_selectedSprints.contains(sid);
                    }).toList();

                    final selected = available.where((s) {
                      final sid = s['id']?.toString() ?? '';
                      return sid.isNotEmpty && _selectedSprints.contains(sid);
                    }).toList();

                    return Card(
                      color: FlownetColors.graphiteGray,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 520;

                                final dropdown = DropdownButtonFormField<String?>(
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                  initialValue: remaining.any((s) => (s['id']?.toString() ?? '') == _pendingSprintId)
                                      ? _pendingSprintId
                                      : null,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Add sprint',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: Text('Select sprint', overflow: TextOverflow.ellipsis),
                                      ),
                                    ),
                                    ...remaining.map((s) {
                                      final sid = s['id']?.toString() ?? '';
                                      final name = s['name']?.toString() ?? 'Unnamed Sprint';
                                      final status = s['status']?.toString() ?? '';
                                      final label = status.isNotEmpty ? '$name • $status' : name;
                                      return DropdownMenuItem<String?>(
                                        value: sid,
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: Text(label, overflow: TextOverflow.ellipsis, softWrap: false),
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (v) => setState(() => _pendingSprintId = v),
                                );

                                final addButton = SizedBox(
                                  width: compact ? double.infinity : null,
                                  child: ElevatedButton(
                                    onPressed: (_pendingSprintId == null)
                                        ? null
                                        : () {
                                            final sid = _pendingSprintId;
                                            if (sid == null || sid.isEmpty) return;
                                            setState(() {
                                              if (!_selectedSprints.contains(sid)) _selectedSprints.add(sid);
                                              _pendingSprintId = null;
                                            });
                                          },
                                    style: _primaryActionStyle(),
                                    child: const Text('Add', overflow: TextOverflow.ellipsis),
                                  ),
                                );

                                if (compact) {
                                  return Column(
                                    children: [
                                      dropdown,
                                      const SizedBox(height: 12),
                                      addButton,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: dropdown),
                                    const SizedBox(width: 12),
                                    addButton,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            if (selected.isEmpty)
                              Text(
                                'No sprints selected',
                                style: TextStyle(color: FlownetColors.pureWhite.withValues(alpha: 0.7)),
                              )
                            else
                              Container(
                                constraints: const BoxConstraints(maxHeight: 180),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: selected.length,
                                  itemBuilder: (context, index) {
                                    final sprint = selected[index];
                                    final sid = sprint['id']?.toString() ?? '';
                                    final name = sprint['name']?.toString() ?? 'Sprint';
                                    final status = sprint['status']?.toString() ?? '';
                                    return ListTile(
                                      dense: true,
                                      title: Text(name),
                                      subtitle: Text(status.isNotEmpty ? 'Status: $status' : ''),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _selectedSprints.remove(sid);
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              if (_selectedSprints.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_selectedSprints.length} sprint(s) selected',
                  style: const TextStyle(
                    color: _brandRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Definition of Done
              _buildSectionHeader('Definition of Done'),
              const SizedBox(height: 16),

              ..._definitionOfDone.map(
                (item) => Card(
                  color: FlownetColors.graphiteGray,
                  child: ListTile(
                    leading:
                        const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(item.text),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _definitionOfDone.remove(item);
                        });
                      },
                    ),
                  ),
                ),
              ),

              ElevatedButton.icon(
                onPressed: _addDoDItem,
                icon: const Icon(Icons.add),
                label: const Text('Add DoD Item'),
                style: _primaryActionStyle(),
              ),
              const SizedBox(height: 28),

              // Evidence Links
              _buildSectionHeader('Evidence & Artifacts'),
              const SizedBox(height: 16),

              ..._evidenceLinks.map(
                (link) => Card(
                  color: FlownetColors.graphiteGray,
                  child: ListTile(
                    leading: const Icon(Icons.link, color: _brandRed),
                    title: Text(link),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _evidenceLinks.remove(link);
                        });
                      },
                    ),
                  ),
                ),
              ),

              ElevatedButton.icon(
                onPressed: _addEvidenceLink,
                icon: const Icon(Icons.add),
                label: const Text('Add Evidence Link'),
                style: _primaryActionStyle(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _artifactDescriptionController,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Document description (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isSubmitting || _isUploadingArtifacts) ? null : _pickArtifactFiles,
                  icon: _isUploadingArtifacts
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload_file),
                  label: const Text('Upload document(s)'),
                  style: _primaryActionStyle(),
                ),
              ),
              if (_artifactFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._artifactFiles.map((f) {
                  final sizeKb = (f.size / 1024).toStringAsFixed(0);
                  return Card(
                    color: FlownetColors.graphiteGray,
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file, color: Colors.white70),
                      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('$sizeKb KB'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _artifactFiles.remove(f);
                          });
                        },
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 28),

              // AI-Powered Release Readiness Gate
              _buildSectionHeader('AI Release Readiness Gate'),
              const SizedBox(height: 16),

              Builder(
                builder: (context) {
                  debugPrint(
                      '📋 Creating AIReadinessGateWidget with title: "${_titleController.text}"');
                  return AIReadinessGateWidget(
                    key: ValueKey(
                        'ai-gate-${_titleController.text}-${_definitionOfDone.length}-${_evidenceLinks.length}'),
                    deliverableId:
                        'temp-${DateTime.now().millisecondsSinceEpoch}',
                    deliverableTitle: _titleController.text,
                    deliverableDescription: _descriptionController.text,
                    definitionOfDone:
                        _definitionOfDone.map((e) => e.text).toList(),
                    evidenceLinks: _evidenceLinks,
                    sprintIds: _selectedSprints,
                    knownLimitations: null,
                    onStatusChanged: (status) {
                      setState(() {
                        _currentReadinessStatus = status;
                      });
                    },
                    onInternalApprovalRequested: (comment) {
                      _requestInternalApproval(comment);
                    },
                  );
                },
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting ||
                          ((_currentReadinessStatus == ReadinessStatus.red ||
                                  _currentReadinessStatus ==
                                      ReadinessStatus.amber) &&
                              !_hasInternalApproval))
                      ? null
                      : _submitDeliverable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _currentReadinessStatus == ReadinessStatus.green
                            ? Colors.green
                            : _currentReadinessStatus == ReadinessStatus.amber
                                ? Colors.orange
                                : _hasInternalApproval
                                    ? _brandRed
                                    : _brandRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _currentReadinessStatus == ReadinessStatus.green
                              ? 'Create Deliverable'
                              : _currentReadinessStatus == ReadinessStatus.amber
                                  ? (_hasInternalApproval
                                      ? 'Create with Internal Approval'
                                      : 'Internal Approval Required')
                                  : _hasInternalApproval
                                      ? 'Create with Internal Approval'
                                      : 'Complete Required Items First',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: FlownetColors.pureWhite,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  ButtonStyle _primaryActionStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _brandRed,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }
}
