import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/project.dart';
import '../models/deliverable.dart';
import '../models/sprint.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/user_data_service.dart';
import '../services/backend_api_service.dart';
import '../providers/service_providers.dart';

class ProjectWorkspaceScreen extends ConsumerStatefulWidget {
  final String? projectId;

  const ProjectWorkspaceScreen({
    super.key,
    this.projectId,
  });

  @override
  ConsumerState<ProjectWorkspaceScreen> createState() =>
      _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState
    extends ConsumerState<ProjectWorkspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientProjectOwnerController = TextEditingController();
  final _tagsController = TextEditingController();

  ProjectStatus _selectedStatus = ProjectStatus.planning;
  ProjectPriority _selectedPriority = ProjectPriority.medium;
  String _selectedProjectType = 'software';
  DateTime? _startDate;
  DateTime? _endDate;

  List<ProjectMember> _members = [];
  List<String> _deliverableIds = [];
  List<String> _sprintIds = [];
  List<Deliverable> _availableDeliverables = [];
  List<Sprint> _availableSprints = [];
  List<User> _availableUsers = [];
  User? _selectedOwner;

  bool _isLoading = false;
  bool _isEditing = false;
  Project? _currentProject;
  bool _isSendingReminder = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadAvailableData();
    if (widget.projectId != null && widget.projectId != 'new') {
      _isEditing = true;
      await _loadProject();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    _clientProjectOwnerController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    if (widget.projectId == null || widget.projectId == 'new') return;

    setState(() => _isLoading = true);
    try {
      final project = await ApiService.getProject(widget.projectId!);
      if (project != null) {
        // First populate base fields
        setState(() {
          _currentProject = project;
          _nameController.text = project.name;
          _descriptionController.text = project.description;
          _clientNameController.text = project.clientName ?? '';
          _clientProjectOwnerController.text = project.clientOwnerName ?? '';
          _selectedStatus = project.status;
          _selectedPriority = project.priority;
          const validProjectTypes = [
            'software',
            'hardware',
            'research',
            'consulting',
            'other'
          ];
          _selectedProjectType = validProjectTypes.contains(project.projectType)
              ? project.projectType
              : 'other';
          _startDate = project.startDate;
          _endDate = project.endDate;
          _tagsController.text = project.tags.join(', ');
          _members = project.members;

          // Debug: Print member information
          debugPrint('=== PROJECT MEMBERS DEBUG ===');
          debugPrint('Project: ${project.name}');
          debugPrint('Members count: ${project.members.length}');
          for (var member in project.members) {
            debugPrint(
                '  - ${member.userName} (${member.userEmail}) - ${member.role}');
          }
          debugPrint('=============================');

          // Prefer IDs from project payload when present
          _deliverableIds = project.deliverableIds;
          _sprintIds = project.sprintIds;

          // Set selected owner
          try {
            if (project.ownerId != null) {
              _selectedOwner =
                  _availableUsers.firstWhere((u) => u.id == project.ownerId);
            } else {
              final ownerMember =
                  _members.firstWhere((m) => m.role == ProjectRole.owner);
              _selectedOwner =
                  _availableUsers.firstWhere((u) => u.id == ownerMember.userId);
            }
          } catch (_) {}
        });

        // If backend did not send deliverableIds, derive from deliverables that reference this project
        if (_deliverableIds.isEmpty && _availableDeliverables.isNotEmpty) {
          final derivedDeliverables = _availableDeliverables
              .where((d) => d.projectId == project.id)
              .map((d) => d.id)
              .toList();
          if (derivedDeliverables.isNotEmpty) {
            setState(() {
              _deliverableIds = derivedDeliverables;
            });
          }
        }

        // If backend did not send sprintIds, fetch sprints linked to this project
        if (_sprintIds.isEmpty) {
          try {
            final sprintMaps =
                await ApiService.getSprints(projectId: project.id);
            final ids = sprintMaps
                .map((s) => s['id']?.toString())
                .where((id) => id != null && id.isNotEmpty)
                .cast<String>()
                .toList();
            if (ids.isNotEmpty) {
              setState(() {
                _sprintIds = ids;
              });
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load project: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailableData() async {
    debugPrint('🔍 Starting to load available data for project workspace...');
    try {
      final deliverables = await ApiService.getDeliverables();
      final sprints = await ApiService.getSprints();

      // Try direct API call first - more reliable
      List<User> users = [];
      try {
        debugPrint('🔍 Trying direct API call for users...');
        final backend = BackendApiService();
        final response = await backend.getUsers(limit: 1000);

        if (response.isSuccess && response.data != null) {
          debugPrint(
              '✅ Direct API call successful - response type: ${response.data.runtimeType}');

          final responseData = response.data;
          List<dynamic> usersDataList = [];

          if (responseData is Map && responseData['users'] is List) {
            usersDataList = responseData['users'];
            debugPrint(
                '📦 Extracted ${usersDataList.length} users from users array');
          } else if (responseData is Map && responseData['data'] is List) {
            usersDataList = responseData['data'];
            debugPrint(
                '📦 Extracted ${usersDataList.length} users from data array');
          } else if (responseData is List) {
            usersDataList = responseData;
            debugPrint(
                '📦 Extracted ${usersDataList.length} users from direct list');
          }

          users = usersDataList.map((userData) {
            String displayName;
            if (userData['name'] != null &&
                userData['name'].toString().isNotEmpty) {
              displayName = userData['name'];
            } else if ((userData['first_name']?.toString().isNotEmpty ?? false) ||
                (userData['last_name']?.toString().isNotEmpty ?? false)) {
              displayName =
                  '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
                      .trim();
            } else {
              displayName = (userData['email'] ?? '').toString().trim();
            }

            // Parse role string to UserRole enum
            UserRole userRole = UserRole.teamMember; // default
            final roleString = userData['role']?.toString().toLowerCase();
            if (roleString != null) {
              switch (roleString) {
                case 'systemadmin':
                  userRole = UserRole.systemAdmin;
                  break;
                case 'projectmanager':
                  userRole = UserRole.projectManager;
                  break;
                case 'deliverylead':
                  userRole = UserRole.deliveryLead;
                  break;
                case 'developer':
                  userRole = UserRole.developer;
                  break;
                case 'qaengineer':
                  userRole = UserRole.qaEngineer;
                  break;
                case 'client':
                  userRole = UserRole.client;
                  break;
                case 'clientreviewer':
                  userRole = UserRole.clientReviewer;
                  break;
                case 'scrummaster':
                  userRole = UserRole.scrumMaster;
                  break;
                case 'stakeholder':
                  userRole = UserRole.stakeholder;
                  break;
                default:
                  userRole = UserRole.teamMember;
              }
            }

            debugPrint(
                '👤 Processing user: $displayName (${userData['id']}) - Role: ${userRole.name}');

            return User(
              id: userData['id'],
              email: userData['email'] ?? '',
              name: displayName,
              role: userRole,
              isActive: userData['is_active'] ?? userData['isActive'] ?? true,
              emailVerified: userData['emailVerified'] ?? true,
              createdAt: DateTime.tryParse(
                      userData['created_at'] ?? userData['createdAt'] ?? '') ??
                  DateTime.now(),
            );
          }).toList();

          debugPrint(
              '✅ Successfully processed ${users.length} users from direct API');
        } else {
          debugPrint('❌ Direct API call failed: ${response.error}');
          throw Exception('Direct API call failed');
        }
      } catch (e) {
        debugPrint('❌ Direct API call failed, trying UserDataService: $e');

        // Fallback to UserDataService
        try {
          users = await UserDataService().getUsers(limit: 1000);
          debugPrint(
              '✅ Successfully loaded ${users.length} users from UserDataService');
        } catch (e2) {
          debugPrint('❌ UserDataService also failed: $e2');
          users = [];
        }
      }

      setState(() {
        _availableDeliverables =
            deliverables.map((d) => Deliverable.fromJson(d)).toList();
        _availableSprints = sprints.map((s) => Sprint.fromJson(s)).toList();
        _availableUsers = users;

        debugPrint('📊 Final state: ${_availableUsers.length} users available');

        // Set default owner if creating new project
        if (!_isEditing && _selectedOwner == null) {
          final currentUserId = AuthService().currentUser?.id;
          if (currentUserId != null) {
            try {
              _selectedOwner =
                  _availableUsers.firstWhere((u) => u.id == currentUserId);
              debugPrint('✅ Set default owner: ${_selectedOwner?.name}');
            } catch (_) {
              debugPrint('⚠️ Current user not found in available users');
            }
          }
        }

        debugPrint(
            '✅ Loaded ${_availableUsers.length} available users for project owner selection');
        for (final user in _availableUsers) {
          debugPrint('  - ${user.name} (${user.id}) - ${user.role.name}');
        }
      });
    } catch (e) {
      debugPrint('❌ Failed to load available data: $e');
      _showErrorSnackBar('Failed to load available data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _generateProjectKey(String projectName) {
    // Remove spaces and special characters, convert to uppercase
    final String cleanName = projectName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Take first 3-4 letters of each word
    final List<String> words = cleanName.split(' ');
    String key = '';

    for (String word in words) {
      if (word.isNotEmpty) {
        key += word.length >= 3
            ? word.substring(0, 3).toUpperCase()
            : word.toUpperCase();
      }
    }

    // Limit to 10 characters and ensure it starts with a letter
    if (key.length > 10) {
      key = key.substring(0, 10);
    }

    // If key is empty or doesn't start with a letter, use a default
    if (key.isEmpty || !RegExp(r'^[A-Z]').hasMatch(key)) {
      key =
          'PRJ${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }

    return key;
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('💾 Saving project with dates:');
      debugPrint('  Start Date: $_startDate');
      debugPrint('  End Date: $_endDate');

      final project = Project(
        id: _isEditing
            ? _currentProject!.id
            : DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        key: _isEditing
            ? _currentProject!.key
            : _generateProjectKey(_nameController.text.trim()),
        description: _descriptionController.text.trim(),
        clientName: _clientNameController.text.trim().isEmpty
            ? null
            : _clientNameController.text.trim(),
        clientOwnerName: _clientProjectOwnerController.text.trim().isEmpty
            ? null
            : _clientProjectOwnerController.text.trim(),
        status: _selectedStatus,
        priority: _selectedPriority,
        projectType: _selectedProjectType,
        startDate: _startDate ?? DateTime.now(),
        endDate: _endDate,
        tags: _tagsController.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        members: _members,
        deliverableIds: _deliverableIds,
        sprintIds: _sprintIds,
        createdBy: AuthService().currentUser?.id ?? 'unknown',
        createdAt: _isEditing ? _currentProject!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
        updatedBy: AuthService().currentUser?.id ?? 'unknown',
        ownerId: _selectedOwner?.id,
      );

      if (_isEditing) {
        final updateSuccess = await ApiService.updateProject(project);

        if (updateSuccess) {
          // Update the current project data with the new values
          setState(() {
            _currentProject = project;
          });

          try {
            // Link selected deliverables to this project by updating their project_id
            for (final deliverableId in _deliverableIds) {
              await ApiService.linkDeliverableToProject(
                  project.id, deliverableId);
            }

            if (_sprintIds.isNotEmpty) {
              await ApiService.associateSprintWithProject(
                  project.id, _sprintIds);
            }
          } catch (_) {}

          _showSuccessSnackBar('Project updated successfully');
        } else {
          _showErrorSnackBar('Failed to update project');
        }
      } else {
        final createdProject = await ApiService.createProjectModel(project);

        if (createdProject != null) {
          try {
            for (final deliverableId in _deliverableIds) {
              await ApiService.linkDeliverableToProject(
                  createdProject.id, deliverableId);
            }

            if (_sprintIds.isNotEmpty) {
              await ApiService.associateSprintWithProject(
                  createdProject.id, _sprintIds);
            }
          } catch (_) {}
        }

        _showSuccessSnackBar('Project created successfully');
      }

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          } else {
            if (_isEditing) {
              // Force refresh by adding timestamp to URL
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              context.go('/project-workspace/${project.id}?refresh=$timestamp');
            } else {
              context.go('/projects');
            }
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save project: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openMemberSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _SelectMembersDialog(
        availableUsers: _availableUsers,
        selectedUserIds: _members.map((m) => m.userId).toList(),
        onSelect: (selectedUsers) {
          setState(() {
            // Keep existing members who are still selected
            final existingMembers = _members
                .where((m) => selectedUsers.any((u) => u.id == m.userId))
                .toList();

            // Add new members
            for (var user in selectedUsers) {
              if (!existingMembers.any((m) => m.userId == user.id)) {
                existingMembers.add(ProjectMember(
                  userId: user.id,
                  userName: user.name,
                  userEmail: user.email,
                  role: ProjectRole.contributor, // Default role
                  assignedAt: DateTime.now(),
                ));
              }
            }
            _members = existingMembers;
          });
        },
      ),
    );
  }

  void _removeMember(String userId) {
    setState(() {
      _members.removeWhere((m) => m.userId == userId);
    });
  }

  void _addDeliverable() {
    showDialog(
      context: context,
      builder: (context) => _SelectDeliverablesDialog(
        availableDeliverables: _availableDeliverables,
        selectedIds: _deliverableIds,
        onSelect: (ids) {
          setState(() {
            _deliverableIds = ids;
          });
        },
      ),
    );
  }

  void _addSprint() {
    showDialog(
      context: context,
      builder: (context) => _SelectSprintsDialog(
        availableSprints: _availableSprints,
        selectedIds: _sprintIds,
        onSelect: (ids) {
          setState(() {
            _sprintIds = ids;
          });
        },
      ),
    );
  }

  Future<void> _sendDueDateReminder() async {
    if (!_isEditing || _currentProject == null) {
      return;
    }
    if (_selectedOwner == null) {
      _showErrorSnackBar('Assign a project owner before sending a reminder.');
      return;
    }
    if (_endDate == null) {
      _showErrorSnackBar('Set an end date before sending a reminder.');
      return;
    }
    final now = DateTime.now();
    if (_endDate!.isAfter(now)) {
      _showErrorSnackBar(
          'Reminder is only available when the project has reached or passed its end date.');
      return;
    }
    if (_selectedStatus == ProjectStatus.completed ||
        _selectedStatus == ProjectStatus.cancelled) {
      _showErrorSnackBar('Project is already completed or cancelled.');
      return;
    }
    setState(() {
      _isSendingReminder = true;
    });
    try {
      final backend = ref.read(backendApiServiceProvider);
      final response = await backend.remindProjectOwner(_currentProject!.id);
      if (response.isSuccess) {
        _showSuccessSnackBar('Reminder sent to project owner.');
      } else {
        _showErrorSnackBar(response.error ?? 'Failed to send reminder.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send reminder: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReminder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Project' : 'Create New Project',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoSection(colorScheme),
                    const SizedBox(height: 24),
                    _buildMetadataSection(colorScheme),
                    const SizedBox(height: 24),
                    _buildDatesSection(colorScheme),
                    const SizedBox(height: 24),
                    _buildMembersSection(colorScheme),
                    const SizedBox(height: 24),
                    _buildDeliverablesSection(colorScheme),
                    const SizedBox(height: 24),
                    _buildSprintsSection(colorScheme),
                    const SizedBox(height: 32),
                    _buildActionButtons(colorScheme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBasicInfoSection(ColorScheme colorScheme) {
    return GlassCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.primary.withAlpha(20),
          colorScheme.secondary.withAlpha(10),
        ],
      ),
      border: Border.all(
        color: colorScheme.primary.withAlpha(40),
        width: 1.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Project Name *',
              hintText: 'Enter project name',
              prefixIcon: Icon(Icons.work_outline, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(100)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(50)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface.withAlpha(100),
            ),
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Project name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description *',
              hintText: 'Describe the project goals and objectives',
              prefixIcon:
                  Icon(Icons.description_outlined, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(100)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(50)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface.withAlpha(100),
            ),
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Description is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _clientNameController,
            decoration: InputDecoration(
              labelText: 'Client Name',
              hintText: 'Enter client or customer name',
              prefixIcon:
                  Icon(Icons.business_outlined, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(100)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(50)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface.withAlpha(100),
            ),
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _clientProjectOwnerController,
            decoration: InputDecoration(
              labelText: 'Project Owner (Client Side)',
              hintText: 'Enter client-side project owner',
              prefixIcon:
                  Icon(Icons.badge_outlined, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(100)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(50)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface.withAlpha(100),
            ),
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<User>(
            // ignore: deprecated_member_use
            value: _selectedOwner,
            // Allow owner selection for System Admins or during editing
            onChanged: (value) {
              setState(() {
                _selectedOwner = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'Project Manager *',
              prefixIcon:
                  Icon(Icons.person_outline, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(100)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(50)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: _isEditing
                  ? colorScheme.surface.withAlpha(100)
                  : colorScheme.surface
                      .withAlpha(50), // Visual cue for disabled state
            ),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
            items: _availableUsers.map((user) {
              return DropdownMenuItem(
                value: user,
                child: Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            validator: (value) {
              if (value == null) {
                return 'Project manager is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(ColorScheme colorScheme) {
    return GlassCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.secondary.withAlpha(20),
          colorScheme.tertiary.withAlpha(10),
        ],
      ),
      border: Border.all(
        color: colorScheme.secondary.withAlpha(40),
        width: 1.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_outlined,
                color: colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Project Metadata',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<ProjectStatus>(
            initialValue: _selectedStatus,
            decoration: InputDecoration(
              labelText: 'Status',
              prefixIcon:
                  Icon(Icons.flag_outlined, color: colorScheme.secondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(100)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(50)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.secondary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface.withAlpha(100),
            ),
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
            items: ProjectStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(status.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedStatus = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ProjectPriority>(
            initialValue: _selectedPriority,
            decoration: InputDecoration(
              labelText: 'Priority',
              prefixIcon: Icon(Icons.priority_high_outlined,
                  color: colorScheme.secondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(100)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(50)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.secondary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface.withAlpha(100),
            ),
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
            items: ProjectPriority.values.map((priority) {
              return DropdownMenuItem(
                value: priority,
                child: Text(priority.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPriority = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: const [
              'software',
              'hardware',
              'research',
              'consulting',
              'other'
            ].contains(_selectedProjectType)
                ? _selectedProjectType
                : null,
            decoration: InputDecoration(
              labelText: 'Project Type',
              prefixIcon:
                  Icon(Icons.category_outlined, color: colorScheme.secondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(100)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(50)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.secondary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface.withAlpha(100),
            ),
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
            items: const [
              DropdownMenuItem(value: 'software', child: Text('Software')),
              DropdownMenuItem(value: 'hardware', child: Text('Hardware')),
              DropdownMenuItem(value: 'research', child: Text('Research')),
              DropdownMenuItem(value: 'consulting', child: Text('Consulting')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedProjectType = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _tagsController,
            decoration: InputDecoration(
              labelText: 'Tags (comma-separated)',
              hintText: 'e.g. mobile, frontend, urgent',
              prefixIcon:
                  Icon(Icons.tag_outlined, color: colorScheme.secondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(100)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.outline.withAlpha(50)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.secondary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface.withAlpha(100),
              helperText: 'Enter tags separated by commas',
            ),
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesSection(ColorScheme colorScheme) {
    return GlassCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.tertiary.withAlpha(20),
          colorScheme.primary.withAlpha(10),
        ],
      ),
      border: Border.all(
        color: colorScheme.tertiary.withAlpha(40),
        width: 1.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.date_range_outlined,
                color: colorScheme.tertiary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Project Dates',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withAlpha(50),
              ),
              color: colorScheme.surface.withAlpha(100),
            ),
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: colorScheme.tertiary),
              title: Text(
                'Start Date',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                _currentProject?.formattedStartDate ?? 'Not set',
                style: TextStyle(
                  color: colorScheme.onSurface.withAlpha(180),
                ),
              ),
              trailing:
                  Icon(Icons.arrow_drop_down, color: colorScheme.tertiary),
              onTap: () async {
                debugPrint('🗓️ Start date picker opened');
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  debugPrint('🗓️ Start date selected: $date');
                  setState(() {
                    _startDate = date;
                    debugPrint('🗓️ _startDate updated to: $_startDate');
                  });
                } else {
                  debugPrint('🗓️ Start date selection cancelled');
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withAlpha(50),
              ),
              color: colorScheme.surface.withAlpha(100),
            ),
            child: ListTile(
              leading: Icon(Icons.event_outlined, color: colorScheme.tertiary),
              title: Text(
                'End Date',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                _currentProject?.formattedEndDate ?? 'Not set',
                style: TextStyle(
                  color: colorScheme.onSurface.withAlpha(180),
                ),
              ),
              trailing:
                  Icon(Icons.arrow_drop_down, color: colorScheme.tertiary),
              onTap: () async {
                debugPrint('🗓️ End date picker opened');
                final date = await showDatePicker(
                  context: context,
                  initialDate:
                      _endDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  debugPrint('🗓️ End date selected: $date');
                  setState(() {
                    _endDate = date;
                    debugPrint('🗓️ _endDate updated to: $_endDate');
                  });
                } else {
                  debugPrint('🗓️ End date selection cancelled');
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          if (_isEditing &&
              _currentProject != null &&
              _selectedOwner != null &&
              _endDate != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isSendingReminder ? null : _sendDueDateReminder,
                icon: _isSendingReminder
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary),
                        ),
                      )
                    : Icon(
                        Icons.notifications_active_outlined,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                label: Text(
                  'Remind Project Owner',
                  style: TextStyle(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(ColorScheme colorScheme) {
    final currentUserId = AuthService().currentUser?.id;
    final isOwner =
        _selectedOwner?.id != null && _selectedOwner!.id == currentUserId;
    // Allow member assignment if it's a new project or if the current user is the owner
    // User requirement: "only the project owner can assign users to projects."
    final canAssignMembers = !_isEditing || isOwner;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                'Team Members',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!canAssignMembers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Only the project owner can assign members.',
                style: TextStyle(
                    color: colorScheme.error, fontStyle: FontStyle.italic),
              ),
            ),
          InkWell(
            onTap: canAssignMembers ? _openMemberSelectionDialog : null,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Assign Members',
                prefixIcon: Icon(Icons.group_add_outlined,
                    color: canAssignMembers
                        ? colorScheme.primary
                        : colorScheme.outline),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabled: canAssignMembers,
                filled: true,
                fillColor: canAssignMembers
                    ? colorScheme.surface.withAlpha(100)
                    : colorScheme.surface.withAlpha(50),
                suffixIcon: Icon(Icons.arrow_drop_down,
                    color: canAssignMembers
                        ? colorScheme.primary
                        : colorScheme.outline),
              ),
              child: _members.isEmpty
                  ? Text('Select members...',
                      style: TextStyle(
                          color: colorScheme.onSurface.withAlpha(100)))
                  : Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: _members
                          .map((member) => Chip(
                                label: Text(member.userName),
                                onDeleted: canAssignMembers
                                    ? () => _removeMember(member.userId)
                                    : null,
                              ))
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverablesSection(ColorScheme colorScheme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Linked Deliverables',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: _addDeliverable,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_deliverableIds.isEmpty)
            const Text('No deliverables linked yet')
          else
            ..._deliverableIds.map((id) {
              final deliverable = _availableDeliverables.firstWhere(
                (d) => d.id == id,
                orElse: () => Deliverable(
                  id: id,
                  title: 'Unknown',
                  description: '',
                  status: DeliverableStatus.draft,
                  createdAt: DateTime.now(),
                  dueDate: DateTime.now(),
                  sprintIds: [],
                  definitionOfDone: [],
                ),
              );
              return ListTile(
                onTap: () {
                  GoRouter.of(context)
                      .push('/deliverable-detail', extra: deliverable);
                },
                title: Text(deliverable.title),
                subtitle: Text(deliverable.statusDisplayName),
                trailing: IconButton(
                  onPressed: () {
                    setState(() {
                      _deliverableIds.remove(id);
                    });
                  },
                  icon: const Icon(Icons.remove, color: Colors.red),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSprintsSection(ColorScheme colorScheme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Associated Sprints',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: _addSprint,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_sprintIds.isEmpty)
            const Text('No sprints associated yet')
          else
            ..._sprintIds.map((id) {
              final sprint = _availableSprints.firstWhere(
                (s) => s.id == id,
                orElse: () => Sprint(
                  id: id,
                  name: 'Unknown',
                  startDate: DateTime.now(),
                  endDate: DateTime.now(),
                  committedPoints: 0,
                  completedPoints: 0,
                  velocity: 0,
                  testPassRate: 0.0,
                  defectCount: 0,
                ),
              );
              return ListTile(
                onTap: () {
                  final projectId = widget.projectId;
                  final sprintId = sprint.id;

                  if (sprintId.isNotEmpty) {
                    final queryParams = <String, String>{
                      'sprintId': sprintId,
                    };
                    if (projectId != null &&
                        projectId.isNotEmpty &&
                        projectId != 'new') {
                      queryParams['projectId'] = projectId;
                    }
                    final uri = Uri(
                        path: '/sprint-console', queryParameters: queryParams);
                    context.go(uri.toString());
                  } else {
                    context.go('/sprint-console');
                  }
                },
                title: Text(sprint.name),
                subtitle: Text(sprint.statusText),
                trailing: IconButton(
                  onPressed: () {
                    setState(() {
                      _sprintIds.remove(id);
                    });
                  },
                  icon: const Icon(Icons.remove, color: Colors.red),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return GlassCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.primary.withAlpha(30),
          colorScheme.secondary.withAlpha(20),
        ],
      ),
      border: Border.all(
        color: colorScheme.primary.withAlpha(50),
        width: 1.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProject,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.onPrimary),
                      ),
                    )
                  : _isEditing
                      ? const Text(
                          'Update Project',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const Text(
                          'Create Project',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/projects');
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outline),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectMembersDialog extends StatefulWidget {
  final List<User> availableUsers;
  final List<String> selectedUserIds;
  final Function(List<User>) onSelect;

  const _SelectMembersDialog({
    required this.availableUsers,
    required this.selectedUserIds,
    required this.onSelect,
  });

  @override
  State<_SelectMembersDialog> createState() => _SelectMembersDialogState();
}

class _SelectMembersDialogState extends State<_SelectMembersDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedUserIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Team Members'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: widget.availableUsers.length,
          itemBuilder: (context, index) {
            final user = widget.availableUsers[index];
            final isSelected = _selectedIds.contains(user.id);

            return CheckboxListTile(
              title: Text(user.name),
              subtitle: Text(user.email),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.add(user.id);
                  } else {
                    _selectedIds.remove(user.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final selectedUsers = widget.availableUsers
                .where((u) => _selectedIds.contains(u.id))
                .toList();
            widget.onSelect(selectedUsers);
            Navigator.of(context).pop();
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}

class _SelectDeliverablesDialog extends StatefulWidget {
  final List<Deliverable> availableDeliverables;
  final List<String> selectedIds;
  final Function(List<String>) onSelect;

  const _SelectDeliverablesDialog({
    required this.availableDeliverables,
    required this.selectedIds,
    required this.onSelect,
  });

  @override
  State<_SelectDeliverablesDialog> createState() =>
      _SelectDeliverablesDialogState();
}

class _SelectDeliverablesDialogState extends State<_SelectDeliverablesDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Deliverables'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: widget.availableDeliverables.length,
          itemBuilder: (context, index) {
            final deliverable = widget.availableDeliverables[index];
            final isSelected = _selectedIds.contains(deliverable.id);

            return CheckboxListTile(
              title: Text(deliverable.title),
              subtitle: Text(deliverable.statusDisplayName),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.add(deliverable.id);
                  } else {
                    _selectedIds.remove(deliverable.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSelect(_selectedIds.toList());
            Navigator.of(context).pop();
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}

class _SelectSprintsDialog extends StatefulWidget {
  final List<Sprint> availableSprints;
  final List<String> selectedIds;
  final Function(List<String>) onSelect;

  const _SelectSprintsDialog({
    required this.availableSprints,
    required this.selectedIds,
    required this.onSelect,
  });

  @override
  State<_SelectSprintsDialog> createState() => _SelectSprintsDialogState();
}

class _SelectSprintsDialogState extends State<_SelectSprintsDialog> {
  late Set<String> _selectedIds;
  String? _pendingSprintId;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.availableSprints
        .where((s) => !_selectedIds.contains(s.id))
        .toList();
    final selected = widget.availableSprints
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    return AlertDialog(
      title: const Text('Select Sprints'),
      content: SizedBox(
        width: double.maxFinite,
        height: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: remaining.any((s) => s.id == _pendingSprintId)
                        ? _pendingSprintId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Add sprint',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Select sprint'),
                      ),
                      ...remaining.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _pendingSprintId = v),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: (_pendingSprintId == null)
                      ? null
                      : () {
                          final id = _pendingSprintId;
                          if (id == null || id.isEmpty) return;
                          setState(() {
                            _selectedIds.add(id);
                            _pendingSprintId = null;
                          });
                        },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: selected.isEmpty
                  ? const Center(child: Text('No sprints selected'))
                  : ListView.builder(
                      itemCount: selected.length,
                      itemBuilder: (context, index) {
                        final sprint = selected[index];
                        return ListTile(
                          dense: true,
                          title: Text(sprint.name),
                          subtitle: Text(sprint.statusText),
                          trailing: IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedIds.remove(sprint.id);
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSelect(_selectedIds.toList());
            Navigator.of(context).pop();
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
