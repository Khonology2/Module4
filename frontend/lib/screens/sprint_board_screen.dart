import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/sprint_database_service.dart';
import '../services/realtime_service.dart';
import '../services/auth_service.dart';
import '../services/jira_service.dart';
import '../services/deliverable_service.dart';
import '../models/deliverable.dart';
import '../theme/flownet_theme.dart';
import '../widgets/sprint_board_widget.dart';
import '../widgets/app_scaffold.dart';

class SprintBoardScreen extends ConsumerStatefulWidget {
  final String sprintId;
  final String sprintName;
  final String? projectKey;
  
  const SprintBoardScreen({
    super.key,
    required this.sprintId,
    required this.sprintName,
    this.projectKey,
  });

  @override
  ConsumerState<SprintBoardScreen> createState() => _SprintBoardScreenState();
}

class _SprintBoardScreenState extends ConsumerState<SprintBoardScreen> {
  final SprintDatabaseService _databaseService = SprintDatabaseService();
  final DeliverableService _deliverableService = DeliverableService();
  late RealtimeService _realtime;
  
  // Data
  List<JiraIssue> _issues = [];
  List<Deliverable> _deliverables = [];
  Map<String, dynamic>? _sprintDetails;
  
  // UI State
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSprintData();
    _setupRealtime();
  }


  Future<void> _loadSprintData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load sprint details
      final sprintDetails = await _databaseService.getSprintDetails(widget.sprintId);
      
      if (mounted) {
        setState(() {
          _sprintDetails = sprintDetails;
        });
      }

      if (sprintDetails != null) {
        final project = sprintDetails['project'];
        final projectId = sprintDetails['project_id']?.toString() ??
            sprintDetails['projectId']?.toString() ??
            (project is Map ? project['id']?.toString() : null);
        debugPrint('🔍 Sprint loaded. Project ID: $projectId');

        await _loadDeliverablesForSprint(widget.sprintId, projectId: projectId);
      } else {
        debugPrint('⚠️ Sprint details not found for ID: ${widget.sprintId}');
        _showSnackBar('Sprint details not found', isError: true);
      }
    } catch (e) {
      debugPrint('❌ Error loading sprint data: $e');
      _showSnackBar('Error loading sprint data: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtime() {
    _realtime = RealtimeService();
    _realtime.initialize(authToken: AuthService().accessToken);
    _realtime.on('deliverable_created', (data) => _loadDeliverablesForSprint(widget.sprintId));
    _realtime.on('deliverable_updated', (data) => _loadDeliverablesForSprint(widget.sprintId));
    _realtime.on('deliverable_deleted', (data) => _loadDeliverablesForSprint(widget.sprintId));
  }

  Future<void> _loadDeliverablesForSprint(String sprintId, {String? projectId}) async {
    try {
      final project = _sprintDetails?['project'];
      final pid = projectId ?? 
                 _sprintDetails?['project_id']?.toString() ?? 
                 _sprintDetails?['projectId']?.toString() ??
                 (project is Map ? project['id']?.toString() : null);
      
      debugPrint('🔍 Fetching deliverables for sprint: $sprintId (project: $pid)');

      var response = await _deliverableService.getDeliverablesForSprint(sprintId);
      if (!response.isSuccess && pid != null && pid.isNotEmpty) {
        response = await _deliverableService.getDeliverables(projectId: pid);
      }
      
      if (response.isSuccess && response.data != null) {
        final data = response.data;
        List<Deliverable> deliverables = [];
        
        if (data is List) {
          // If it's a raw list, we might need to parse it, but DeliverableService 
          // usually returns {'deliverables': List<Deliverable>}
          try {
            deliverables = data.map((e) => e is Deliverable ? e : Deliverable.fromJson(Map<String, dynamic>.from(e))).toList();
          } catch (e) {
            debugPrint('❌ Error parsing deliverables list: $e');
          }
        } else if (data is Map) {
          final dynamic rawList = data['deliverables'] ?? data['data'] ?? [];
          if (rawList is List) {
            deliverables = rawList.map((e) => e is Deliverable ? e : Deliverable.fromJson(Map<String, dynamic>.from(e))).toList();
          }
        }

        if (deliverables.isNotEmpty) {
          deliverables = deliverables.where((d) {
            final inSprint = d.sprintIds.map((e) => e.toString()).contains(sprintId.toString());
            if (!inSprint) return false;
            if (pid == null || pid.isEmpty) return true;
            return (d.projectId ?? '').toString() == pid.toString();
          }).toList();
        }
        
        if (mounted) {
          setState(() {
            _deliverables = deliverables;
            // Map deliverables to JiraIssue for the board widget
            _issues = deliverables.map((d) {
              // Generate a safe key from the ID
              String key = d.id.length > 8 ? d.id.substring(0, 8).toUpperCase() : d.id.toUpperCase();
              if (key.isEmpty) key = 'DEL-${d.id.hashCode.toString().substring(0, 4)}';

              return JiraIssue(
                id: d.id,
                key: key,
                summary: d.title,
                description: d.description,
                status: _mapDeliverableStatusToBoard(d.status),
                priority: d.priority,
                issueType: 'Deliverable',
                assignee: d.ownerName ?? d.assignedToName,
                created: d.createdAt,
                updated: d.dueDate,
              );
            }).toList();
          });
        }
        
        debugPrint('✅ Loaded ${_deliverables.length} deliverables for sprint $sprintId');
      } else {
        debugPrint('❌ Failed to fetch deliverables: ${response.error}');
        _showSnackBar('Failed to load deliverables: ${response.error}', isError: true);
      }
    } catch (e) {
      debugPrint('❌ Error loading deliverables: $e');
      _showSnackBar('Error loading deliverables: $e', isError: true);
    }
  }

  String _mapDeliverableStatusToBoard(DeliverableStatus status) {
    switch (status) {
      case DeliverableStatus.draft:
        return 'To Do';
      case DeliverableStatus.inProgress:
        return 'In Progress';
      case DeliverableStatus.inReview:
      case DeliverableStatus.submitted:
      case DeliverableStatus.changeRequested:
      case DeliverableStatus.rejected:
        return 'In Review';
      case DeliverableStatus.signedOff:
      case DeliverableStatus.approved:
        return 'Done';
    }
  }

  DeliverableStatus _mapBoardStatusToDeliverable(String boardStatus) {
    switch (boardStatus) {
      case 'To Do':
        return DeliverableStatus.draft;
      case 'In Progress':
        return DeliverableStatus.inProgress;
      case 'In Review':
        return DeliverableStatus.inReview;
      case 'Done':
        return DeliverableStatus.signedOff;
      default:
        return DeliverableStatus.draft;
    }
  }

  Future<void> _handleIssueStatusChange(JiraIssue issue, String newStatus) async {
    try {
      final auth = AuthService();
      if (!auth.canEditDeliverable()) {
        _showSnackBar('You do not have permission to update deliverables');
        return;
      }
      
      setState(() {
        _isLoading = true;
      });

      final newDeliverableStatus = _mapBoardStatusToDeliverable(newStatus);
      
      // Update deliverable status in database
      final response = await _deliverableService.updateDeliverableStatus(
        issue.id,
        newDeliverableStatus.name,
      );

      if (response.isSuccess) {
        // Update the issue in the local list
        final index = _issues.indexWhere((i) => i.id == issue.id);
        if (index != -1) {
          setState(() {
            _issues[index] = JiraIssue(
              id: issue.id,
              key: issue.key,
              summary: issue.summary,
              description: issue.description,
              status: newStatus,
              issueType: issue.issueType,
              priority: issue.priority,
              assignee: issue.assignee,
              reporter: issue.reporter,
              created: issue.created,
              updated: DateTime.now(),
              labels: issue.labels,
            );
            _isLoading = false;
          });
          
          // Update sprint progress based on deliverables
          final total = _issues.length;
          final done = _issues.where((i) => i.status == 'Done').length;
          final progress = total > 0 ? (done / total) * 100 : 0.0;
          try {
            await _databaseService.updateSprintProgress(
              sprintId: widget.sprintId,
              progress: progress,
            );
            setState(() {
              _sprintDetails = {
                ...?_sprintDetails,
                'progress': progress,
              };
            });
          } catch (_) {}

          _showSnackBar('Deliverable moved to $newStatus');
        } else {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('Deliverable not found', isError: true);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Failed to update deliverable status: ${response.error}', isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error moving deliverable: $e', isError: true);
    }
  }

  void _showCreateDeliverableDialog() {
    final projectId = _sprintDetails?['project_id']?.toString() ?? _sprintDetails?['projectId']?.toString();
    final params = <String, String>{
      'sprintId': widget.sprintId,
      if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
    };
    final uri = Uri(path: '/enhanced-deliverable-setup', queryParameters: params);
    context.go(uri.toString());
  }


  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? FlownetColors.crimsonRed : FlownetColors.electricBlue,
      ),
    );
  }

  @override
  void dispose() {
    _realtime.offAll('deliverable_created');
    _realtime.offAll('deliverable_updated');
    _realtime.offAll('deliverable_deleted');
    super.dispose();
  }

  Widget _buildSprintHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FlownetColors.charcoalBlack.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlownetColors.electricBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_run, color: FlownetColors.electricBlue, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sprintName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: FlownetColors.pureWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_sprintDetails != null) ...[
                      Text(
                        _sprintDetails!['description'] ?? 'No description',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: FlownetColors.pureWhite.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSprintInfoChip(
                              'Status',
                              (() {
                                final raw = (_sprintDetails!['status'] ??
                                        _sprintDetails!['state'] ??
                                        '')
                                    .toString()
                                    .trim();
                                if (raw.isEmpty) return 'Draft';
                                if (raw.toLowerCase() == 'in_progress') return 'In Progress';
                                return raw;
                              })(),
                              _getStatusColor((_sprintDetails!['status'] ?? _sprintDetails!['state'])?.toString()),
                            ),
                            const SizedBox(width: 12),
                            if (_sprintDetails!['start_date'] != null)
                              _buildSprintInfoChip(
                                'Start',
                                _formatDate(_sprintDetails!['start_date']),
                                FlownetColors.electricBlue,
                              ),
                            const SizedBox(width: 12),
                            if (_sprintDetails!['end_date'] != null)
                              _buildSprintInfoChip(
                                'End',
                                _formatDate(_sprintDetails!['end_date']),
                                FlownetColors.crimsonRed,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildSprintStats(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              DropdownButton<String>(
                value: _normalizeSprintStatus((_sprintDetails?['status'] ?? 'planning')?.toString()),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'planning', child: Text('Planning')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  final auth = AuthService();
                  if (auth.isSystemAdmin) {
                    _showSnackBar('System admin can view/comment only');
                    return;
                  }
                  if (!(auth.isTeamMember || auth.isDeliveryLead)) {
                    _showSnackBar('You do not have permission to update sprint status', isError: true);
                    return;
                  }
                  final oldStatus = (_sprintDetails?['status'] ?? '').toString();
                  final totalIssues = _issues.length;
                  final completedIssues = _issues.where((issue) => issue.status == 'Done').length;
                  final progress = totalIssues > 0 ? (completedIssues / totalIssues) * 100 : 0.0;
                  final ok = await _databaseService.updateSprintStatusHttp(
                    sprintId: widget.sprintId,
                    status: value,
                    progress: progress,
                    oldStatus: oldStatus.isEmpty ? null : oldStatus,
                    sprintName: widget.sprintName,
                  );
                  if (ok) {
                    setState(() {
                      _sprintDetails = {
                        ...?_sprintDetails,
                        'status': value,
                        'progress': progress,
                      };
                    });
                    _showSnackBar('Sprint status updated to $value');
                  } else {
                    _showSnackBar('Failed to update sprint status', isError: true);
                  }
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  final auth = AuthService();
                  if (auth.isSystemAdmin) {
                    _showSnackBar('System admin can view/comment only');
                    return;
                  }
                  _showCreateDeliverableDialog();
                },
                icon: const Icon(Icons.add),
                label: const Text('New Deliverable'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlownetColors.electricBlue,
                  foregroundColor: FlownetColors.pureWhite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _normalizeSprintStatus(String? status) {
    final s = (status ?? '').toLowerCase().trim();
    if (s.isEmpty) return 'draft';
    if (s == 'draft') return 'draft';
    if (s == 'in_progress' || s == 'in progress') return 'in_progress';
    if (s == 'completed' || s == 'done') return 'completed';
    if (s == 'planning' || s == 'planned' || s == 'to do') return 'planning';
    if (s == 'cancelled') return 'cancelled';
    return 'draft';
  }

  Widget _buildSprintInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSprintStats() {
    final totalIssues = _issues.length;
    final completedIssues = _issues.where((issue) => issue.status == 'Done').length;
    final inProgressIssues = _issues.where((issue) => issue.status == 'In Progress').length;
    final progress = totalIssues > 0 ? (completedIssues / totalIssues) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildStatItem('Progress', '${progress.toStringAsFixed(1)}%', FlownetColors.electricBlue),
        const SizedBox(height: 8),
        _buildStatItem('Completed', '$completedIssues/$totalIssues', FlownetColors.electricBlue),
        const SizedBox(height: 8),
        _buildStatItem('In Progress', '$inProgressIssues', FlownetColors.crimsonRed),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: FlownetColors.pureWhite.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyBoard() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: FlownetColors.charcoalBlack.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FlownetColors.electricBlue.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              color: FlownetColors.electricBlue.withValues(alpha: 0.5),
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              'No deliverables yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: FlownetColors.pureWhite.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first deliverable for this project',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: FlownetColors.pureWhite.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateDeliverableDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create First Deliverable'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlownetColors.electricBlue,
                foregroundColor: FlownetColors.pureWhite,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
      case 'active':
      case 'in_progress':
      case 'in progress':
        return FlownetColors.electricBlue;
      case 'completed':
        return Colors.green;
      case 'planning':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return FlownetColors.pureWhite;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final tz = date.toUtc().add(const Duration(hours: 2));
      String two(int n) => n < 10 ? '0$n' : '$n';
      return '${two(tz.day)}/${two(tz.month)}/${tz.year} ${two(tz.hour)}:${two(tz.minute)}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        useBackgroundImage: false,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    final auth = AuthService();
    final canCreateDeliverable = auth.canCreateDeliverable();
    return AppScaffold(
      useBackgroundImage: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Sprint Board - ${widget.sprintName}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/sprint-console');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSprintData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined, color: Colors.white),
            onPressed: () {
              final encodedName = Uri.encodeComponent(widget.sprintName);
              context.push('/sprint-report/${widget.sprintId}?name=$encodedName');
            },
            tooltip: 'Sprint Report',
          ),
          if (canCreateDeliverable)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _showCreateDeliverableDialog,
              tooltip: 'Create Deliverable',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sprint Header
                  _buildSprintHeader(),
                  const SizedBox(height: 32),
                  
                  // Sprint Board
                  if (_issues.isNotEmpty)
                    SprintBoardWidget(
                      sprintId: widget.sprintId,
                      sprintName: widget.sprintName,
                      deliverables: _issues,
                      onDeliverableStatusChanged: _handleIssueStatusChange,
                    )
                  else
                    _buildEmptyBoard(),
                ],
              ),
            ),
      floatingActionButton: canCreateDeliverable
          ? FloatingActionButton.extended(
              onPressed: _showCreateDeliverableDialog,
              backgroundColor: FlownetColors.electricBlue,
              foregroundColor: FlownetColors.pureWhite,
              icon: const Icon(Icons.add),
              label: const Text('Create Deliverable'),
            )
          : null,
    );
  }
}

