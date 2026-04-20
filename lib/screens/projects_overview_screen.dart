import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/sprint_database_service.dart';

class ProjectsOverviewScreen extends StatefulWidget {
  const ProjectsOverviewScreen({super.key});

  @override
  State<ProjectsOverviewScreen> createState() => _ProjectsOverviewScreenState();
}

class _ProjectsOverviewScreenState extends State<ProjectsOverviewScreen> {
  final SprintDatabaseService _sprintService = SprintDatabaseService();
  final List<Map<String, dynamic>> _projects = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'active', 'completed'

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
      final projects = await _sprintService.getProjects();
      setState(() {
        _projects
          ..clear()
          ..addAll(projects);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  _buildHeaderSection(),
                  const SizedBox(height: 32),

                  // Your Projects Section
                  _buildProjectsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and Search/Filter Section
        Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'assets/Icons/projects_nav_active.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.folder_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Search Bar
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search projects...',
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Filter Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: DropdownButton<String>(
                value: _selectedFilter,
                onChanged: (value) {
                  setState(() => _selectedFilter = value!);
                },
                dropdownColor: Colors.grey[800],
                icon: const Icon(Icons.filter_list, color: Colors.white70),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Projects')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Projects',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Subtitle
        const Text(
          'View and manage your projects and their sprints',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            // All Projects Button
            OutlinedButton.icon(
              onPressed: () {
                // Navigate to all projects or refresh
                _loadProjects();
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('All Projects'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.grey),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 12),

            // Create Project Button
            ElevatedButton.icon(
              onPressed: () async {
                final created = await context.push<bool>('/projects/create');
                if (created == true) {
                  await _loadProjects();
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Project'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Filter projects based on search query and selected filter
  List<Map<String, dynamic>> _getFilteredProjects() {
    var filteredProjects = List<Map<String, dynamic>>.from(_projects);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredProjects = filteredProjects.where((project) {
        final name = project['name']?.toString().toLowerCase() ?? '';
        final description = project['description']?.toString().toLowerCase() ?? '';
        return name.contains(_searchQuery.toLowerCase()) || 
               description.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply status filter
    switch (_selectedFilter) {
      case 'active':
        filteredProjects = filteredProjects.where((project) => 
          project['status']?.toString() == 'active').toList();
        break;
      case 'completed':
        filteredProjects = filteredProjects.where((project) => 
          project['status']?.toString() == 'completed').toList();
        break;
      case 'all':
      default:
        // Already filtered by search if applicable
        break;
    }

    return filteredProjects;
  }

  Widget _buildProjectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        const Text(
          'Your Projects',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Filtered Project Cards
        ..._getFilteredProjects().map((project) => _buildProjectCard(project)),

        // Empty state
        if (_projects.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/Icons/projects_nav_inactive.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.folder_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No projects found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first project to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final name = project['name']?.toString() ?? 'Untitled Project';
    final key = project['key']?.toString() ?? '';
    final description = project['description']?.toString() ?? '';
    final startDate = project['start_date']?.toString() ?? '';
    final endDate = project['end_date']?.toString() ?? '';
    final status = project['status']?.toString() ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Title and Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  switch (value) {
                    case 'details':
                      final projectId = project['id']?.toString() ?? key;
                      if (projectId.isNotEmpty) {
                        context.push('/project-details/$projectId');
                      }
                      break;
                    case 'edit':
                      final projectId = project['id']?.toString() ?? key;
                      if (projectId.isNotEmpty) {
                        context.push('/project-workspace/$projectId');
                      }
                      break;
                    case 'delete':
                      // Show delete confirmation
                      _showDeleteDialog(project);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16),
                        SizedBox(width: 8),
                        Text('Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Project Key and Description
          if (key.isNotEmpty) ...[
            Text(
              key,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Dates and Status
          Row(
            children: [
              // Start Date
              if (startDate.isNotEmpty) ...[
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Start: $startDate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // End Date
              if (endDate.isNotEmpty) ...[
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'End: $endDate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'planning':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      case 'on_hold':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showDeleteDialog(Map<String, dynamic> project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final projectId = project['id']?.toString();
              if (projectId == null || projectId.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid project ID'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              // Show loading indicator
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deleting project...')),
                );
              }

              try {
                final success = await _sprintService.deleteProject(projectId);

                if (success) {
                  // Refresh the projects list
                  await _loadProjects();

                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Project "${project['name']}" deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Failed to delete project "${project['name']}"'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting project: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
