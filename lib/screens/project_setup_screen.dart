import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../services/project_service.dart';
import '../services/user_data_service.dart';
import '../services/backend_api_service.dart';
import '../widgets/glass_card.dart';

class ProjectSetupScreen extends StatefulWidget {
  final String? projectId;

  const ProjectSetupScreen({super.key, this.projectId}) : super();

  @override
  ProjectSetupScreenState createState() => ProjectSetupScreenState();
}

class ProjectSetupScreenState extends State<ProjectSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _keyController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedProjectType = 'Fixed Scope';
  ProjectStatus _selectedStatus = ProjectStatus.planning;
  ProjectPriority _selectedPriority = ProjectPriority.medium;

  bool _isLoading = false;
  bool _isEditing = false;
  Project? _originalProject;

  final List<String> _projectTypes = [
    'Fixed Scope',
    'Time & Materials',
    'Support / Maintenance',
    'Internal',
  ];

  final List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoadingUsers = false;
  Map<String, dynamic>? _selectedProjectOwner;

  final Map<String, String?> _validationErrors = {
    'name': null,
    'key': null,
    'description': null,
    'clientName': null,
    'startDate': null,
    'endDate': null,
  };

  @override
  void initState() {
    super.initState();
    // Initialize default dates for new projects
    if (widget.projectId == null) {
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 30));
    }
    _isEditing = widget.projectId != null;
    _loadAvailableUsers();
    if (_isEditing) {
      _loadProject();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    if (widget.projectId == null) return;
    
    try {
      final project = await ProjectService.getProjectById(widget.projectId!);
      if (project != null) {
        setState(() {
          _originalProject = project;
          _nameController.text = project.name;
          _descriptionController.text = project.description;
          _clientNameController.text = project.clientName ?? '';
          _keyController.text = project.key;
          _selectedProjectType = project.projectType;
          _selectedStatus = project.status;
          _selectedPriority = project.priority;
          _startDate = project.startDate;
          _endDate = project.endDate;
          
          // Load project owner if available
          if (project.ownerId != null) {
            _selectedProjectOwner = {
              'id': project.ownerId,
              'name': 'Project Owner', // We don't have ownerName in the model
            };
          }
          
          // Load team members
          _teamMembers.clear();
          if (project.members.isNotEmpty) {
            _teamMembers.addAll(project.members.map((member) => {
              'id': member.userId,
              'name': member.userName,
              'email': member.userEmail,
              'role': member.role.name,
              'projectRole': member.role.name,
              'addedAt': member.assignedAt.toIso8601String(),
            }));
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error loading project: $e');
    }finally {
      setState(() => _isLoading = false);
    }
  }

  String? _validateField(String fieldName, String? value) {
    switch (fieldName) {
      case 'name':
        if (value == null || value.trim().isEmpty) {
          return 'Project name is required';
        }
        if (value.trim().length < 3) {
          return 'Project name must be at least 3 characters';
        }
        if (value.trim().length > 100) {
          return 'Project name must not exceed 100 characters';
        }
        if (!RegExp(r'^[a-zA-Z0-9\s\-_]+$').hasMatch(value.trim())) {
          return 'Project name can only contain letters, numbers, spaces, hyphens, and underscores';
        }
        break;
      case 'key':
        if (value == null || value.trim().isEmpty) {
          return 'Project key is required';
        }
        if (value.trim().length < 2) {
          return 'Project key must be at least 2 characters';
        }
        if (value.trim().length > 20) {
          return 'Project key must not exceed 20 characters';
        }
        if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(value.trim())) {
          return 'Project key must start with letter and contain only letters, numbers, and underscores';
        }
        break;
      case 'description':
        if (value == null || value.trim().isEmpty) {
          return 'Description is required';
        }
        if (value.trim().length < 10) {
          return 'Description must be at least 10 characters';
        }
        if (value.trim().length > 1000) {
          return 'Description must not exceed 1000 characters';
        }
        break;
      case 'clientName':
        if (value == null || value.trim().isEmpty) {
          return 'Client name is required';
        }
        if (value.trim().length < 2) {
          return 'Client name must be at least 2 characters';
        }
        if (value.trim().length > 100) {
          return 'Client name must not exceed 100 characters';
        }
        break;
      case 'startDate':
        if (_startDate == null) {
          return 'Start date is required';
        }
        break;
      case 'endDate':
        if (_endDate == null) {
          return 'End date is required';
        }
        if (_startDate != null && _endDate!.isBefore(_startDate!)) {
          return 'End date must be after start date';
        }
        break;
    }
    return null;
  }

  void _validateFieldOnChange(String fieldName, String? value) {
    final error = _validateField(fieldName, value);
    setState(() {
      _validationErrors[fieldName] = error;
    });
  }

  Future<void> _loadAvailableUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      debugPrint('🔍 Loading available users from backend...');
      
      // Try UserDataService first
      try {
        final List<User> users = await UserDataService().getUsers(limit: 1000);
        debugPrint('✅ Successfully loaded ${users.length} users from UserDataService');
        
        setState(() {
          _availableUsers = users.map((user) {
            final displayName =
                (user.name.isNotEmpty ? user.name : user.email).trim();
            final userMap = {
              'id': user.id,
              'name': displayName,
              'email': user.email,
              'role': user.role.name,
              'originalRole': user.role.name, // Store original role for removal
              'isActive': user.isActive,
              'emailVerified': user.emailVerified,
            };
            debugPrint('🔍 Processed user: ${userMap['name']} (${userMap['id']}) - Active: ${userMap['isActive']}');
            return userMap;
          }).where((user) => user['isActive'] == true).toList(); // Only show active users
          _isLoadingUsers = false;
          
          debugPrint('✅ Final available users count: ${_availableUsers.length}');
          for (final user in _availableUsers) {
            debugPrint('  - ${user['name']} (${user['id']})');
          }
        });
      } catch (e) {
        debugPrint('❌ UserDataService failed, trying direct API call: $e');
        
        // Fallback: Direct API call
        final backend = BackendApiService();
        final response = await backend.getUsers(limit: 1000);
        
        if (response.isSuccess && response.data != null) {
          debugPrint('✅ Direct API call successful - response type: ${response.data.runtimeType}');
          
          final responseData = response.data;
          List<dynamic> usersDataList = [];
          
          if (responseData is Map) {
            // Handle different response formats
            if (responseData['users'] is List) {
              usersDataList = responseData['users'];
            } else if (responseData['data'] is List) {
              usersDataList = responseData['data'];
            } else if (responseData['success'] == true && responseData['data'] is List) {
              usersDataList = responseData['data'];
            }
          } else if (responseData is List) {
            usersDataList = responseData;
          }
          
          setState(() {
            _availableUsers = usersDataList.map((userData) {
              // Handle different name formats
              String displayName;
              if (userData['name'] != null && userData['name'].toString().isNotEmpty) {
                displayName = userData['name'];
              } else if (userData['first_name'] != null && userData['first_name'].toString().isNotEmpty) {
                displayName = '${userData['first_name']} ${userData['last_name'] ?? ''}'.trim();
              } else {
                displayName = (userData['email'] ?? '').toString().trim();
              }
              
              return {
                'id': userData['id'],
                'name': displayName,
                'email': userData['email'],
                'role': userData['role'] ?? 'user',
                'isActive': userData['is_active'] ?? userData['isActive'] ?? true,
                'emailVerified': userData['emailVerified'] ?? true,
              };
            }).where((user) =>
                user['isActive'] == true &&
                ((user['name']?.toString().trim().isNotEmpty ?? false) ||
                    (user['email']?.toString().trim().isNotEmpty ?? false))).toList();
            _isLoadingUsers = false;
            
            debugPrint('✅ Final available users count (direct API): ${_availableUsers.length}');
            for (final user in _availableUsers) {
              debugPrint('  - ${user['name']} (${user['id']})');
            }
          });
        } else {
          throw Exception('API call failed: ${response.error}');
        }
      }
      
      debugPrint('✅ Processed ${_availableUsers.length} active users for display');
    } catch (e) {
      setState(() => _isLoadingUsers = false);
      debugPrint('❌ Error loading users: $e');
      setState(() {
        _availableUsers = [];
      });
    }
  }

  void _addTeamMember(Map<String, dynamic> user) {
    setState(() {
      if (!_teamMembers.any((member) => member['id'] == user['id'])) {
        final teamMember = {
          'id': user['id'], // Real database ID from backend
          'name': user['name'],
          'email': user['email'],
          'role': user['role'], // User's system role
          'projectRole': 'member', // Role within this project
          'originalRole': user['originalRole'] ?? user['role'],
          'isActive': user['isActive'] ?? true,
          'emailVerified': user['emailVerified'] ?? false,
          'addedAt': DateTime.now().toIso8601String(),
        };
        
        _teamMembers.add(teamMember);
        _availableUsers.removeWhere((u) => u['id'] == user['id']);
        
        debugPrint('✅ Added team member: ${user['name']} (${user['id']}) to project');
        debugPrint('📊 Current team members: ${_teamMembers.length}');
      } else {
        debugPrint('⚠️ User ${user['name']} is already a team member');
      }
    });
  }

  void _removeTeamMember(Map<String, dynamic> member) {
    setState(() {
      _teamMembers.removeWhere((m) => m['id'] == member['id']);
      _availableUsers.add({
        'id': member['id'],
        'name': member['name'],
        'email': member['email'],
        'role': member['originalRole'] ?? 'developer',
      });
    });
  }

  void _updateTeamMemberRole(String memberId, String newRole) {
    setState(() {
      final memberIndex = _teamMembers.indexWhere((m) => m['id'] == memberId);
      if (memberIndex != -1) {
        _teamMembers[memberIndex]['role'] = newRole;
      }
    });
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) {
      _showValidationErrorSummary();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final projectData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'clientName': _clientNameController.text.trim(),
        'projectKey': _keyController.text.trim(),
        'projectType': _selectedProjectType,
        'status': _selectedStatus.name,
        'priority': _selectedPriority.name,
        'startDate': _startDate!.toIso8601String(),
        'endDate': _endDate!.toIso8601String(),
        'owner_id': _selectedProjectOwner?['id'],
        'owner_name': _selectedProjectOwner?['name'],
        'members': _teamMembers.map((member) => {
          'id': member['id'], // Real database ID
          'name': member['name'],
          'email': member['email'],
          'role': member['projectRole'] ?? 'member', // Role within project
          'systemRole': member['role'], // User's system role
          'addedAt': member['addedAt'],
        }).toList(),
      };

      debugPrint('💾 Saving project with ${_teamMembers.length} team members');
      for (final member in _teamMembers) {
        debugPrint('  - Member: ${member['name']} (${member['id']})');
      }

      Project? savedProject;

      if (widget.projectId != null) {
        savedProject =
            await ProjectService.updateProject(widget.projectId!, projectData);
        _showSuccessSnackBar('Project updated successfully');
      } else {
        savedProject = await ProjectService.createProject(projectData);
        _showSuccessSnackBar('Project created successfully');
      }

      if (mounted) {
        if (widget.projectId != null) {
          Navigator.of(context).pop(savedProject);
        } else {
          // Navigate to project workspace screen for new projects
          context.push('/project-workspace/${savedProject.id}');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error saving project: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _hasFormChanged() {
    if (_originalProject == null) return true;

    return _nameController.text.trim() != _originalProject!.name ||
        _descriptionController.text.trim() != _originalProject!.description ||
        _clientNameController.text.trim() !=
            (_originalProject!.clientName ?? '') ||
        _selectedProjectType != _originalProject!.projectType ||
        _selectedStatus != _originalProject!.status ||
        _selectedPriority != _originalProject!.priority ||
        _startDate?.toIso8601String() !=
            _originalProject!.startDate.toIso8601String() ||
        _endDate?.toIso8601String() !=
            _originalProject!.endDate?.toIso8601String();
  }

  void _resetForm() {
    if (_originalProject != null) {
      setState(() {
        _nameController.text = _originalProject!.name;
        _descriptionController.text = _originalProject!.description;
        _clientNameController.text = _originalProject!.clientName ?? '';
        _keyController.text = _originalProject!.key;

        final loadedType = _originalProject!.projectType;
        if (_projectTypes.contains(loadedType)) {
          _selectedProjectType = loadedType;
        } else if (loadedType.toLowerCase() == 'software') {
          _selectedProjectType = 'Fixed Scope';
        } else {
          _selectedProjectType = _projectTypes.first;
        }
        _selectedStatus = _originalProject!.status;
        _selectedPriority = _originalProject!.priority;
        _startDate = _originalProject!.startDate;
        _endDate = _originalProject!.endDate;

        // Clear validation errors
        _validationErrors.forEach((key, value) {
          _validationErrors[key] = null;
        });
      });
    }
  }

  void _showValidationErrorSummary() {
    final errors = <String>[];
    _validationErrors.forEach((field, error) {
      if (error != null) {
        errors.add(error);
      }
    });

    if (errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Errors'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: errors
                .map(
                  (error) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(error)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    // Handle case where name might be an object representation
    if (name.startsWith('{') || name.startsWith('[')) {
      return '?'; // Return default for object representations
    }
    
    // Split by spaces and take first letter of first two parts
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _startDate ?? DateTime.now()
          : _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate!.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[900]!.withValues(alpha: 0.1),
              Colors.purple[900]!.withValues(alpha: 0.1),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildForm(),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit Project' : 'Create Project',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEditing
                      ? 'Update project details and manage team members'
                      : 'Define project details and assign team members',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Icon(
                Icons.close,
                color: Colors.grey[700],
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProjectInformationSection(),
            const SizedBox(height: 24),
            _buildTimelineSection(),
            const SizedBox(height: 24),
            _buildClientClassificationSection(),
            const SizedBox(height: 24),
            _buildTeamManagementSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectInformationSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          _buildModernNameField(),
          const SizedBox(height: 16),
          _buildModernKeyField(),
          const SizedBox(height: 16),
          _buildModernDescriptionField(),
          const SizedBox(height: 16),
          _buildModernProjectOwnerField(),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          _buildModernDateFields(),
        ],
      ),
    );
  }

  Widget _buildClientClassificationSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client & Classification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          _buildModernClientField(),
          const SizedBox(height: 16),
          _buildModernProjectTypeField(),
        ],
      ),
    );
  }

  Widget _buildTeamManagementSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Team Members',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
              if (_teamMembers.isNotEmpty)
                Text(
                  '${_teamMembers.length} member${_teamMembers.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718096),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Current team members
          if (_teamMembers.isNotEmpty) ...[
            ..._teamMembers.map((member) => _buildTeamMemberTile(member)),
            const SizedBox(height: 16),
          ],

          // Add team member button
          _buildAddTeamMemberButton(),

          const SizedBox(height: 16),

          // Available users section
          if (_availableUsers.isNotEmpty) ...[
            const Text(
              'Available Users',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4A5568),
              ),
            ),
            const SizedBox(height: 8),
            ..._availableUsers
                .take(3)
                .map((user) => _buildAvailableUserTile(user)),
            if (_availableUsers.length > 3)
              Text(
                '... and ${_availableUsers.length - 3} more',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF718096),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamMemberTile(Map<String, dynamic> member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue[100],
            child: Text(
              _getInitials(member['name']),
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Color(0xFF1A202C),
                  ),
                ),
                Text(
                  member['email'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: member['role'],
            icon: const Icon(Icons.arrow_drop_down, size: 20),
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1A202C),
            ),
            items: ['owner', 'admin', 'member', 'viewer'].map((role) {
              return DropdownMenuItem(
                value: role,
                child: Text(
                  role[0].toUpperCase() + role.substring(1),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A202C),
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateTeamMemberRole(member['id'], value);
              }
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: Colors.red[400]),
            onPressed: () => _removeTeamMember(member),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableUserTile(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            child: Text(
              user['name'][0].toUpperCase(),
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  user['email'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _addTeamMember(user),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTeamMemberButton() {
    return OutlinedButton.icon(
      onPressed: _showAddTeamMemberDialog,
      icon: Icon(Icons.person_add, color: Colors.blue[600]),
      label: Text(
        'Add Team Member',
        style: TextStyle(color: Colors.blue[600]),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.blue[300]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showSelectOwnerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isLoadingUsers ? 'Loading Users...' : 'Select Project Owner'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _isLoadingUsers
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching available users from server...'),
                    SizedBox(height: 8),
                    Text(
                      'Please wait',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                )
              : _availableUsers.isEmpty
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No Available Users',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No users available to assign as project owner',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Text(
                          'Available Users (${_availableUsers.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: _availableUsers.map((user) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  child: Text(
                                    _getInitials(user['name']),
                                    style: TextStyle(
                                      color: Colors.green[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(user['name']),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user['email']),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            user['role'] ?? 'user',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue[800],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (user['isActive'] == true) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Active',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  setState(() {
                                    _selectedProjectOwner = user;
                                  });
                                  debugPrint('🔍 Selected project owner: ${user['name']}');
                                },
                              );
                            }).toList(),
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
          if (!_isLoadingUsers && _availableUsers.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Optionally refresh users
                _loadAvailableUsers();
              },
              child: const Text('Refresh'),
            ),
        ],
      ),
    );
  }

  void _showAddTeamMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isLoadingUsers ? 'Loading Users...' : 'Add Team Member'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _isLoadingUsers
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching available users from server...'),
                    SizedBox(height: 8),
                    Text(
                      'Please wait',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                )
              : _availableUsers.isEmpty
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No Available Users',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'All users are already assigned to this project',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Text(
                          'Available Users (${_availableUsers.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: _availableUsers.map((user) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue[100],
                                  child: Text(
                                    _getInitials(user['name']),
                                    style: TextStyle(
                                      color: Colors.blue[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(user['name']),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user['email']),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            user['role'],
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green[800],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (user['emailVerified'] == true) ...[
                                          const SizedBox(width: 4),
                                          Icon(Icons.verified, size: 12, color: Colors.green[600]),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    _addTeamMember(user);
                                    Navigator.of(context).pop();
                                    _showSuccessSnackBar('${user['name']} added to project team');
                                  },
                                  child: const Text('Add'),
                                ),
                              );
                            }).toList(),
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
          if (!_isLoadingUsers && _availableUsers.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadAvailableUsers(); // Refresh the list
              },
              child: const Text('Refresh'),
            ),
        ],
      ),
    );
  }

  Widget _buildModernNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Project Name*',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1A202C),
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: 'Enter project name',
            hintStyle: const TextStyle(
              color: Color(0xFFA0AEC0),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3182CE)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          maxLength: 100,
          onChanged: (value) => _validateFieldOnChange('name', value),
          validator: (value) => _validateField('name', value),
        ),
      ],
    );
  }

  Widget _buildModernKeyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Project ID*',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4A5568),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isNotEmpty) {
                  final key = name
                      .toUpperCase()
                      .replaceAll(RegExp(r'[^A-Z0-9_]'), '_')
                      .replaceAll(RegExp(r'_+'), '_');
                  _keyController.text = key;
                }
              },
              icon: const Icon(Icons.refresh, size: 16),
              tooltip: 'Generate from project name',
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _keyController,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1A202C),
            fontWeight: FontWeight.w400,
            letterSpacing: 1.2,
          ),
          inputFormatters: [
            UpperCaseTextFormatter(),
            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9_]')),
          ],
          decoration: InputDecoration(
            hintText: 'PROJECT_KEY',
            hintStyle: const TextStyle(
              color: Color(0xFFA0AEC0),
              fontSize: 14,
              letterSpacing: 1.2,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3182CE)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          maxLength: 20,
          onChanged: (value) => _validateFieldOnChange('key', value),
          validator: (value) => _validateField('key', value),
        ),
      ],
    );
  }

  Widget _buildModernDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Project Description',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1A202C),
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Enter project description',
            hintStyle: const TextStyle(
              color: Color(0xFFA0AEC0),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3182CE)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          maxLength: 1000,
          onChanged: (value) => _validateFieldOnChange('description', value),
          validator: (value) => _validateField('description', value),
        ),
      ],
    );
  }

  Widget _buildModernDateFields() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start Date*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context, isStartDate: true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _startDate != null
                              ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                              : 'Select start date',
                          style: TextStyle(
                            color: _startDate != null
                                ? Colors.black87
                                : Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'End Date*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context, isStartDate: false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _endDate != null
                              ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                              : 'Select end date',
                          style: TextStyle(
                            color: _endDate != null
                                ? Colors.black87
                                : Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernProjectOwnerField() {
    debugPrint('🔥 Building project owner field with new implementation!');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Project Owner*',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2D3748),
            border: Border.all(color: const Color(0xFF4A5568)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.grey[400], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedProjectOwner?['name'] ?? 'Select Project Owner',
                  style: TextStyle(
                    color: _selectedProjectOwner != null ? Colors.white : Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
              ),
              if (_selectedProjectOwner != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedProjectOwner = null;
                    });
                  },
                  tooltip: 'Clear Selection',
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showSelectOwnerDialog,
                icon: const Icon(Icons.people, size: 16),
                label: const Text('Select'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (_selectedProjectOwner == null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Please select a project owner',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModernClientField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Client*',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _clientNameController,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1A202C),
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: 'Select client',
            hintStyle: const TextStyle(
              color: Color(0xFFA0AEC0),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3182CE)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon:
                const Icon(Icons.arrow_drop_down, color: Color(0xFF718096)),
          ),
          onChanged: (value) => _validateFieldOnChange('clientName', value),
          validator: (value) => _validateField('clientName', value),
        ),
      ],
    );
  }

  Widget _buildModernProjectTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Project Type*',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _projectTypes.contains(_selectedProjectType)
                  ? _selectedProjectType
                  : null,
              hint: const Text('Choose project type',
                  style: TextStyle(color: Color(0xFFA0AEC0))),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1A202C),
                fontWeight: FontWeight.w400,
              ),
              isExpanded: true,
              items: _projectTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(
                    type,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A202C),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedProjectType = newValue!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GlassCard(
        child: Column(
          children: [
            if (_isEditing && _hasFormChanged()) ...[
              // Reset button for edit mode
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetForm,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset Changes'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.orange[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Main action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              context.go('/projects');
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Saving...'),
                            ],
                          )
                        : Text(
                            _isEditing ? 'Update Project' : 'Create Project',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
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
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
