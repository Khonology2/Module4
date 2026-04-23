import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/project_service.dart';

class ProjectCreateScreen extends StatefulWidget {
  final String? projectId;
  
  const ProjectCreateScreen({super.key, this.projectId});

  @override
  State<ProjectCreateScreen> createState() => _ProjectCreateScreenState();
}

class _ProjectCreateScreenState extends State<ProjectCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _clientController = TextEditingController();
  final _repositoryController = TextEditingController();
  final _documentationController = TextEditingController();
  String _selectedType = 'Software Development';
  bool _isLoading = false;
  bool _isEditing = false;

  final List<String> _projectTypes = [
    'Software Development',
    'Infrastructure',
    'Consulting',
    'Research & Development',
    'Training',
    'Support & Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.projectId != null;
    if (_isEditing) {
      _loadProjectData();
    }
  }

  Future<void> _loadProjectData() async {
    if (widget.projectId == null) return;
    
    try {
      final project = await ProjectService.getProjectById(widget.projectId!);
      if (project != null) {
        setState(() {
          _nameController.text = project.name;
          _keyController.text = project.id;
          _descriptionController.text = project.description;
          _clientController.text = project.clientName ?? '';
          _selectedType = project.projectType;
          _startDateController.text = '${project.startDate.day}/${project.startDate.month}/${project.startDate.year}';
          if (project.endDate != null) {
            _endDateController.text = '${project.endDate!.day}/${project.endDate!.month}/${project.endDate!.year}';
          }
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _clientController.dispose();
    _repositoryController.dispose();
    _documentationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      controller.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  void _generateProjectKey() {
    if (_nameController.text.trim().isNotEmpty) {
      final name = _nameController.text.trim();
      final key = name
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .split(' ')
          .where((word) => word.isNotEmpty)
          .map((word) => word[0].toUpperCase())
          .take(3)
          .join('');
      _keyController.text = key;
    }
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final projectData = {
        'name': _nameController.text.trim(),
        'key': _keyController.text.trim(),
        'description': _descriptionController.text.trim(),
        'clientName': _clientController.text.trim(),
        'projectType': _selectedType,
        'startDate': _startDateController.text.trim(),
        'endDate': _endDateController.text.trim(),
        'repositoryUrl': _repositoryController.text.trim(),
        'documentationUrl': _documentationController.text.trim(),
        'status': 'planning',
        'priority': 'medium',
        'tags': [],
        'members': [],
        'deliverableIds': [],
        'sprintIds': [],
      };

      if (_isEditing) {
        await ProjectService.updateProject(widget.projectId!, projectData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Project updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await ProjectService.createProject(projectData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Project created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      if (mounted) {
        context.go('/projects');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating project: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Icons/images/auth_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    _isEditing ? 'Edit Project' : 'Create Project',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Project Name
                  _buildGlassFormField(
                    label: 'Project Name',
                    controller: _nameController,
                    hintText: 'Enter project name',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Project name is required';
                      }
                      return null;
                    },
                    onChanged: (_) => _generateProjectKey(),
                  ),
                  const SizedBox(height: 20),

                  // Project Key
                  Row(
                    children: [
                      Expanded(
                        child: _buildGlassFormField(
                          label: 'Project Key',
                          controller: _keyController,
                          hintText: 'Auto-generated from project name',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Project key is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _generateProjectKey,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          tooltip: 'Generate Key',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  _buildGlassFormField(
                    label: 'Description',
                    controller: _descriptionController,
                    maxLines: 3,
                    hintText: 'Enter project description',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Description is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Dates Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildGlassFormField(
                          label: 'Start Date',
                          controller: _startDateController,
                          hintText: 'DD/MM/YYYY',
                          readOnly: true,
                          suffixIcon: Icons.calendar_today,
                          onTap: () => _selectDate(context, _startDateController),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Start date is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildGlassFormField(
                          label: 'End Date',
                          controller: _endDateController,
                          hintText: 'DD/MM/YYYY',
                          readOnly: true,
                          suffixIcon: Icons.calendar_today,
                          onTap: () => _selectDate(context, _endDateController),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'End date is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Client Name
                  _buildGlassFormField(
                    label: 'Client Name',
                    controller: _clientController,
                    hintText: 'Enter client name',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Client name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Project Type
                  _buildGlassDropdownField(
                    label: 'Project Type',
                    value: _selectedType,
                    items: _projectTypes,
                    onChanged: (value) {
                      setState(() => _selectedType = value);
                    },
                  ),
                  const SizedBox(height: 20),

                  // URLs Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildGlassFormField(
                          label: 'Repository URL',
                          controller: _repositoryController,
                          hintText: 'https://github.com/username/repo',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildGlassFormField(
                          label: 'Documentation URL',
                          controller: _documentationController,
                          hintText: 'https://docs.example.com',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: OutlinedButton(
                            onPressed: () => context.go('/projects'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide.none,
                              backgroundColor: Colors.transparent,
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProject,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    _isEditing ? 'Update Project' : 'Save Project',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassFormField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    int maxLines = 1,
    bool readOnly = false,
    IconData? suffixIcon,
    void Function()? onTap,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            readOnly: readOnly,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              suffixIcon: suffixIcon != null
                  ? IconButton(
                      icon: Icon(suffixIcon, 
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      onPressed: onTap,
                    )
                  : null,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            items: items.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _selectedType = value);
              }
            },
          ),
        ),
      ],
    );
  }
}
