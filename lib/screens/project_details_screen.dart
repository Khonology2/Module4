import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/backend_api_service.dart';
import '../services/sprint_database_service.dart';
import '../widgets/glass_card.dart';
import '../theme/flownet_theme.dart';

class ProjectDetailsScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailsScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends ConsumerState<ProjectDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _project;
  List<Map<String, dynamic>> _sprints = [];
  List<Map<String, dynamic>> _projectMembers = [];
  String? _error;
  int? _projectDuration;

  @override
  void initState() {
    super.initState();
    _loadProjectDetails();
  }

  Future<void> _loadProjectDetails() async {
    try {
      setState(() => _isLoading = true);

      final resp = await BackendApiService().getProject(widget.projectId);
      if (!resp.isSuccess || resp.data == null) {
        setState(() => _error = resp.error ?? 'Failed to load project details');
        return;
      }
      final raw = resp.data;
      final Map<String, dynamic> projectData;
      if (raw is Map) {
        final inner = raw['data'] ?? raw['project'] ?? raw;
        projectData = inner is Map ? Map<String, dynamic>.from(inner) : <String, dynamic>{};
      } else {
        projectData = <String, dynamic>{};
      }
      
      if (projectData.isNotEmpty) {
        setState(() {
          _project = projectData;
          // Calculate project duration
          final startRaw = projectData['start_date'] ?? projectData['startDate'];
          final endRaw = projectData['end_date'] ?? projectData['endDate'];
          if (startRaw != null && endRaw != null) {
            final startDate = DateTime.parse(startRaw.toString());
            final endDate = DateTime.parse(endRaw.toString());
            _projectDuration = endDate.difference(startDate).inDays;
          }

          final membersRaw = projectData['members'];
          if (membersRaw is List) {
            _projectMembers = membersRaw
                .where((m) => m != null)
                .map((m) => m is Map ? Map<String, dynamic>.from(m) : <String, dynamic>{})
                .where((m) => m.isNotEmpty)
                .map((m) => <String, dynamic>{
                      'id': (m['userId'] ?? m['user_id'] ?? m['id'] ?? '').toString(),
                      'name': (m['userName'] ?? m['user_name'] ?? m['name'] ?? '').toString(),
                      'role': (m['role'] ?? '').toString(),
                      'email': (m['userEmail'] ?? m['user_email'] ?? m['email'] ?? '').toString(),
                      'avatar': m['avatar'],
                    })
                .toList();
          } else {
            _projectMembers = [];
          }
        });

        // Load sprints for this project
        await _loadSprints();
      } else {
        debugPrint('❌ Backend response failed: ${resp.error}');
        setState(() => _error = 'Project not found');
      }
    } catch (e) {
      debugPrint('❌ Error loading project details: $e');
      setState(() => _error = 'Failed to load project details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSprints() async {
    try {
      final sprintsData = await SprintDatabaseService().getSprints(projectId: widget.projectId);
      setState(() {
        _sprints = sprintsData;
      });
    } catch (e) {
      debugPrint('Error loading sprints: $e');
    }
  }

  String _formatStatus(String? status) {
    final raw = (status ?? '').toString().trim();
    if (raw.isEmpty) return 'Draft';
    switch (raw.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'planning':
      case 'planned':
      case 'to do':
        return 'Planning';
      case 'in_progress':
      case 'inprogress':
      case 'in progress':
      case 'active':
        return 'In Progress';
      case 'completed':
      case 'done':
        return 'Completed';
      case 'on_hold':
      case 'onhold':
        return 'On Hold';
      case 'cancelled':
        return 'Cancelled';
      default:
        final normalized = raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
        if (normalized.isEmpty) return 'Draft';
        return normalized
            .split(RegExp(r'\s+'))
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
            .join(' ');
    }
  }

  String _formatPriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return 'Medium';
    }
  }

  IconData _getRoleIcon(String? role) {
    switch (role?.toLowerCase()) {
      case 'owner':
        return Icons.star;
      case 'manager':
        return Icons.admin_panel_settings;
      case 'developer':
        return Icons.code;
      case 'designer':
        return Icons.palette;
      case 'tester':
        return Icons.bug_report;
      default:
        return Icons.person;
    }
  }

  Color _getStatusColor(String? status) {
    final s = (status ?? '').toString().toLowerCase().trim();
    switch (s) {
      case '':
      case 'draft':
        return Colors.grey;
      case 'planning':
      case 'planned':
      case 'to do':
        return Colors.blue;
      case 'in_progress':
      case 'in progress':
      case 'active':
        return Colors.orange;
      case 'completed':
      case 'done':
        return Colors.green;
      case 'on_hold':
      case 'onhold':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _projectField(String key, [String? altKey]) {
    final p = _project;
    if (p == null) return '';
    final v = p[key] ?? (altKey != null ? p[altKey] : null);
    return (v ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlownetColors.background,
      appBar: AppBar(
        title: Text(_project?['name'] ?? 'Project Details'),
        backgroundColor: FlownetColors.surface,
        foregroundColor: FlownetColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProjectDetails,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _project == null
                  ? const Center(child: Text('Project not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Project Header
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(_project!['status']).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getStatusColor(_project!['status']),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.folder,
                                        color: _getStatusColor(_project!['status']),
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _project!['name'] ?? 'Untitled Project',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: FlownetColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _project!['key'] ?? 'NO-KEY',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_project!['description'] != null) ...[
                                  Text(
                                    _project!['description'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: FlownetColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                Row(
                                  children: [
                                    _buildStatusChip(),
                                    const SizedBox(width: 8),
                                    _buildPriorityChip(),
                                  ],
                                ),
                                if (_projectField('client_name', 'clientName').trim().isNotEmpty ||
                                    _projectField('client_owner_name', 'clientOwnerName').trim().isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _projectField('client_name', 'clientName').trim().isEmpty
                                            ? const SizedBox.shrink()
                                            : Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Client',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _projectField('client_name', 'clientName'),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: FlownetColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                      Expanded(
                                        child: _projectField('client_owner_name', 'clientOwnerName').trim().isEmpty
                                            ? const SizedBox.shrink()
                                            : Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Client Owner',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _projectField('client_owner_name', 'clientOwnerName'),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: FlownetColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Project Metrics
                          Row(
                            children: [
                              Expanded(
                                child: GlassCard(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        color: FlownetColors.primary,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _projectDuration != null 
                                            ? '$_projectDuration days'
                                            : 'Not set',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: FlownetColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Duration',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: GlassCard(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.timer,
                                        color: FlownetColors.primary,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${_sprints.length}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: FlownetColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Sprints',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: GlassCard(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.people,
                                        color: FlownetColors.primary,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${_projectMembers.length}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: FlownetColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Members',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Project Timeline
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Project Timeline',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: FlownetColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Start Date',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (_project!['start_date'] ?? _project!['startDate']) != null
                                                ? _formatDate(DateTime.parse((_project!['start_date'] ?? _project!['startDate']).toString()))
                                                : 'Not set',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: FlownetColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'End Date',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (_project!['end_date'] ?? _project!['endDate']) != null
                                                ? _formatDate(DateTime.parse((_project!['end_date'] ?? _project!['endDate']).toString()))
                                                : 'Not set',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: FlownetColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Project Members
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Project Members',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: FlownetColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ..._projectMembers.map((member) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: FlownetColors.primary.withValues(alpha: 0.1),
                                        child: member['avatar'] != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(20),
                                                child: Image.network(
                                                  member['avatar'],
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.person,
                                                color: FlownetColors.primary,
                                                size: 20,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              member['name'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: FlownetColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              member['role'] ?? 'No role',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        _getRoleIcon(member['role']),
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Sprints
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Sprints',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: FlownetColors.textPrimary,
                                      ),
                                    ),
                                    if (_sprints.isNotEmpty)
                                      TextButton(
                                        onPressed: () {
                                          final pid = widget.projectId;
                                          final pkey = (_project?['key'] ?? '').toString();
                                          final qp = <String, String>{
                                            'projectId': pid,
                                            if (pkey.trim().isNotEmpty) 'projectKey': pkey.trim(),
                                          };
                                          context.go(Uri(path: '/sprint-console', queryParameters: qp).toString());
                                        },
                                        child: const Text('View All'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_sprints.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.timer,
                                            size: 48,
                                            color: Color(0xFFBDBDBD),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No sprints created yet',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ..._sprints.take(3).map((sprint) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: FlownetColors.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.timer,
                                            color: FlownetColors.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sprint['name'] ?? 'Untitled Sprint',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: FlownetColors.textPrimary,
                                                  ),
                                                ),
                                                if (sprint['start_date'] != null && sprint['end_date'] != null)
                                                  Text(
                                                    '${_formatDate(DateTime.parse(sprint['start_date']))} - ${_formatDate(DateTime.parse(sprint['end_date']))}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(sprint['status']).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _getStatusColor(sprint['status']),
                                              ),
                                            ),
                                            child: Text(
                                              _formatStatus(sprint['status']),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _getStatusColor(sprint['status']),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(_project!['status']).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(_project!['status']),
        ),
      ),
      child: Text(
        _formatStatus(_project!['status']),
        style: TextStyle(
          fontSize: 12,
          color: _getStatusColor(_project!['status']),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPriorityChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getPriorityColor(_project!['priority']).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getPriorityColor(_project!['priority']),
        ),
      ),
      child: Text(
        _formatPriority(_project!['priority']),
        style: TextStyle(
          fontSize: 12,
          color: _getPriorityColor(_project!['priority']),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
