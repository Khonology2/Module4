import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../models/deliverable.dart';
import '../services/deliverable_service.dart';
import '../services/backend_api_service.dart';
import '../services/user_data_service.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';

class DeliverableSetupScreen extends ConsumerStatefulWidget {
  const DeliverableSetupScreen({super.key});

  @override
  ConsumerState<DeliverableSetupScreen> createState() =>
      _DeliverableSetupScreenState();
}

class _DeliverableSetupScreenState
    extends ConsumerState<DeliverableSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dodController = TextEditingController();
  final _evidenceLinksController = TextEditingController();
  final _artifactDescriptionController = TextEditingController();
  final _deliverableService = DeliverableService();

  String _priority = 'medium';
  String _status = 'draft';
  DateTime? _dueDate;
  final List<String> _selectedSprints = [];
  String? _pendingSprintId;
  List<Map<String, dynamic>> _availableSprints = [];
  final List<PlatformFile> _artifactFiles = [];
  List<Map<String, dynamic>> _users = [];
  String? _ownerId;
  String? _selectedProjectId;
  List<Map<String, dynamic>> _projects = [];
  bool _isSaving = false;
  bool _isGenerating = false;
  bool _isLoadingUsers = false;
  bool _isUploadingArtifacts = false;

  @override
  void initState() {
    super.initState();
    try {
      final uid = AuthService().currentUser?.id;
      if (uid != null && ( _ownerId == null || _ownerId!.isEmpty)) {
        _ownerId = uid;
      }
    } catch (_) {}
    _loadSprints();
    _loadUsers();
    _loadProjects();
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
          projectsList =
              data['data'] as List? ?? data['projects'] as List? ?? [];
        }

        setState(() {
          _projects = projectsList
              .where((p) => p != null)
              .map((p) =>
                  p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{})
              .where((m) => m.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      debugPrint('🔍 Loading users for deliverable assignment...');
      final List<User> users = await UserDataService().getUsers(limit: 1000);
      debugPrint('✅ Successfully loaded ${users.length} users from backend');
      setState(() {
        _users = users
            .map((user) {
              // Handle name construction properly
              String displayName = user.name.trim();

              // Fallback to email if name is empty
              if (displayName.isEmpty) {
                displayName = user.email.trim();
              }

              debugPrint('👤 Processed user: $displayName (${user.email})');

              return {
                'id': user.id,
                'name': displayName,
                'email': user.email,
                'role': user.role.name,
                'originalRole': user.role.name,
                'isActive': user.isActive,
                'emailVerified': user.emailVerified,
              };
            })
            .where((user) => user['isActive'] == true)
            .toList();
        _isLoadingUsers = false;
      });
      debugPrint(
          '✅ Processed ${_users.length} active users for deliverable assignment');

      // Debug: Print user data for verification
      for (final user in _users) {
        debugPrint(
            '  👤 ${user["name"]} (${user["email"]}) - Role: ${user["role"]}');
      }
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      debugPrint('❌ Error loading users: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users. Please check your connection and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadSprints() async {
    try {
      debugPrint('📦 Loading sprints...');
      // Use BackendApiService for sprints
      final backendApiService = BackendApiService();
      final response = await backendApiService.getSprints();

      debugPrint(
          '📦 Sprint response: isSuccess=${response.isSuccess}, data=${response.data}');

      if (response.isSuccess && response.data != null) {
        List<dynamic> sprintsList = [];

        if (response.data is List) {
          sprintsList = response.data as List;
        } else if (response.data is Map) {
          final data = response.data as Map<String, dynamic>;
          sprintsList = data['data'] as List? ?? data['sprints'] as List? ?? [];
        }

        debugPrint('📦 Parsed sprints list: ${sprintsList.length} items');

        setState(() {
          _availableSprints = sprintsList
              .where((s) => s != null) // Filter out nulls
              .map((s) {
                if (s is Map<String, dynamic>) {
                  return s;
                } else if (s is Map) {
                  return Map<String, dynamic>.from(s);
                } else {
                  debugPrint('⚠️ Unexpected sprint type: ${s.runtimeType}');
                  return <String, dynamic>{};
                }
              })
              .where((m) => m.isNotEmpty) // Filter out empty maps
              .toList();
        });
        debugPrint('✅ Loaded ${_availableSprints.length} sprints');
      } else {
        setState(() {
          _availableSprints = [];
        });
        debugPrint('⚠️ No sprints found: ${response.error ?? "Unknown error"}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading sprints: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      setState(() {
        _availableSprints = [];
      });
    }
  }

  Future<void> _generateTitleSuggestion() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final messages = [
        {
          'role': 'system',
          'content':
              'Write a concise professional deliverable title. Max 12 words.'
        },
        {
          'role': 'user',
          'content':
              'Description: ${_descriptionController.text}\nPriority: $_priority\nDue: ${_dueDate?.toIso8601String() ?? ''}\nSprints: ${_selectedSprints.join(', ')}'
        }
      ];
      final resp = await BackendApiService()
          .aiChat(messages, temperature: 0.6, maxTokens: 40);
      if (resp.isSuccess && resp.data != null) {
        final data =
            resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : {};
        final content =
            (data['content'] ?? (data['data']?['content']))?.toString() ?? '';
        if (content.isNotEmpty) {
          _titleController.text = content.trim();
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateDescriptionSuggestion() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final messages = [
        {
          'role': 'system',
          'content':
              'Write a clear deliverable description summarizing scope, outcomes, and constraints.'
        },
        {
          'role': 'user',
          'content':
              'Title: ${_titleController.text}\nPriority: $_priority\nDue: ${_dueDate?.toIso8601String() ?? ''}\nSprints: ${_selectedSprints.join(', ')}\nDefinition of Done: ${_dodController.text}'
        }
      ];
      final resp = await BackendApiService()
          .aiChat(messages, temperature: 0.7, maxTokens: 160);
      if (resp.isSuccess && resp.data != null) {
        final data =
            resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : {};
        final content =
            (data['content'] ?? (data['data']?['content']))?.toString() ?? '';
        if (content.isNotEmpty) {
          _descriptionController.text = content.trim();
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateDodSuggestion() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final messages = [
        {
          'role': 'system',
          'content':
              'Propose 5-8 acceptance criteria as a checklist, one per line.'
        },
        {
          'role': 'user',
          'content':
              'Title: ${_titleController.text}\nDescription: ${_descriptionController.text}'
        }
      ];
      final resp = await BackendApiService()
          .aiChat(messages, temperature: 0.7, maxTokens: 200);
      if (resp.isSuccess && resp.data != null) {
        final data =
            resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : {};
        final content =
            (data['content'] ?? (data['data']?['content']))?.toString() ?? '';
        if (content.isNotEmpty) {
          _dodController.text = content.trim();
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
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

  Future<void> _saveDeliverable() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      debugPrint('📦 Creating deliverable: ${_titleController.text}');

      // Use DeliverableService which handles authentication automatically
      final response = await _deliverableService.createDeliverable(
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        definitionOfDone: _dodController.text.isEmpty
            ? null
            : _dodController.text
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .map((s) => DoDItem(text: s))
                .toList(),
        priority: _priority,
        status: _status,
        dueDate: _dueDate,
        sprintIds: _selectedSprints,
        ownerId: _ownerId,
        projectId: _selectedProjectId,
        evidenceLinks: _evidenceLinksController.text
            .split(RegExp(r'[,\n]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );

      if (!mounted) return;

      if (!response.isSuccess) {
        setState(() => _isSaving = false);
        
        if (response.isSuccess) {
          try {
            Deliverable? created;
            if (response.data is Map<String, dynamic>) {
              final m = response.data as Map<String, dynamic>;
              if (m['deliverable'] is Deliverable) {
                created = m['deliverable'] as Deliverable;
              } else if (m['deliverable'] is Map) {
                created = Deliverable.fromJson(Map<String, dynamic>.from(m['deliverable'] as Map));
              } else if (m['id'] != null) {
                created = Deliverable(
                  id: m['id'].toString(),
                  title: _titleController.text,
                  description: _descriptionController.text,
                  definitionOfDone: _dodController.text.split('\n')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .map((s) => DoDItem(text: s))
                      .toList(),
                  priority: _priority,
                  status: DeliverableStatus.values.firstWhere(
                    (e) => e.name == _status, 
                    orElse: () => DeliverableStatus.draft
                  ),
                  dueDate: _dueDate ?? DateTime.now(),
                  createdBy: '',
                  assignedTo: null,
                  sprintIds: _selectedSprints,
                  projectId: _selectedProjectId,
                  createdByName: null,
                  assignedToName: null,
                  createdAt: DateTime.now(),
                  evidenceLinks: _evidenceLinksController.text.isNotEmpty 
                      ? _evidenceLinksController.text.split(',').map((e) => e.trim()).toList() 
                      : [],
                );
              }

              if (created != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Deliverable "${created.title}" created'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
                try {
                  GoRouter.of(context).go('/report-editor/${created.id}');
                } catch (_) {
                  Navigator.of(context).pushNamed('/report-editor/${created.id}');
                }
              }
            }

            _titleController.clear();
            _descriptionController.clear();
            _dodController.clear();
            _evidenceLinksController.clear();
            setState(() {
              _dueDate = null;
              _selectedSprints.clear();
            });
          } catch (_) {}
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to create deliverable: ${response.error ?? "Unknown error"}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating deliverable: $e');
      debugPrint('📚 Stack trace: $stackTrace');

      if (mounted) {
        setState(() => _isSaving = false);
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
          const SnackBar(content: Text('JSON files cannot be uploaded.'), backgroundColor: Colors.red),
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
          SnackBar(content: Text('Uploaded $ok document(s)'), backgroundColor: Colors.green),
        );
      } else if (ok > 0 && failed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded $ok document(s), $failed failed'), backgroundColor: Colors.orange),
        );
      } else if (failed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failed document upload(s) failed'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingArtifacts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Deliverable'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Deliverable Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isGenerating ? null : _generateTitleSuggestion,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Suggest with AI'),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      _isGenerating ? null : _generateDescriptionSuggestion,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Suggest with AI'),
                ),
              ),
              const SizedBox(height: 16),

              // Definition of Done
              TextFormField(
                controller: _dodController,
                decoration: const InputDecoration(
                  labelText: 'Definition of Done',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.checklist),
                  hintText: 'Enter the acceptance criteria...',
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the definition of done';
                  }
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isGenerating ? null : _generateDodSuggestion,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Suggest with AI'),
                ),
              ),
              const SizedBox(height: 16),

              // Owner
              DropdownButtonFormField<String>(
                initialValue: _ownerId,
                decoration: InputDecoration(
                  labelText: 'Owner',
                  border: OutlineInputBorder(),
                  prefixIcon: _isLoadingUsers 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.person),
                  helperText: _isLoadingUsers 
                    ? 'Loading users...' 
                    : 'Select the team member responsible for this deliverable',
                  suffixIcon: _users.isEmpty && !_isLoadingUsers
                    ? IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: _loadUsers,
                        tooltip: 'Retry loading users',
                      )
                    : null,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  if (!_isLoadingUsers && _users.isNotEmpty)
                    ..._users.map((user) {
                      String name = user['name'] ?? '';
                      if (name.isEmpty) {
                        name = user['email'] ?? 'Unknown';
                      }

                      final role = user['role']?.toString() ?? '';
                      if (role.isNotEmpty) {
                        name = '$name ($role)';
                      }

                      return DropdownMenuItem<String>(
                        value: user['id'].toString(),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: user['isActive'] == true
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: user['isActive'] == true
                                      ? null
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            if (user['emailVerified'] == true)
                              const Icon(
                                Icons.verified,
                                size: 16,
                                color: Colors.blue,
                              ),
                          ],
                        ),
                      );
                    }),
                ],
                onChanged: _isLoadingUsers
                    ? null
                    : (value) {
                        setState(() {
                          _ownerId = value;
                        });
                      },
                validator: (value) {
                  if (_status != 'draft' && (value == null || value.isEmpty)) {
                    return 'Owner must be selected before deliverable is marked Active/In Progress';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Project
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedProjectId,
                decoration: const InputDecoration(
                  labelText: 'Assign Project *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder),
                  helperText: 'Select the project this deliverable belongs to',
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(_projects.isEmpty
                        ? 'No projects available'
                        : 'Select Project'),
                  ),
                  ..._projects.map((project) {
                    final name =
                        project['name'] ?? project['key'] ?? 'Unknown Project';
                    return DropdownMenuItem<String>(
                      value: project['id'].toString(),
                      child: Text(name),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProjectId = value;
                    if (value != null && value.isNotEmpty) {
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
                    return 'Please assign a project';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Priority and Status Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.priority_high),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                            value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                            value: 'critical', child: Text('Critical')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _priority = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(
                            value: 'in_progress', child: Text('In Progress')),
                        DropdownMenuItem(
                            value: 'review', child: Text('Review')),
                        DropdownMenuItem(
                            value: 'completed', child: Text('Completed')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _status = value!;
                        });
                      },
                    ),
                  ),
                ],
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
              const SizedBox(height: 16),

              // Evidence Links
              TextFormField(
                controller: _evidenceLinksController,
                decoration: const InputDecoration(
                  labelText: 'Evidence Links',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                  hintText: 'Demo link, repo, test summary, user guide...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _artifactDescriptionController,
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
                  onPressed: (_isSaving || _isUploadingArtifacts) ? null : _pickArtifactFiles,
                  icon: _isUploadingArtifacts
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload_file),
                  label: const Text('Upload document(s)'),
                ),
              ),
              if (_artifactFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._artifactFiles.map((f) {
                  final sizeKb = (f.size / 1024).toStringAsFixed(0);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file),
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

              // Sprint Selection
              const Text(
                'Contributing Sprints',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: _availableSprints.map((sprint) {
                    final idStr = (sprint['id'] ?? '').toString();
                    final isSelected = _selectedSprints.contains(idStr);
                    return CheckboxListTile(
                      title: Text(sprint['name']?.toString() ?? ''),
                      subtitle: Text('${sprint['start_date']} - ${sprint['end_date']}'),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            if (!_selectedSprints.contains(idStr)) {
                              _selectedSprints.add(idStr);
                            }
                          } else {
                            _selectedSprints.remove(idStr);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDeliverable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Deliverable',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dodController.dispose();
    _evidenceLinksController.dispose();
    super.dispose();
  }
}