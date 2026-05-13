// ignore_for_file: strict_top_level_inference, duplicate_ignore

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import '../theme/flownet_theme.dart';
import '../widgets/project_card.dart';
import 'sprint_board_screen.dart';
import '../services/backend_api_service.dart';
import '../services/realtime_service.dart';
import '../services/auth_service.dart';
import '../services/sprint_database_service.dart';
import '../services/project_service.dart';
import '../services/jira_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_card.dart';

class SprintConsoleScreen extends StatefulWidget {
  final String? initialProjectKey;
  final String? initialSprintId;
  const SprintConsoleScreen({super.key, this.initialProjectKey, this.initialSprintId});

  @override
  State<SprintConsoleScreen> createState() => _SprintConsoleScreenState();
}

class _SprintConsoleScreenState extends State<SprintConsoleScreen> {
  static const Color _headerCtaRed = Color(0xFFD70E0E);

  final SprintDatabaseService _sprintService = SprintDatabaseService();
  // State variables
  final List<Map<String, dynamic>> _projects = [];
  String? _selectedProjectKey;
  String? _selectedSprintId;
  bool _useAiForTicket = false;
  final bool _isGeneratingAiTicket = false;
  final GlobalKey _sprintsSectionKey = GlobalKey();
  final GlobalKey _ticketsSectionKey = GlobalKey();

  final List<Map<String, dynamic>> _sprints = [];
  final List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = false;

  late RealtimeService _realtime;
  // Navigate to project creation screen
  Future<void> _navigateToCreateProject() async {
    final result = await context.push<bool>('/project-workspace/new');
    if (!mounted) return;
    if (result == true) {
      await _loadData();
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedProjectKey = widget.initialProjectKey;
    _selectedSprintId = widget.initialSprintId;
    _loadData();
    _setupRealtime();
  }

  @override
  void dispose() {
    try {
      _realtime.offAll('ticket_created');
      _realtime.offAll('ticket_updated');
      _realtime.offAll('ticket_deleted');
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool isUuidLike(String v) {
        final s = v.trim();
        return RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(s) && s.contains('-');
      }

      if (_selectedProjectKey == null || _selectedProjectKey!.isEmpty) {
        try {
          await _sprintService.backfillSprintProjects();
        } catch (_) {}
      }
      // Load projects from same API as Project Workspace so new projects appear everywhere
      final projectList = await ProjectService.getAllProjects(limit: 1000);
      final projects = projectList.map((p) => p.toJson()).toList();
      List<Map<String, dynamic>> sprints;
      if (_selectedProjectKey != null && _selectedProjectKey!.isNotEmpty) {
        final selectedKey = _selectedProjectKey!.trim();
        final selected = projects.firstWhere(
          (p) {
            final key = p['key']?.toString();
            final id = p['id']?.toString();
            return key == selectedKey || id == selectedKey;
          },
          orElse: () => <String, dynamic>{},
        );
        final pid = (selected['id']?.toString() ?? '').trim();
        final pkey = (selected['key']?.toString() ?? '').trim();
        final fallbackPid = isUuidLike(selectedKey) ? selectedKey : '';
        final fallbackPkey = (!isUuidLike(selectedKey)) ? selectedKey : '';
        sprints = await _sprintService.getSprints(
          projectId: pid.isNotEmpty ? pid : (fallbackPid.isNotEmpty ? fallbackPid : null),
          projectKey: pkey.isNotEmpty ? pkey : (fallbackPkey.isNotEmpty ? fallbackPkey : null),
        );
      } else {
        sprints = await _sprintService.getSprints();
      }
      setState(() {
        _projects.clear();
        _projects.addAll(projects);
        _sprints.clear();
        _sprints.addAll(sprints);
      });

      // If a project is preselected, ensure sprints section is visible
      if (_selectedProjectKey != null && _selectedProjectKey!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _sprintsSectionKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.1,
              duration: const Duration(milliseconds: 300),
            );
          }
        });
      }

      // Load tickets if sprint is selected
      if (_selectedSprintId != null) {
        await _loadTickets();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _ticketsSectionKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.1,
              duration: const Duration(milliseconds: 300),
            );
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error loading data: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupRealtime() {
    _realtime = RealtimeService();
    _realtime.initialize(authToken: AuthService().accessToken);
    _realtime.on('ticket_created', (data) {
      try {
        final sid = (data['sprint_id'] ?? data['sprintId'] ?? '').toString();
        if (sid.isNotEmpty &&
            _selectedSprintId != null &&
            sid == _selectedSprintId) {
          _loadTickets();
        }
      } catch (_) {}
    });
    _realtime.on('ticket_updated', (data) {
      try {
        final sid = (data['sprint_id'] ?? data['sprintId'] ?? '').toString();
        if (sid.isNotEmpty &&
            _selectedSprintId != null &&
            sid == _selectedSprintId) {
          _loadTickets();
        }
      } catch (_) {}
    });
    _realtime.on('ticket_deleted', (data) {
      try {
        final sid = (data['sprint_id'] ?? data['sprintId'] ?? '').toString();
        if (sid.isNotEmpty &&
            _selectedSprintId != null &&
            sid == _selectedSprintId) {
          _loadTickets();
        }
      } catch (_) {}
    });
  }

  Future<void> _loadTickets() async {
    if (_selectedSprintId == null) return;

    try {
      final tickets = await _sprintService.getSprintTickets(_selectedSprintId!);
      setState(() {
        _tickets.clear();
        _tickets.addAll(tickets);
      });
    } catch (e) {
      _showSnackBar('Error loading tickets: $e', isError: true);
    }
  }

  // Helper method to show a snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // Handle project selection
  void _selectProject(Map<String, dynamic> project) {
    if (!mounted) return;

    setState(() {
      _selectedProjectKey =
          project['key']?.toString() ?? project['id']?.toString();
      _selectedSprintId = null; // Reset selected sprint when project changes
      _tickets.clear(); // Clear tickets when project changes
    });

    // Navigate to sprint console with project filter
    final keyOrId = _selectedProjectKey;
    if (keyOrId != null && keyOrId.isNotEmpty) {
      context.go('/sprint-console?projectKey=${Uri.encodeComponent(keyOrId)}');
    } else {
      _loadSprints(project);
    }
  }

  // Load sprints for a specific project
  Future<void> _loadSprints(Map<String, dynamic> project) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final projectId = project['id']?.toString();
      final projectKey = project['key']?.toString();

      final fetched = await _sprintService.getSprints(
        projectId:
            (projectId != null && projectId.isNotEmpty) ? projectId : null,
        projectKey:
            (projectKey != null && projectKey.isNotEmpty) ? projectKey : null,
      );

      setState(() {
        _sprints
          ..clear()
          ..addAll(fetched);
      });

      // If we have an initial sprint ID, select it
      if (_selectedSprintId != null) {
        final sprint = _sprints.firstWhere(
          (s) => s['id']?.toString() == _selectedSprintId,
          orElse: () => <String, dynamic>{},
        );
        if (sprint.isNotEmpty) {
          // Select without navigating to board immediately to avoid double navigation
          _selectSprint(sprint, navigateToBoard: false);
        }
      }

      // Auto-scroll to sprints section after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _sprintsSectionKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.1,
            duration: const Duration(milliseconds: 300),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading sprints: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Handle sprint selection
  void _selectSprint(Map<String, dynamic> sprint, {bool navigateToBoard = true}) {
    if (!mounted) return;

    setState(() {
      _selectedSprintId = sprint['id']?.toString();
    });

    // Load tickets for the selected sprint
    _loadTickets();

    // Navigate to sprint board (UI navigation only; does not change data logic)
    if (!navigateToBoard) return;
    final sprintId = sprint['id']?.toString();
    if (sprintId != null) {
      final sprintName = sprint['name']?.toString() ?? 'Sprint Board';
      context.push(
          '/sprint-board/$sprintId?name=${Uri.encodeComponent(sprintName)}');
    }
  }

  // Map ticket to issue format
  Map<String, dynamic> _mapTicketToIssue(Map<String, dynamic> ticket) {
    return {
      'id': ticket['id'],
      'key': ticket['key'] ?? 'TKT-${ticket['id']}',
      'fields': {
        'summary': ticket['title'] ?? 'No title',
        'status': {'name': ticket['status'] ?? 'To Do'},
        'priority': {'name': ticket['priority'] ?? 'Medium'},
        'issuetype': {'name': ticket['type'] ?? 'Task'},
      },
    };
  }

  // Update sprint status
  Future<void> _updateSprintStatus(String sprintId, String newStatus) async {
    if (!mounted) return;

    try {
      final messenger = ScaffoldMessenger.of(context);
      final auth = AuthService();
      if (!(auth.isTeamMember || auth.isDeliveryLead || auth.isSystemAdmin)) {
        _showSnackBar('You do not have permission to update sprint status',
            isError: true);
        return;
      }

      bool isCompletingStatus(String v) {
        final n = v.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
        return n == 'completed' || n == 'done' || n == 'closed';
      }

      bool missingRequiredMetrics(Map<String, dynamic> s) {
        final testPassRate = s['test_pass_rate'] ?? s['testPassRate'];
        final defectsOpened = s['defects_opened'] ?? s['defectsOpened'];
        final defectsClosed = s['defects_closed'] ?? s['defectsClosed'];
        final codeReview = s['code_review_completion'] ?? s['codeReviewCompletion'];
        final documentation = s['documentation_status'] ?? s['documentationStatus'];
        return testPassRate == null ||
            defectsOpened == null ||
            defectsClosed == null ||
            codeReview == null ||
            documentation == null;
      }

      if (isCompletingStatus(newStatus)) {
        try {
          final sprintResp = await BackendApiService().getSprint(sprintId);
          if (sprintResp.isSuccess && sprintResp.data != null) {
            final raw = sprintResp.data;
            final data = raw is Map && raw['data'] is Map
                ? Map<String, dynamic>.from(raw['data'] as Map)
                : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
            if (missingRequiredMetrics(data)) {
              if (!mounted) return;
              _showSnackBar('Complete sprint metrics before marking the sprint as completed.', isError: true);
              await context.push('/sprint-metrics/$sprintId');
              final refreshed = await BackendApiService().getSprint(sprintId);
              final rraw = refreshed.isSuccess ? refreshed.data : null;
              final rdata = rraw is Map && rraw['data'] is Map
                  ? Map<String, dynamic>.from(rraw['data'] as Map)
                  : (rraw is Map ? Map<String, dynamic>.from(rraw) : <String, dynamic>{});
              if (missingRequiredMetrics(rdata)) {
                if (!mounted) return;
                _showSnackBar('Sprint metrics are still incomplete. Sprint status was not changed.', isError: true);
                return;
              }
            }
          }
        } catch (_) {}
      }

      setState(() {
        _isLoading = true;
      });

      final sprintIndex =
          _sprints.indexWhere((s) => s['id'].toString() == sprintId);
      if (sprintIndex == -1) return;

      final current = Map<String, dynamic>.from(_sprints[sprintIndex]);
      final oldStatus = (current['status'] ?? '').toString();
      final sprintName = (current['name'] ?? '').toString();

      final ok = await _sprintService.updateSprintStatus(
        sprintId: sprintId,
        status: newStatus,
        oldStatus: oldStatus.isEmpty ? null : oldStatus,
        sprintName: sprintName.isEmpty ? null : sprintName,
      );

      if (ok) {
        final updated = Map<String, dynamic>.from(current);
        updated['status'] = newStatus;
        setState(() {
          _sprints[sprintIndex] = updated;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Sprint status updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to update sprint status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update sprint status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmAndDeleteSprint(
      String sprintId, String sprintName) async {
    if (!mounted) return;
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Delete Sprint'),
            content: Text('Delete "$sprintName"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
      if (result != true) return;

      setState(() {
        _isLoading = true;
      });
      final ok = await _sprintService.deleteSprint(sprintId);
      // ignore: use_build_context_synchronously
      final messenger = ScaffoldMessenger.of(context);
      if (ok) {
        setState(() {
          _sprints.removeWhere((s) => s['id'].toString() == sprintId);
          if (_selectedSprintId == sprintId) _selectedSprintId = null;
        });
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Sprint deleted'), backgroundColor: Colors.green),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Failed to delete sprint'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error deleting sprint: $e'),
            backgroundColor: Colors.red),
      );
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
    if (_isLoading) {
      return AppScaffold(
        useBackgroundImage: false,
        useGlassContainer: false,
        centered: false,
        scrollable: false,
        appBar: _buildSprintAppBar(),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
          ),
        ),
      );
    }

    return AppScaffold(
      useBackgroundImage: false,
      useGlassContainer: false,
      centered: false,
      scrollable: false,
      appBar: _buildSprintAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Projects or Sprints Section
          if (_selectedProjectKey == null) ...[
            _buildProjectsSection(),
            const SizedBox(height: 24),
            // _buildAllSprintsSection(), // Hidden as per request to nest sprints under projects
          ] else ...[
            _buildSelectedProjectSprintsView(),
          ],
          const SizedBox(height: 24),

          // Tickets Section (conditionally shown when a sprint is selected)
          if (_selectedSprintId != null) ...[
            Container(
              key: _ticketsSectionKey,
              child: _buildTicketsSection(),
            ),
          ],

          // Add some bottom padding
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSprintAppBar() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final auth = AuthService();
    final canCreateSprint = auth.hasPermission('create_sprint');
    final canManageProjects = auth.hasPermission('manage_projects');
    final showListActions = _selectedProjectKey == null;

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: kToolbarHeight + 40,
      titleSpacing: 16,
      title: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: Transform.scale(
                  scale: 1.6,
                  child: Image.asset(
                    'assets/Points.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.dashboard,
                      size: 18,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sprints Management',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your projects, sprints, and tickets in one place',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: onSurface.withAlpha(230),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (showListActions && (canCreateSprint || canManageProjects))
          Padding(
            padding: const EdgeInsets.only(top: 10, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canCreateSprint)
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _showCreateSprintDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _headerCtaRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        'Create Sprint',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (canCreateSprint && canManageProjects) const SizedBox(width: 8),
                if (canManageProjects)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: _navigateToCreateProject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _headerCtaRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        'Create Project',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProjectsSection() {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Projects',
          style: theme.textTheme.titleLarge?.copyWith(
            color: onSurfaceColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_selectedProjectKey == null)
          Text(
            'Select a project to create sprints',
            style: TextStyle(
              color: onSurfaceColor.withAlpha(179),
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 16),
        if (_selectedProjectKey != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              blur: 8.0,
              color: Colors.white.withAlpha(12),
              border: Border.all(color: Colors.white.withAlpha(18), width: 0.8),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromARGB(16, 0, 0, 0),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                  offset: Offset(0, 4),
                ),
              ],
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected project: ${_projects.firstWhere(
                        (p) {
                          final keyOrId =
                              p['key']?.toString() ?? p['id']?.toString();
                          return keyOrId == _selectedProjectKey;
                        },
                        orElse: () => {'name': 'Unknown'},
                      )['name']}',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_projects.isEmpty)
          _buildEmptyState(
            'No projects yet',
            'Create your first project to get started',
          )
        else
          _buildProjectsGrid(),
      ],
    );
  }


  Widget _buildSelectedProjectSprintsView() {
    Map<String, dynamic> selected = const {};
    try {
      selected = _projects.firstWhere(
        (p) {
          final keyOrId = p['key']?.toString() ?? p['id']?.toString();
          return keyOrId == _selectedProjectKey;
        },
        orElse: () => <String, dynamic>{},
      );
    } catch (_) {}
    if (selected.isEmpty) {
      final key = (_selectedProjectKey ?? '').toString().trim();
      if (key.isNotEmpty) {
        selected = <String, dynamic>{
          'id': key,
          'key': key,
          'name': key,
        };
      }
    }
    return _buildProjectNestedSprints(selected);
  }

  int _calculateCrossAxisCount(double width) {
    if (width > 1200) return 4;
    if (width > 900) return 3;
    if (width > 600) return 2;
    return 1;
  }

  Widget _buildProjectsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            _calculateCrossAxisCount(MediaQuery.of(context).size.width),
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        final projectKey =
            project['key']?.toString() ?? project['id']?.toString();
        final isSelected = _selectedProjectKey == projectKey;

        return ProjectCard(
          project: project,
          isSelected: isSelected,
          onTap: () => _selectProject(project),
          onEdit: () {
            final projectId = project['id']?.toString();
            if (projectId != null) {
              context.push('/project-workspace/$projectId');
            }
          },
        );
      },
    );
  }

  Widget _buildProjectNestedSprints(Map<String, dynamic> project) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;
    final projectName =
        project['name']?.toString() ?? _selectedProjectKey ?? 'Project';
    final projectId = project['id']?.toString();
    final projectKey = project['key']?.toString();

    // Check if there are any active (non-completed) sprints for this project
    final projectSprints = _sprints.where((s) {
      try {
        final pid = (s['project_id'] ?? s['projectId'] ?? (s['project'] is Map ? s['project']['id'] : null))?.toString();
        final pkey = (s['project_key'] ?? s['projectKey'] ?? (s['project'] is Map ? s['project']['key'] : null))?.toString();
        if (projectId != null && projectId.isNotEmpty && pid == projectId) return true;
        if (projectKey != null && projectKey.isNotEmpty && pkey == projectKey) return true;
      } catch (_) {}
      return false;
    }).toList();

    final hasActiveSprint = projectSprints.any((s) {
      final status = (s['status'] ?? '').toString().toLowerCase();
      return status != 'completed' && status != 'done';
    });

    // Check permissions
    final auth = AuthService();

    return Column(
      key: _sprintsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      setState(() {
                        _selectedProjectKey = null;
                        _selectedSprintId = null;
                        _sprints.clear();
                        _tickets.clear();
                      });
                      context.go('/sprint-console');
                      _loadData();
                    },
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sprints in $projectName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onSurfaceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (auth.hasPermission('create_sprint'))
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: ElevatedButton.icon(
                  onPressed: hasActiveSprint ? null : _showCreateSprintDialog,
                  icon: const Icon(Icons.add),
                  label: Text(
                    hasActiveSprint ? 'Complete active sprint' : 'Create sprint',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasActiveSprint ? Colors.grey : primaryColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (projectSprints.isEmpty)
          _buildEmptyState(
            'No sprints for this project',
            'Create a sprint for the selected project to start planning',
          )
        else
          _buildSprintsList(
            _sprints.where((s) {
              try {
                final pid = (s['project_id'] ??
                        s['projectId'] ??
                        (s['project'] is Map ? s['project']['id'] : null))
                    ?.toString();
                final pkey = (s['project_key'] ??
                        s['projectKey'] ??
                        (s['project'] is Map ? s['project']['key'] : null))
                    ?.toString();
                if (projectId != null &&
                    projectId.isNotEmpty &&
                    pid == projectId) {
                  return true;
                }
                if (projectKey != null &&
                    projectKey.isNotEmpty &&
                    pkey == projectKey) {
                  return true;
                }

                // Heuristic: match by name or description containing project name/key
                final name = (s['name'] ?? '').toString().toLowerCase();
                final desc = (s['description'] ?? '').toString().toLowerCase();
                final pName = projectName.toLowerCase();
                final pKey = (projectKey ?? '').toLowerCase();
                if (pName.isNotEmpty &&
                    (name.contains(pName) || desc.contains(pName))) {
                  return true;
                }
                if (pKey.isNotEmpty &&
                    (name.contains(pKey) || desc.contains(pKey))) {
                  return true;
                }
              } catch (_) {}
              return false;
            }).toList(),
          ),
      ],
    );
  }

  // Get color based on status
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'in_progress':
      case 'in progress':
      case 'active':
        return Colors.blue;
      case 'completed':
      case 'done':
        return Colors.green;
      case 'planning':
      case 'planned':
      case 'to do':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStatusLabel(String? status) {
    final s = (status ?? '').toString().trim();
    if (s.isEmpty) return 'DRAFT';
    final lower = s.toLowerCase();
    if (lower == 'in_progress') return 'IN PROGRESS';
    if (lower == 'in progress') return 'IN PROGRESS';
    if (lower == 'to do') return 'PLANNING';
    return s.toUpperCase();
  }

  String _mapSprintStatusSelection(String value) {
    final v = value.toLowerCase().replaceAll('_', '').replaceAll(' ', '').trim();
    if (v == 'todo' || v == 'planning' || v == 'planned') return 'planning';
    if (v == 'inprogress' || v == 'active') return 'in_progress';
    if (v == 'done' || v == 'completed') return 'completed';
    if (v == 'cancelled' || v == 'canceled') return 'cancelled';
    return value;
  }

  bool _canEditSprint(Map<String, dynamic> sprint) {
    final auth = AuthService();
    if (auth.isSystemAdmin || auth.isDeliveryLead || auth.hasPermission('create_sprint')) {
      return true;
    }
    final uid = auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return false;

    final sprintProjectId = (sprint['project_id'] ?? sprint['projectId'])?.toString();
    if (sprintProjectId == null || sprintProjectId.isEmpty) return false;

    try {
      final project = _projects.firstWhere(
        (p) => (p['id']?.toString() ?? '') == sprintProjectId,
        orElse: () => <String, dynamic>{},
      );
      final ownerId = (project['ownerId'] ?? project['owner_id'])?.toString() ??
          (project['owner'] is Map ? (project['owner']['id']?.toString()) : null);
      return ownerId != null && ownerId.isNotEmpty && ownerId == uid;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> _openCreateSprintRoute({
    String? projectId,
    String? projectName,
    Map<String, dynamic>? sprint,
  }) async {
    final params = <String, String>{};
    if (projectId != null && projectId.isNotEmpty) {
      params['projectId'] = projectId;
    }
    if (projectName != null && projectName.isNotEmpty) {
      params['projectName'] = projectName;
    }
    final uri = Uri(
      path: '/sprint-create',
      queryParameters: params.isEmpty ? null : params,
    );
    return context.push<bool>(uri.toString(), extra: sprint);
  }

  Future<void> _editSprint(Map<String, dynamic> sprint) async {
    if (!_canEditSprint(sprint)) {
      _showSnackBar('You do not have permission to edit this sprint', isError: true);
      return;
    }

    final sprintProjectId = (sprint['project_id'] ?? sprint['projectId'])?.toString();
    String? projectName;
    String? projectId;
    if (sprintProjectId != null && sprintProjectId.isNotEmpty) {
      projectId = sprintProjectId;
      try {
        final project = _projects.firstWhere(
          (p) => (p['id']?.toString() ?? '') == sprintProjectId,
          orElse: () => <String, dynamic>{},
        );
        projectName = project['name']?.toString();
      } catch (_) {}
    }

    final ok = await _openCreateSprintRoute(
      projectId: projectId,
      projectName: projectName,
      sprint: sprint,
    );

    if (ok == true) {
      await _loadData();
    }
  }

  Widget _buildSprintsList(List<Map<String, dynamic>> sprints) {
    // Get project dates for validation flags
    DateTime? projectStartDate;
    DateTime? projectEndDate;
    if (_selectedProjectKey != null) {
      final project = _projects.firstWhere(
        (p) => p['id']?.toString() == _selectedProjectKey || p['key']?.toString() == _selectedProjectKey,
        orElse: () => <String, dynamic>{},
      );
      if (project.isNotEmpty) {
        if (project['start_date'] != null) projectStartDate = DateTime.tryParse(project['start_date'].toString());
        if (projectStartDate == null && project['startDate'] != null) projectStartDate = DateTime.tryParse(project['startDate'].toString());
        
        if (project['end_date'] != null) projectEndDate = DateTime.tryParse(project['end_date'].toString());
        if (projectEndDate == null && project['endDate'] != null) projectEndDate = DateTime.tryParse(project['endDate'].toString());
      }
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sprints.length,
      itemBuilder: (context, index) {
        final sprint = sprints[index];
        final isSelected = _selectedSprintId == sprint['id']?.toString();
        
        // Calculate if sprint is out of project date range
        DateTime? sprintStart;
        DateTime? sprintEnd;
        if (sprint['start_date'] != null) {
          sprintStart = DateTime.tryParse(sprint['start_date'].toString());
        }
        if (sprint['end_date'] != null) {
          sprintEnd = DateTime.tryParse(sprint['end_date'].toString());
        }
        final bool isOutOfRange = (projectStartDate != null && sprintStart != null && sprintStart.isBefore(projectStartDate)) ||
                                  (projectEndDate != null && sprintEnd != null && sprintEnd.isAfter(projectEndDate));

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isOutOfRange ? Border.all(color: Colors.red.withAlpha(128), width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withAlpha(77),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOutOfRange ? Colors.red.withAlpha(128) : Colors.white.withAlpha(128),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectSprint(sprint),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Leading icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isOutOfRange 
                                  ? Colors.red.withAlpha(51)
                                  : (isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withAlpha(51)
                                      : Theme.of(context)
                                          .colorScheme
                                          .error
                                          .withAlpha(26)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isOutOfRange
                                    ? Colors.red.withAlpha(128)
                                    : (isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withAlpha(51)
                                        : Theme.of(context)
                                            .colorScheme
                                            .error
                                            .withAlpha(26)),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              isOutOfRange ? Icons.warning_amber_rounded : (isSelected ? Icons.done : Icons.directions_run),
                              color: isOutOfRange ? Colors.red : (isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Sprint details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sprint['name']?.toString() ??
                                      'Unknown Sprint',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${sprint['start_date']?.toString() ?? 'No start date'} - ${sprint['end_date']?.toString() ?? 'No end date'}',
                                  style: TextStyle(
                                    color: isOutOfRange ? Colors.red : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha(179),
                                    fontSize: 12,
                                    fontWeight: isOutOfRange ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: getStatusColor((sprint['status'] ?? '').toString())
                                        .withAlpha(26),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: getStatusColor((sprint['status'] ?? '').toString())
                                          .withAlpha(77),
                                    ),
                                  ),
                                  child: Text(
                                    getStatusLabel(sprint['status']?.toString()),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: getStatusColor((sprint['status'] ?? '').toString()),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    final sid = sprint['id'].toString();
                                    if (value == 'edit') {
                                      _editSprint(sprint);
                                      return;
                                    }
                                    if (value == 'delete') {
                                      _confirmAndDeleteSprint(
                                          sid,
                                          sprint['name']?.toString() ??
                                              'Sprint');
                                    } else {
                                      _updateSprintStatus(sid, _mapSprintStatusSelection(value));
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (_canEditSprint(sprint)) ...[
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit Sprint'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                    ],
                                    if (AuthService().hasPermission('update_sprint_status')) ...[
                                      const PopupMenuItem(
                                        value: 'To Do',
                                        child: Text('Mark as To Do'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'In Progress',
                                        child: Text('Mark as In Progress'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'Done',
                                        child: Text('Mark as Done'),
                                      ),
                                    ],
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete Sprint', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_vert,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(26),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void viewSprintBoard(Map<String, dynamic> sprint) {
    // Navigate to sprint board screen with sprint name
    GoRouter.of(context).go(
        '/sprint-board/${sprint['id']}?name=${Uri.encodeComponent(sprint['name'])}');
  }

  void viewSprintDetails(Map<String, dynamic> sprint) {
    // Navigate to sprint detail screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SprintBoardScreen(
          sprintId: sprint['id'].toString(),
          sprintName: (sprint['name'] ?? 'Sprint').toString(),
          projectKey: sprint['project_id']?.toString(),
        ),
      ),
    );
  }

  void _showCreateSprintDialog() async {
    // Allow creating sprint even without pre-selecting a project
    // The CreateSprintScreen will show a project dropdown if no project is selected

    debugPrint(
        '🔵 _showCreateSprintDialog called - showing CreateSprintScreen');

    // Ensure projects are loaded so we can resolve projectId and CreateSprintScreen has data
    if (_projects.isEmpty) {
      await _loadData();
    }

    String? projectId;
    String? projectName;
    final key = _selectedProjectKey;

    if (key != null && key.isNotEmpty) {
      try {
        final selectedProject = _projects.firstWhere(
          (p) {
            final pid = p['id']?.toString();
            final pkey = p['key']?.toString();
            return pid == key || pkey == key;
          },
        );
        projectId = selectedProject['id']?.toString();
        projectName = selectedProject['name']?.toString();
        if (projectId != null && projectId.isNotEmpty) {
          debugPrint('🔵 Selected project: $projectName (ID: $projectId)');
        }
      } catch (e) {
        debugPrint('⚠️ Selected project not found: $e');
      }
    } else {
      debugPrint('🔵 No project selected - will show project dropdown');
    }

    if (!mounted) return;
    // Always show CreateSprintScreen - never redirect to project creation
    debugPrint(
        '🔵 Pushing CreateSprintScreen with projectId: $projectId, projectName: $projectName');
    final result = await _openCreateSprintRoute(
      projectId: projectId,
      projectName: projectName,
    );

    debugPrint('🔵 CreateSprintScreen returned: $result');
    if (result == true) {
      _loadData();
    }
  }

  // AI suggestion methods removed as they are now handled in CreateSprintScreen

  Widget _buildTicketsSection() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (_tickets.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tickets',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: showCreateTicketDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Ticket'),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEmptyState(
            'No tickets in this sprint',
            'Add tickets to this sprint to start tracking work',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tickets',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: showCreateTicketDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Ticket'),
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _tickets.length,
          itemBuilder: (context, index) {
            final ticket = _tickets[index];
            final mappedTicket = _mapTicketToIssue(ticket);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withAlpha(77),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(26),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(mappedTicket['fields']['summary'] ?? 'No title'),
                subtitle: Text(mappedTicket['key'] ?? ''),
                onTap: () {},
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () {},
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void showCreateTicketDialog() {
    if (_selectedSprintId == null) {
      _showSnackBar('Select a sprint first', isError: true);
      return;
    }
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final assigneeController = TextEditingController();
    final aiPromptController = TextEditingController();
    String selectedPriority = 'Medium';
    String selectedType = 'Task';

    showDialog(
      context: context,
      builder: (context) {
        bool useAi = _useAiForTicket;
        bool isGenerating = _isGeneratingAiTicket;
        return StatefulBuilder(
          builder: (context, dialogSetState) => AlertDialog(
            backgroundColor: FlownetColors.charcoalBlack,
            title: const Text('Create Ticket',
                style: TextStyle(color: FlownetColors.pureWhite)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          value: useAi,
                          onChanged: (v) {
                            dialogSetState(() {
                              useAi = v;
                            });
                            setState(() {
                              _useAiForTicket = v;
                            });
                          },
                          title: const Text('Use AI Assistance',
                              style: TextStyle(color: FlownetColors.pureWhite)),
                        ),
                      ),
                    ],
                  ),
                  if (useAi) ...[
                    TextField(
                      controller: aiPromptController,
                      maxLines: 3,
                      style: const TextStyle(color: FlownetColors.pureWhite),
                      decoration: const InputDecoration(
                        labelText: 'AI Prompt (requirements/context)',
                        labelStyle:
                            TextStyle(color: FlownetColors.electricBlue),
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: FlownetColors.electricBlue),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: FlownetColors.electricBlue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: isGenerating
                            ? null
                            : () async {
                                dialogSetState(() {
                                  isGenerating = true;
                                });
                                try {
                                  final backend = BackendApiService();
                                  final foundSprint = _sprints.firstWhere(
                                    (s) =>
                                        (s['id']?.toString() ?? '') ==
                                        _selectedSprintId,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  final sprintName =
                                      foundSprint['name']?.toString() ?? '';
                                  final messages = [
                                    {
                                      'role': 'system',
                                      'content':
                                          'Generate a sprint ticket. Return JSON with keys: title, description. Include acceptance criteria as bullet points inside description. Keep language clear and actionable.'
                                    },
                                    {
                                      'role': 'user',
                                      'content':
                                          'Sprint: $sprintName. Requirements: ${aiPromptController.text}'
                                              .trim()
                                    }
                                  ];
                                  final resp = await backend.aiChat(messages,
                                      temperature: 0.5, maxTokens: 320);
                                  if (resp.isSuccess && resp.data != null) {
                                    final data = resp.data is Map
                                        ? Map<String, dynamic>.from(
                                            resp.data as Map)
                                        : {};
                                    final content = (data['content'] ??
                                                (data['data']?['content']))
                                            ?.toString() ??
                                        '';
                                    String t = '';
                                    String d = '';
                                    try {
                                      Map<String, dynamic>? parsed;
                                      if (content.trim().startsWith('{')) {
                                        parsed = Map<String, dynamic>.from(
                                            jsonDecode(content));
                                      } else if (content.contains('{') &&
                                          content.contains('}')) {
                                        final start = content.indexOf('{');
                                        final end = content.lastIndexOf('}');
                                        if (start >= 0 && end > start) {
                                          final jsonStr =
                                              content.substring(start, end + 1);
                                          parsed = Map<String, dynamic>.from(
                                              jsonDecode(jsonStr));
                                        }
                                      }
                                      if (parsed != null) {
                                        t = (parsed['title'] ?? '').toString();
                                        d = (parsed['description'] ?? '')
                                            .toString();
                                      }
                                    } catch (_) {}
                                    if (t.isEmpty) {
                                      final lines = content
                                          .split('\n')
                                          .where((e) => e.trim().isNotEmpty)
                                          .toList();
                                      t = lines.isNotEmpty
                                          ? lines.first.trim()
                                          : 'New Sprint Ticket';
                                      d = lines.skip(1).join('\n').trim();
                                      if (d.isEmpty) d = content.trim();
                                    }
                                    titleController.text = t;
                                    descriptionController.text = d;
                                  }
                                } catch (_) {}
                                dialogSetState(() {
                                  isGenerating = false;
                                });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FlownetColors.electricBlue,
                          foregroundColor: FlownetColors.pureWhite,
                        ),
                        icon: isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome),
                        label: const Text('Generate with AI'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: FlownetColors.pureWhite),
                    decoration: const InputDecoration(
                      labelText: 'Ticket Title',
                      labelStyle: TextStyle(color: FlownetColors.electricBlue),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: FlownetColors.electricBlue),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: FlownetColors.electricBlue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    style: const TextStyle(color: FlownetColors.pureWhite),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: FlownetColors.electricBlue),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: FlownetColors.electricBlue),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: FlownetColors.electricBlue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: assigneeController,
                    style: const TextStyle(color: FlownetColors.pureWhite),
                    decoration: const InputDecoration(
                      labelText: 'Assignee Email',
                      labelStyle: TextStyle(color: FlownetColors.electricBlue),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: FlownetColors.electricBlue),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: FlownetColors.electricBlue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedPriority,
                          style:
                              const TextStyle(color: FlownetColors.pureWhite),
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            labelStyle:
                                TextStyle(color: FlownetColors.electricBlue),
                            border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: FlownetColors.electricBlue),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: FlownetColors.electricBlue, width: 2),
                            ),
                          ),
                          dropdownColor: FlownetColors.charcoalBlack,
                          items: const [
                            DropdownMenuItem(
                                value: 'Low',
                                child: Text('Low',
                                    style: TextStyle(
                                        color: FlownetColors.pureWhite))),
                            DropdownMenuItem(
                                value: 'Medium',
                                child: Text('Medium',
                                    style: TextStyle(
                                        color: FlownetColors.pureWhite))),
                            DropdownMenuItem(
                                value: 'High',
                                child: Text('High',
                                    style: TextStyle(
                                        color: FlownetColors.pureWhite))),
                            DropdownMenuItem(
                                value: 'Critical',
                                child: Text('Critical',
                                    style: TextStyle(
                                        color: FlownetColors.pureWhite))),
                          ],
                          onChanged: (value) => dialogSetState(
                              () => selectedPriority = value ?? 'Medium'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          style:
                              const TextStyle(color: FlownetColors.pureWhite),
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            labelStyle:
                                TextStyle(color: FlownetColors.electricBlue),
                            border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: FlownetColors.electricBlue),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: FlownetColors.electricBlue, width: 2),
                            ),
                          ),
                          dropdownColor: FlownetColors.charcoalBlack,
                          items: const [
                            DropdownMenuItem(
                                value: 'Task',
                                child: Text('Task',
                                    style: TextStyle(
                                        color: FlownetColors.pureWhite))),
                            DropdownMenuItem(
                                value: 'Bug',
                                child: Text('Bug',
                                    style: TextStyle(
                                        color: FlownetColors.pureWhite))),
                            DropdownMenuItem(
                                value: 'Story',
                                child: Text('Story',
                                    style: TextStyle(
                                        color: FlownetColors.pureWhite))),
                            DropdownMenuItem(
                                value: 'Epic',
                                child: Text('Epic',
                                    style: TextStyle(
                                        color: FlownetColors.pureWhite))),
                          ],
                          onChanged: (value) => dialogSetState(
                              () => selectedType = value ?? 'Task'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: FlownetColors.pureWhite)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  try {
                    if (useAi &&
                        (titleController.text.isEmpty ||
                            descriptionController.text.isEmpty)) {
                      dialogSetState(() {
                        isGenerating = true;
                      });
                      try {
                        final backend = BackendApiService();
                        final foundSprint = _sprints.firstWhere(
                          (s) =>
                              (s['id']?.toString() ?? '') == _selectedSprintId,
                          orElse: () => <String, dynamic>{},
                        );
                        final sprintName =
                            foundSprint['name']?.toString() ?? '';
                        final messages = [
                          {
                            'role': 'system',
                            'content':
                                'Generate a sprint ticket. Return JSON with keys: title, description. Include acceptance criteria as bullet points inside description. Keep language clear and actionable.'
                          },
                          {
                            'role': 'user',
                            'content':
                                'Sprint: $sprintName. Requirements: ${aiPromptController.text}'
                                    .trim()
                          }
                        ];
                        final resp = await backend.aiChat(messages,
                            temperature: 0.5, maxTokens: 320);
                        if (resp.isSuccess && resp.data != null) {
                          final data = resp.data is Map
                              ? Map<String, dynamic>.from(resp.data as Map)
                              : {};
                          final content =
                              (data['content'] ?? (data['data']?['content']))
                                      ?.toString() ??
                                  '';
                          String t = '';
                          String d = '';
                          try {
                            Map<String, dynamic>? parsed;
                            if (content.trim().startsWith('{')) {
                              parsed = Map<String, dynamic>.from(
                                  jsonDecode(content));
                            } else if (content.contains('{') &&
                                content.contains('}')) {
                              final start = content.indexOf('{');
                              final end = content.lastIndexOf('}');
                              if (start >= 0 && end > start) {
                                final jsonStr =
                                    content.substring(start, end + 1);
                                parsed = Map<String, dynamic>.from(
                                    jsonDecode(jsonStr));
                              }
                            }
                            if (parsed != null) {
                              t = (parsed['title'] ?? '').toString();
                              d = (parsed['description'] ?? '').toString();
                            }
                          } catch (_) {}
                          if (t.isEmpty) {
                            final lines = content
                                .split('\n')
                                .where((e) => e.trim().isNotEmpty)
                                .toList();
                            t = lines.isNotEmpty
                                ? lines.first.trim()
                                : 'New Sprint Ticket';
                            d = lines.skip(1).join('\n').trim();
                            if (d.isEmpty) {
                              d = content.trim();
                            }
                          }
                          if (titleController.text.isEmpty) {
                            titleController.text = t;
                          }
                          if (descriptionController.text.isEmpty) {
                            descriptionController.text = d;
                          }
                        }
                      } catch (_) {}
                      dialogSetState(() {
                        isGenerating = false;
                      });
                    }
                    if (titleController.text.isEmpty) {
                      _showSnackBar('Provide a ticket title (AI can help)',
                          isError: true);
                      return;
                    }
                    final res = await _sprintService.createTicketAlt(
                      sprintId: _selectedSprintId!,
                      title: titleController.text,
                      description: descriptionController.text,
                      assignee: assigneeController.text.isNotEmpty
                          ? assigneeController.text
                          : null,
                      priority: selectedPriority,
                    );
                    if (res != null) {
                      _showSnackBar('Ticket created');
                      await _loadTickets();
                      navigator.pop();
                    } else {
                      _showSnackBar('Failed to create ticket', isError: true);
                    }
                  } catch (_) {}
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlownetColors.electricBlue,
                  foregroundColor: FlownetColors.pureWhite,
                ),
                child: const Text('Create Ticket'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Event handlers
  void handleIssueStatusChange(JiraIssue issue, String newStatus) {
    // Implementation for handling status changes
    _showSnackBar('Status changed to $newStatus');
  }
}
