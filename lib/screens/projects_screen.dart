import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/project_service.dart';
import 'package:khono/models/project.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_card.dart';
import 'project_workspace_screen.dart';
import '../utils/project_extensions.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> _projects = [];
  bool _isLoading = false;
  String? _selectedProjectId;

  // Unified management mode
  final bool _isCreateMode = false;
  String? _editingProjectId;

  // Form controllers for creation/editing
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projects = await ProjectService.getAllProjects();
      setState(() {
        _projects = projects;
        _isLoading = false;
      });

      if (projects.isEmpty) {
        _showEmptyStateMessage();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _showErrorMessage(e);
      }
    }
  }

  void _navigateToProjectSetup() {
    final auth = AuthService();
    if (!auth.hasPermission('manage_projects')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Only Delivery Leads and System Admins can create projects.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProjectWorkspaceScreen(),
      ),
    );
  }

  void _showErrorMessage(dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to load projects: ${error.toString()}'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadProjects,
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showEmptyStateMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'No projects found. Create your first project to get started!'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;
    final canManageProjects = AuthService().hasPermission('manage_projects');

    return AppScaffold(
      useBackgroundImage: true,
      centered: false,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header
                Container(
                  margin: const EdgeInsets.all(16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withAlpha(51),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: primaryColor.withAlpha(128)),
                              ),
                              child: Icon(
                                _isCreateMode ? Icons.edit : Icons.folder,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isCreateMode
                                        ? (_editingProjectId != null
                                            ? 'Edit Project'
                                            : 'Create New Project')
                                        : 'Projects',
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      color: onSurfaceColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _isCreateMode
                                        ? 'Fill in the project details below'
                                        : 'View and manage your projects and their sprints',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: onSurfaceColor.withAlpha(230),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isCreateMode) ...[
                              ElevatedButton.icon(
                                onPressed: () => _navigateToSprintConsole(
                                    _selectedProjectId),
                                icon: const Icon(Icons.directions_run),
                                label: Text(_selectedProjectId != null
                                    ? 'View Sprints'
                                    : 'Sprint Console'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                              ),
                              if (canManageProjects) ...[
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _navigateToProjectSetup,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Project'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content
                Expanded(
                  child: _isCreateMode
                      ? _buildProjectForm()
                      : _buildProjectsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildProjectsList() {
    final canManageProjects = AuthService().hasPermission('manage_projects');
    if (_projects.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first project to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(179),
                  ),
            ),
            if (canManageProjects) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToProjectSetup,
                icon: const Icon(Icons.add),
                label: const Text('Create Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Projects',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _projects.length,
          itemBuilder: (context, index) {
            final project = _projects[index];
            return _buildProjectCard(project);
          },
        ),
      ],
    );
  }

  Widget _buildProjectCard(Project project) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.key,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (project.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            project.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: theme.colorScheme.onSurface.withAlpha(179)),
                    color: Colors.transparent,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility,
                                size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            const Text('View Details'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            const Text('Edit Project'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'view') {
                        debugPrint(
                            'ProjectsScreen: Navigating to project workspace for ID: ${project.id}');
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ProjectWorkspaceScreen(projectId: project.id),
                          ),
                        );
                      } else if (value == 'edit') {
                        debugPrint(
                            'ProjectsScreen: Navigating to edit project for ID: ${project.id}');
                        context.push('/project-workspace/${project.id}');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Start: ${project.formattedStartDate}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  if (project.displayEndDate != null) ...[
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.event,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'End: ${project.formattedEndDate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Colors.orange[300],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'No end date set',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange[300],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectForm() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Form',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Project Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _clientNameController,
            decoration: const InputDecoration(
              labelText: 'Client Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            decoration: const InputDecoration(
              labelText: 'Project Key',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSprintConsole(String? projectId) {
    if (projectId != null && projectId.isNotEmpty) {
      context.push('/sprint-console', extra: {'projectId': projectId});
    } else {
      context.push('/sprint-console');
    }
  }
}
