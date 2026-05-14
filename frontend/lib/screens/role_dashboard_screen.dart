import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user_role.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../services/backend_api_service.dart';
import '../services/api_service.dart';
import '../services/user_data_service.dart';
import '../services/sign_off_report_service.dart';
import '../services/notification_service.dart';
import '../models/notification_item.dart';
import '../models/deliverable.dart';
import '../screens/deliverables_metrics/deliverables_metrics_screen.dart';
import '../widgets/sprint_performance_chart.dart';
import '../widgets/signature_capture_widget.dart';
import '../theme/flownet_theme.dart';
import '../providers/service_providers.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class RoleDashboardScreen extends ConsumerStatefulWidget {
  const RoleDashboardScreen({super.key});

  @override
  ConsumerState<RoleDashboardScreen> createState() =>
      _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends ConsumerState<RoleDashboardScreen> {
  User? _currentUser;
  final AuthService _authService = AuthService();
  late RealtimeService realtimeService;
  final SignOffReportService _reportService =
      SignOffReportService(AuthService());
  bool _isLoadingDashboardDeliverables = false;
  bool _isLoadingDashboardSprints = false;
  List<Map<String, dynamic>> _dashboardDeliverables = [];
  List<Map<String, dynamic>> _dashboardSprints = [];
  List<Map<String, dynamic>> _dashboardProjects = [];
  bool _isLoadingDashboardProjects = false;
  List<Map<String, dynamic>> _auditLogs = [];
  List<Map<String, dynamic>> _filteredAuditLogs = [];
  final BackendApiService _backendService = BackendApiService();
  final UserDataService _userDataService = UserDataService();
  List<Map<String, dynamic>> _pendingReports = [];
  bool _isLoadingPendingReports = false;
  String? _pendingReportsError;
  String? _selectedTeamFilter;
  String? _hoveredTeamFilter;
  String? _selectedAdminFilter;
  String? _hoveredAdminFilter;
  String? _hoveredAdminQuickAction;
  bool _isBottomFabExpanded = false;
  
  // Cache for user names to avoid repeated API calls
  final Map<String, String> _userNamesCache = {};

  String _extractAuditUserId(Map<String, dynamic> log) {
    final id = (log['user_id'] ?? log['userId'] ?? log['actor_id'] ?? log['actorId'])?.toString();
    if (id != null && id.trim().isNotEmpty) return id.trim();
    final userObj = log['user'];
    if (userObj is Map) {
      final uid = userObj['id']?.toString();
      if (uid != null && uid.trim().isNotEmpty) return uid.trim();
    }
    return '';
  }

  String _extractAuditActorLabel(Map<String, dynamic> log) {
    final direct = (log['actor_name'] ??
            log['actorName'] ??
            log['user_name'] ??
            log['userName'] ??
            log['user_email'] ??
            log['userEmail'] ??
            log['actor'] ??
            log['user'])
        ?.toString();
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    final id = _extractAuditUserId(log);
    final cached = id.isNotEmpty ? _userNamesCache[id] : null;
    if (cached != null && cached.trim().isNotEmpty) return cached.trim();
    return 'System';
  }

  Future<void> _hydrateAuditActors(List<Map<String, dynamic>> logs) async {
    final ids = logs
        .map(_extractAuditUserId)
        .where((id) => id.isNotEmpty && !_userNamesCache.containsKey(id))
        .toSet()
        .toList();
    if (ids.isNotEmpty) {
      final futures = ids.map((userId) => _getUserNameById(userId));
      await Future.wait(futures);
    }

    for (final log in logs) {
      log['actor_id'] = _extractAuditUserId(log);
      log['actor'] = _extractAuditActorLabel(log);
    }
  }

  // Method to get user name by ID with caching
  Future<String> _getUserNameById(String userId) async {
    // Check cache first
    if (_userNamesCache.containsKey(userId)) {
      return _userNamesCache[userId]!;
    }

    try {
      final user = await _userDataService.getUserById(userId);
      if (user != null) {
        final userName = user.name.isNotEmpty ? user.name : user.email;
        _userNamesCache[userId] = userName;
        return userName;
      }
    } catch (e) {
      debugPrint('Error fetching user name for $userId: $e');
    }

    // Fallback to showing the ID
    _userNamesCache[userId] = 'User $userId';
    return 'User $userId';
  }

  // Missing variables
  final String _selectedChartType = 'velocity';
  bool _isLoadingClientMetrics = false;
  Map<String, dynamic> _clientReviewMetrics = {};

  bool _isLoadingAuditLogs = false;
  String? _auditLogsError;
  bool _isLoadingMoreAuditLogs = false;
  int _auditLogsPage = 1;
  final int _auditLogsPerPage = 20;
  bool _hasMoreAuditLogs = true;
  String? _selectedActionFilter;
  String? _selectedUserFilter;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  final String _searchQuery = '';
  final String _sortField = 'created_at';
  final bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    realtimeService = RealtimeService();
    realtimeService.initialize(authToken: _authService.accessToken);
    _loadCurrentUser();
    _loadDashboardSprints();
    _loadDashboardDeliverables();
    _loadDashboardProjects();
    _loadReviewHistoryReports();
    _loadPendingReports();
    _loadClientReviewMetrics();
    _setupRealtimeListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    realtimeService.off('user_role_changed', _handleRoleChanged);
    realtimeService.offAll('sprint_created');
    realtimeService.offAll('sprint_updated');
    realtimeService.offAll('deliverable_created');
    realtimeService.offAll('deliverable_updated');
    realtimeService.offAll('approval_created');
    realtimeService.offAll('approval_updated');
    realtimeService.offAll('project_created');
    realtimeService.offAll('project_updated');
    realtimeService.offAll('audit_log_created');
    // Do not call offAll for notification_received as it affects other widgets
    super.dispose();
  }

  Future<void> _loadDashboardSprints() async {
    setState(() => _isLoadingDashboardSprints = true);
    try {
      final items = await ApiService.getSprints();
      _dashboardSprints = items;
    } finally {
      if (mounted) setState(() => _isLoadingDashboardSprints = false);
    }
  }

  Future<void> _loadDashboardDeliverables() async {
    setState(() => _isLoadingDashboardDeliverables = true);
    try {
      final items = await ApiService.getDeliverables();
      _dashboardDeliverables = items;

      // Pre-populate user cache for better performance
      await _preloadUserNames(items);
    } finally {
      if (mounted) setState(() => _isLoadingDashboardDeliverables = false);
    }
  }

  // Preload user names for all deliverables to avoid multiple API calls
  Future<void> _preloadUserNames(List<Map<String, dynamic>> deliverables) async {
    final Set<String> userIds = {};
    
    for (final deliverable in deliverables) {
      final ownerId = _getOwnerId(deliverable);
      final assignedToId = deliverable['assigned_to']?.toString() ?? deliverable['assignedTo']?.toString();
      
      if (ownerId != null && ownerId.isNotEmpty) {
        userIds.add(ownerId);
      }
      if (assignedToId != null && assignedToId.isNotEmpty) {
        userIds.add(assignedToId);
      }
    }

    // Batch load user names
    final futures = userIds.map((userId) => _getUserNameById(userId));
    await Future.wait(futures);
  }

  Future<void> _loadDashboardProjects() async {
    setState(() => _isLoadingDashboardProjects = true);
    try {
      final resp = await _backendService.getProjects(page: 1, limit: 1000);
      if (resp.isSuccess && resp.data != null) {
        final dynamic raw = resp.data;
        final List<dynamic> items = raw is Map
            ? (raw['items'] ?? raw['projects'] ?? raw['data'] ?? [])
            : (raw is List ? raw : []);
        if (mounted) {
          setState(() {
            _dashboardProjects = items
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingDashboardProjects = false);
    }
  }

  Future<void> _loadReviewHistoryReports() async {
    setState(() {
      _isLoadingAuditLogs = true;
      _auditLogsError = null;
    });
    try {
      final resp = await _backendService.getRealAuditLogs(skip: 0, limit: 50);
      if (resp.isSuccess && resp.data != null) {
        final dynamic raw = resp.data;
        final List<dynamic> items = raw is Map
            ? (raw['audit_logs'] ??
                raw['items'] ??
                raw['logs'] ??
                raw['data'] ??
                [])
            : (raw is List ? raw : []);
        final list = items
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        await _hydrateAuditActors(list);
        setState(() {
          _auditLogs = list;
          _filteredAuditLogs = _auditLogs;
        });
      } else {
        setState(() {
          _auditLogs = [];
          _filteredAuditLogs = _auditLogs;
          _auditLogsError = resp.error ?? 'Failed to load audit logs';
        });
      }
    } catch (e) {
      setState(() {
        _auditLogsError = 'Failed to load audit logs';
        _auditLogs = [];
        _filteredAuditLogs = _auditLogs;
      });
    } finally {
      if (mounted) setState(() => _isLoadingAuditLogs = false);
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      // Initialize AuthService first
      await _authService.initialize();

      // Get the current user from AuthService
      final user = await _authService.getCurrentUser();
      if (user != null && (user.isActive || user.isSystemAdmin)) {
        if (!mounted) return;
        setState(() {
          _currentUser = user;
        });
        debugPrint(
            '✅ Loaded user: ${user.name} (${user.email}) - Role: ${user.role}');

        // Load audit logs after user is loaded
        _loadAuditLogs();

        // Initialize realtime service with valid token
        if (_authService.accessToken != null) {
          realtimeService.initialize(authToken: _authService.accessToken);
          _setupRealtimeListeners();
        }
      } else {
        if (!_authService.isAuthenticated) {
          debugPrint('❌ Inactive or no user found, redirecting to login');
          if (mounted) {
            final messenger = ScaffoldMessenger.of(context);
            final router = GoRouter.of(context);
            messenger.showSnackBar(
              const SnackBar(
                content:
                    Text('Your account is inactive. Please contact support.'),
                backgroundColor: Colors.red,
              ),
            );
            router.go('/');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading current user: $e');
      // If there's an error, redirect to login
      if (mounted) {
        context.go('/');
      }
    }
  }

  Future<void> _loadAuditLogs({bool loadMore = false}) async {
    if (_isLoadingAuditLogs && !loadMore) return;
    if (_isLoadingMoreAuditLogs && loadMore) return;
    if (!loadMore && !_hasMoreAuditLogs) return;

    final int page = loadMore ? _auditLogsPage + 1 : 1;
    final int skip = (page - 1) * _auditLogsPerPage;

    setState(() {
      if (loadMore) {
        _isLoadingMoreAuditLogs = true;
      } else {
        _isLoadingAuditLogs = true;
        _auditLogsError = null;
      }
    });

    try {
      final response = await _backendService.getAuditLogs(
        skip: skip,
        limit: _auditLogsPerPage,
        action: _selectedActionFilter,
        userId: _selectedUserFilter,
      );

      if (response.isSuccess) {
        final data = response.data;
        final logs =
            data?['audit_logs'] ?? data?['items'] ?? data?['logs'] ?? [];
        final totalCount =
            data?['total'] ?? data?['total_count'] ?? logs.length;

        // Apply date filtering if dates are selected
        List<Map<String, dynamic>> filteredLogs =
            List<Map<String, dynamic>>.from(logs);

        if (_selectedStartDate != null || _selectedEndDate != null) {
          filteredLogs = filteredLogs.where((log) {
            final createdAt = log['created_at'] as String?;
            if (createdAt == null) return false;

            try {
              final logDate = DateTime.parse(createdAt);

              if (_selectedStartDate != null &&
                  logDate.isBefore(_selectedStartDate!)) {
                return false;
              }
              if (_selectedEndDate != null &&
                  logDate.isAfter(_selectedEndDate!)) {
                return false;
              }

              return true;
            } catch (e) {
              return false;
            }
          }).toList();
        }

        await _hydrateAuditActors(filteredLogs);
        setState(() {
          if (loadMore) {
            _auditLogs.addAll(filteredLogs);
            _auditLogsPage = page;
            _hasMoreAuditLogs = _auditLogs.length < totalCount;
          } else {
            _auditLogs = filteredLogs;
            _auditLogsPage = 1;
            _hasMoreAuditLogs = _auditLogs.length < totalCount &&
                filteredLogs.length == _auditLogsPerPage;
          }
        });

        // Apply search and sort after loading data
        _applySearchAndSort();

        debugPrint(
            '✅ Loaded ${filteredLogs.length} audit logs (page $page, total ${_auditLogs.length}, has more: $_hasMoreAuditLogs)');
      } else {
        setState(() {
          _auditLogsError = response.error ?? 'Failed to load audit logs';
        });
        debugPrint('❌ Error loading audit logs: $_auditLogsError');
      }
    } catch (e) {
      setState(() {
        _auditLogsError = 'Failed to load audit logs: $e';
      });
      debugPrint('❌ Exception loading audit logs: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAuditLogs = false;
          _isLoadingMoreAuditLogs = false;
        });
      }
    }
  }

  void _applySearchAndSort() {
    List<Map<String, dynamic>> filtered =
        List<Map<String, dynamic>>.from(_auditLogs);

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((Map<String, dynamic> log) {
        final action = (log['action'] as String? ?? '').toLowerCase();
        final userEmail = (log['user_email'] as String? ?? '').toLowerCase();
        final entityName = (log['entity_name'] as String? ?? '').toLowerCase();
        final entityType = (log['entity_type'] as String? ?? '').toLowerCase();
        final userRole = (log['user_role'] as String? ?? '').toLowerCase();
        return action.contains(query) ||
            userEmail.contains(query) ||
            entityName.contains(query) ||
            entityType.contains(query) ||
            userRole.contains(query);
      }).toList();
    }

    // Apply sorting
    filtered.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final dynamic aValue = a[_sortField];
      final dynamic bValue = b[_sortField];

      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return _sortAscending ? -1 : 1;
      if (bValue == null) return _sortAscending ? 1 : -1;

      if (aValue is String && bValue is String) {
        return _sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      }

      if (aValue is DateTime && bValue is DateTime) {
        return _sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      }

      if (aValue is String && bValue is DateTime) {
        try {
          final aDate = DateTime.parse(aValue);
          return _sortAscending
              ? aDate.compareTo(bValue)
              : bValue.compareTo(aDate);
        } catch (e) {
          return _sortAscending ? -1 : 1;
        }
      }

      if (aValue is DateTime && bValue is String) {
        try {
          final bDate = DateTime.parse(bValue);
          return _sortAscending
              ? aValue.compareTo(bDate)
              : bDate.compareTo(aValue);
        } catch (e) {
          return _sortAscending ? 1 : -1;
        }
      }

      return 0;
    });

    setState(() {
      _filteredAuditLogs = filtered;
    });
  }

  String? _getOwnerName(Map<String, dynamic> data) {
    if (data['ownerName'] != null) return data['ownerName'].toString();
    if (data['owner_name'] != null) return data['owner_name'].toString();
    
    // Map backend field names to frontend expectations
    if (data['created_by_name'] != null) return data['created_by_name'].toString();

    if (data['owner'] != null && data['owner'] is Map) {
      final owner = data['owner'];
      final first = owner['first_name'] ?? owner['firstName'] ?? '';
      final last = owner['last_name'] ?? owner['lastName'] ?? '';
      if (first.toString().isNotEmpty || last.toString().isNotEmpty) {
        return '$first $last'.trim();
      }
      return owner['email']?.toString();
    }
    return null;
  }

  String? _getOwnerId(Map<String, dynamic> data) {
    return data['ownerId']?.toString() ??
        data['owner_id']?.toString() ??
        // Map backend field names to frontend expectations
        data['created_by']?.toString() ??
        (data['owner'] != null && data['owner'] is Map
            ? data['owner']['id']?.toString()
            : null);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: _buildRoleSpecificContent(),
        ),
        Positioned(
          right: 16,
          bottom: 12,
          child: _buildBottomRightExpandableFab(),
        ),
      ],
    );
  }

  Widget _buildRoleSpecificContent() {
    switch (_currentUser!.role) {
      case UserRole.teamMember:
        return _buildTeamMemberDashboard();
      case UserRole.deliveryLead:
        return _buildDeliveryLeadDashboard();
      case UserRole.client:
        return _buildClientReviewerDashboard();
      case UserRole.clientReviewer:
        return _buildClientReviewerDashboard();
      case UserRole.systemAdmin:
        return _buildSystemAdminDashboard();
      case UserRole.developer:
        return _buildDeveloperDashboard();
      case UserRole.projectManager:
        return _buildProjectManagerDashboard();
      case UserRole.scrumMaster:
        return _buildScrumMasterDashboard();
      case UserRole.qaEngineer:
        return _buildQAEngineerDashboard();
      case UserRole.stakeholder:
        return _buildStakeholderDashboard();
    }
  }

  Widget _buildTeamMemberDashboard() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 980;
        final double headingSize = compact ? 22 : 26;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTeamQuickActionsPanel(compact: compact),
                  const SizedBox(height: 10),
                  Text(
                    'Review Metrics Overview',
                    style: TextStyle(
                      color: textColor,
                      fontSize: headingSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTeamReviewMetricsCards(compact: compact),
                  const SizedBox(height: 10),
                  compact
                      ? Column(
                          children: [
                            _buildTeamDeliverablesPanel(),
                            const SizedBox(height: 10),
                            _buildTeamProjectsPanel(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildTeamDeliverablesPanel()),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: _buildTeamProjectsPanel()),
                          ],
                        ),
                  const SizedBox(height: 10),
                  _buildTeamRecentActivitiesPanel(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeamHeaderIconButton({
    IconData? icon,
    String? assetPath,
    required VoidCallback onTap,
  }) {
    assert(icon != null || assetPath != null);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: assetPath != null
          ? SizedBox(
              width: 36,
              height: 36,
              child: _buildDashboardAssetIcon(
                assetPath,
                size: 36,
                fit: BoxFit.contain,
                visualScale: 1.25,
              ),
            )
          : Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xD9FFFFFF),
              ),
              alignment: Alignment.center,
              child: Icon(icon!, size: 18, color: textColor),
            ),
    );
  }

  Widget _buildDashboardAssetIcon(
    String assetPath, {
    double size = 20,
    BoxFit fit = BoxFit.contain,
    double visualScale = 1.0,
  }) {
    return ClipOval(
      child: Transform.scale(
        scale: visualScale,
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: fit,
          filterQuality: FilterQuality.none,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Color _dashboardSurfaceColor() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (isDarkMode) {
      return FlownetColors.surface.withValues(alpha: 0.4);
    }
    // Light mode widgets at 60% opacity
    return Colors.white.withValues(alpha: 0.6);
  }

  TextStyle _dashboardTextStyle({
    double size = 14,
    FontWeight weight = FontWeight.w500,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      color: isDarkMode ? Colors.white : Colors.black,
      fontSize: size,
      fontWeight: weight,
    );
  }

  Color _subtitleTextColor() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? Colors.white.withAlpha(210) : Colors.black87;
  }

  Widget _buildTeamQuickActionsPanel({bool compact = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _dashboardSurfaceColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _buildTeamRoundIcon(
            Icons.rocket_launch_outlined,
            assetPath: 'assets/dashboard_team_member/Group417.png',
            containerSize: 40,
            assetVisualScale: 1.2,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Actions', style: _dashboardTextStyle(size: compact ? 20 : 22, weight: FontWeight.w700)),
                Text(
                  'Dream BIG, work hard and stay focused - make it a productive day!',
                  style: _dashboardTextStyle(size: 11, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Spacer(),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildTeamPillButton('CREATE DELIVERABLE', () => context.go('/deliverable-setup')),
              _buildTeamPillButton('VIEW PROJECTS', () => context.go('/projects')),
              _buildTeamPillButton('BUILD REPORT', () {
                final first = _dashboardDeliverables.isNotEmpty ? _dashboardDeliverables.first : null;
                final sprintId = first != null ? _extractFirstSprintId(first) : null;
                if (sprintId != null && sprintId.isNotEmpty) {
                  context.go('/sprint-report/$sprintId');
                  return;
                }
                context.go('/sprint-console');
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamReviewMetricsCards({bool compact = false}) {
    final cards = [
      _buildTeamMetricCard(
        'Submitted',
        '${_clientReviewMetrics['submitted'] ?? 0}',
        'assets/dashboard_team_member/Group519.png',
      ),
      _buildTeamMetricCard(
        'Approved',
        '${_clientReviewMetrics['approved'] ?? 0}',
        'assets/dashboard_team_member/Group520.png',
      ),
      _buildTeamMetricCard(
        'Changes Requested',
        '${_clientReviewMetrics['changes'] ?? 0}',
        'assets/dashboard_team_member/Group523.png',
      ),
      _buildTeamMetricCard(
        'Rejected',
        '${_clientReviewMetrics['rejected'] ?? 0}',
        'assets/dashboard_team_member/Group_521.png',
      ),
      _buildTeamMetricCard(
        'Average Review Time',
        '${_clientReviewMetrics['avg_review_time'] ?? '-'}',
        'assets/dashboard_team_member/Group_522.png',
      ),
    ];
    if (compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards
            .map((c) => SizedBox(width: 240, child: c))
            .toList(),
      );
    }
    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _buildTeamMetricCard(String title, String value, String iconAssetPath) {
    return Container(
      decoration: BoxDecoration(
        color: _dashboardSurfaceColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _dashboardTextStyle(size: 20, weight: FontWeight.w700)),
          Text('Additional description information to include.', style: _dashboardTextStyle(size: 11)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(value, style: _dashboardTextStyle(size: 18, weight: FontWeight.w700)),
              const Spacer(),
              _buildTeamRoundIcon(
                Icons.circle,
                size: 16,
                assetPath: iconAssetPath,
                containerSize: 40,
                assetVisualScale: 1.2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamDeliverablesPanel() {
    final uid = _currentUser?.id.toString() ?? '';
    var myDeliverables = _dashboardDeliverables.where((d) {
      final assigned = (d['assigned_to'] ?? d['assignedTo'] ?? '').toString();
      final created = (d['created_by'] ?? d['createdBy'] ?? '').toString();
      return assigned == uid || created == uid;
    }).toList();

    if (_selectedTeamFilter != null) {
      final filter = _selectedTeamFilter!;
      if (filter == 'HIGH PRIORITY') {
        myDeliverables = myDeliverables
            .where((d) => (d['priority'] ?? '').toString().toLowerCase() == 'high')
            .toList();
      } else if (filter == 'MEDIUM PRIORITY') {
        myDeliverables = myDeliverables
            .where((d) => (d['priority'] ?? '').toString().toLowerCase() == 'medium')
            .toList();
      } else if (filter == 'LOW PRIORITY') {
        myDeliverables = myDeliverables
            .where((d) => (d['priority'] ?? '').toString().toLowerCase() == 'low')
            .toList();
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: _dashboardSurfaceColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTeamRoundIcon(
                Icons.track_changes,
                assetPath: 'assets/dashboard_team_member/overview.png',
                containerSize: 40,
                assetVisualScale: 1.2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deliverables Overview', style: _dashboardTextStyle(size: 20, weight: FontWeight.w700)),
                    Text('Additional description can be included if required.', style: _dashboardTextStyle(size: 11)),
                  ],
                ),
              ),
              _buildTeamRoundIcon(
                Icons.notifications_none,
                size: 16,
                assetPath: 'assets/dashboard_team_member/Group_398.png',
                containerSize: 36,
                assetVisualScale: 1.2,
              ),
              const SizedBox(width: 6),
              Text('${myDeliverables.length}', style: _dashboardTextStyle(size: 16, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Colors.white24),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildTeamMiniFilter('VIEW ALL'),
              const SizedBox(width: 8),
              _buildTeamMiniFilter('HIGH PRIORITY'),
              const SizedBox(width: 8),
              _buildTeamMiniFilter('MEDIUM PRIORITY'),
              const SizedBox(width: 8),
              _buildTeamMiniFilter('LOW PRIORITY'),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingDashboardDeliverables)
            const Center(child: CircularProgressIndicator())
          else if (myDeliverables.isEmpty)
            Text('No deliverables yet', style: _dashboardTextStyle())
          else
            ...myDeliverables.take(6).map((d) {
              final title = (d['title'] ?? d['name'] ?? d['deliverableName'] ?? 'Document Name').toString();
              final due = (d['due_date'] ?? d['dueDate'] ?? d['deadline'] ?? '').toString();
              final shortDue = due.isNotEmpty && due.length >= 10 ? due.substring(0, 10) : due;
              final id = (d['id']?.toString() ?? d['uuid']?.toString() ?? '');
              final priority = (d['priority'] ?? 'medium').toString().toLowerCase();
              final status = (d['status'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      status.toLowerCase() == 'completed' ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$title - Draft Description', style: _dashboardTextStyle(size: 12)),
                    ),
                    if (shortDue.isNotEmpty)
                      Text(shortDue, style: _dashboardTextStyle(size: 11)),
                    const SizedBox(width: 8),
                    _buildTeamPriorityBadge(priority),
                    const SizedBox(width: 8),
                    _buildTeamActionPill('EDIT', () => _editDeliverable(d)),
                    const SizedBox(width: 6),
                    _buildTeamActionPill('COMPLETE', () {
                      if (id.isNotEmpty) {
                        _updateDeliverableStatus(id, 'completed');
                      }
                    }),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTeamProjectsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _dashboardSurfaceColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTeamRoundIcon(
                Icons.folder_copy_outlined,
                assetPath: 'assets/dashboard_team_member/Group517.png',
                containerSize: 42,
                assetVisualScale: 1.15,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projects Overview', style: _dashboardTextStyle(size: 20, weight: FontWeight.w700)),
                    Text('Additional description can be included.', style: _dashboardTextStyle(size: 11)),
                  ],
                ),
              ),
              _buildTeamRoundIcon(
                Icons.notifications_none,
                size: 16,
                assetPath: 'assets/dashboard_team_member/Group_398.png',
                containerSize: 36,
                assetVisualScale: 1.2,
              ),
              const SizedBox(width: 6),
              Text('${_dashboardProjects.length}', style: _dashboardTextStyle(size: 16, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Colors.white24),
          const SizedBox(height: 6),
          if (_isLoadingDashboardProjects)
            const Center(child: CircularProgressIndicator())
          else if (_dashboardProjects.isEmpty)
            Text('No projects found', style: _dashboardTextStyle())
          else
            ..._dashboardProjects.take(8).map((p) {
              final name = (p['name'] ?? 'Project').toString();
              final id = (p['id'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: id.isNotEmpty ? () => context.go('/project-workspace/$id') : null,
                  child: Row(
                    children: [
                      Icon(Icons.check_box, size: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name, style: _dashboardTextStyle(size: 12))),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTeamRecentActivitiesPanel() {
    final userId = _currentUser?.id.toString() ?? '';
    final userName = _currentUser?.name ?? '';
    final my = _filteredAuditLogs.where((a) {
      final actor = (a['actor'] ?? a['user'] ?? '').toString();
      final uid = (a['user_id'] ?? a['actor_id'] ?? '').toString();
      return actor == userName || uid == userId;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: _dashboardSurfaceColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTeamRoundIcon(
                Icons.notifications_active_outlined,
                assetPath: 'assets/dashboard_team_member/red_bells.png',
                containerSize: 40,
                assetVisualScale: 1.2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Activities', style: _dashboardTextStyle(size: 20, weight: FontWeight.w700)),
                    Text('Additional description can be included if required.', style: _dashboardTextStyle(size: 11)),
                  ],
                ),
              ),
              _buildTeamRoundIcon(
                Icons.notifications_none,
                size: 16,
                assetPath: 'assets/dashboard_team_member/Group_398.png',
                containerSize: 36,
                assetVisualScale: 1.2,
              ),
              const SizedBox(width: 6),
              Text('${my.length}', style: _dashboardTextStyle(size: 16, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Colors.white24),
          const SizedBox(height: 6),
          if (_isLoadingAuditLogs)
            const Center(child: CircularProgressIndicator())
          else if (_auditLogsError != null)
            Text(_auditLogsError!, style: _dashboardTextStyle())
          else if (my.isEmpty)
            Text('No Recent Activity.', style: _dashboardTextStyle())
          else
            ...my.take(5).map((a) {
              final action = (a['action'] ?? a['event'] ?? a['type'] ?? 'Activity').toString();
              final actor = (a['actor'] ?? a['user'] ?? '').toString();
              final text = actor.isNotEmpty ? '$action • $actor' : action;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(text, style: _dashboardTextStyle(size: 12)),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTeamPillButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: FlownetColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildTeamMiniFilter(String label) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final bool isActive = _selectedTeamFilter == label || _hoveredTeamFilter == label;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTeamFilter = label),
      onExit: (_) => setState(() => _hoveredTeamFilter = null),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          setState(() {
            _selectedTeamFilter = label == 'VIEW ALL' ? null : label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: FlownetColors.primary),
            color: isActive ? FlownetColors.primary : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : textColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamPriorityBadge(String priority) {
    Color color;
    String text;
    switch (priority) {
      case 'high':
        color = const Color(0xFF4A90E2);
        text = 'High Priority';
        break;
      case 'low':
        color = const Color(0xFF7ED321);
        text = 'Low Priority';
        break;
      default:
        color = const Color(0xFFF5A623);
        text = 'Medium Priority';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTeamActionPill(String label, VoidCallback onTap) {
    final bool isComplete = label == 'COMPLETE';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isComplete ? FlownetColors.primary : Colors.grey.shade600,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRoundIcon(
    IconData icon, {
    double size = 20,
    double containerSize = 34,
    double assetVisualScale = 1.7,
    String? assetPath,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    if (assetPath != null) {
      return SizedBox(
        width: containerSize,
        height: containerSize,
        child: _buildDashboardAssetIcon(
          assetPath,
          size: containerSize,
          fit: BoxFit.contain,
          visualScale: assetVisualScale,
        ),
      );
    }

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size, color: textColor),
    );
  }

  Widget _buildStandaloneAssetIcon(
    String assetPath, {
    double size = 34,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          final altPath = assetPath.startsWith('frontend/')
              ? assetPath.replaceFirst('frontend/', '')
              : 'frontend/$assetPath';
          return Image.asset(
            altPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.image_not_supported_outlined,
                size: size,
                color: FlownetColors.crimsonRed,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTeamHeaderAssetIconButton({
    required String assetPath,
    required VoidCallback onTap,
    double buttonSize = 40,
    double iconSize = 22,
  }) {
    return Material(
      color: _dashboardSurfaceColor(),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Center(
            child: Image.asset(
              assetPath,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image_not_supported_outlined,
                  size: iconSize,
                  color: FlownetColors.crimsonRed,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Map<String, int> _computeDeliverableStatusCounts() {
    final now = DateTime.now();
    int completed = 0;
    int inProgress = 0;
    int overdue = 0;
    for (final d in _dashboardDeliverables) {
      final status = (d['status'] ?? '').toString().toLowerCase();
      final isCompleted =
          status == 'completed' || status == 'done' || status == 'approved';
      if (isCompleted) {
        completed++;
      } else {
        inProgress++;
      }
      if (!isCompleted) {
        final rawDue =
            (d['due_date'] ?? d['dueDate'] ?? d['deadline'] ?? '').toString();
        DateTime? due;
        if (rawDue.isNotEmpty) {
          try {
            due = DateTime.parse(rawDue);
          } catch (_) {}
        }
        if (due != null && due.isBefore(now)) {
          overdue++;
        }
      }
    }
    return {
      'total': _dashboardDeliverables.length,
      'completed': completed,
      'inProgress': inProgress,
      'overdue': overdue,
    };
  }

  Widget _buildDeliveryLeadReviewMetricsCards({bool compact = false}) {
    final cards = [
      _buildDeliveryLeadMetricAssetCard(
        'Submitted',
        '${_clientReviewMetrics['submitted'] ?? 0}',
        'assets/Icons/submitted_red_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'Approved',
        '${_clientReviewMetrics['approved'] ?? 0}',
        'assets/Icons/approved_red_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'Changes Requested',
        '${_clientReviewMetrics['changes'] ?? 0}',
        'assets/Icons/changes_request_red_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'Rejected',
        '${_clientReviewMetrics['rejected'] ?? 0}',
        'assets/Icons/rejected_red_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'Average Review Time',
        '${_clientReviewMetrics['avg_review_time'] ?? '-'}',
        'assets/Icons/review_time_red_icon.png',
      ),
    ];

    if (compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) => SizedBox(width: 240, child: c)).toList(),
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _buildDeliveryLeadTopHeader() {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                'Delivery Manager Dashboard',
                style: _dashboardTextStyle(size: 28, weight: FontWeight.w700),
              ),
              const SizedBox(width: 14),
              Text(
                'Hello, ${_currentUser?.name ?? 'Name Surname'}',
                style: _dashboardTextStyle(size: 14, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
        _buildTeamHeaderAssetIconButton(
          assetPath: 'assets/Message.png',
          onTap: () => context.go('/notifications'),
        ),
        const SizedBox(width: 10),
        _buildTeamHeaderAssetIconButton(
          assetPath: 'assets/notification.png',
          onTap: () => _loadPendingReports(),
        ),
      ],
    );
  }

  Widget _buildDeliveryLeadApprovalRemindersPanel({bool compact = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _dashboardSurfaceColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _buildStandaloneAssetIcon('assets/Icons/reminder_icon.png', size: 44),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approval Reminders',
                  style: _dashboardTextStyle(
                    size: compact ? 20 : 22,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Dream BIG, work hard and stay focused - make it a productive day!',
                  style: _dashboardTextStyle(size: 11, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Spacer(),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildTeamPillButton(
                'SEND REMINDER',
                () => context.go('/send-reminder'),
              ),
              _buildTeamPillButton(
                'TRIGGER ESCALATION',
                _triggerEscalation,
              ),
              _buildTeamPillButton(
                'DELIVERABLES OVERVIEW',
                () => context.go('/deliverables-overview'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryLeadTeamMetricsCards({bool compact = false}) {
    final counts = _computeDeliverableStatusCounts();
    final total = counts['total'] ?? 0;
    final completed = counts['completed'] ?? 0;
    final inProgress = counts['inProgress'] ?? 0;
    final overdue = counts['overdue'] ?? 0;
    final pendingReviews = _pendingReports.length;
    final completionRate =
        total > 0 ? ((completed / total) * 100).round() : 0;

    final cards = [
      _buildDeliveryLeadMetricAssetCard(
        'Deliverables',
        '$total',
        'assets/Icons/deliverables_kpi_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'In Progress',
        '$inProgress',
        'assets/Icons/progress_kpi_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'Completed',
        '$completed',
        'assets/Icons/completed_kpi_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'Overdue',
        '$overdue',
        'assets/Icons/overdue_kpi_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'Active Sprints',
        '${_dashboardSprints.length}',
        'assets/Icons/active_sprints_kpi_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'Active Projects',
        '${_dashboardProjects.length}',
        'assets/Icons/active_projects_kpi_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'Pending Reviews',
        '$pendingReviews',
        'assets/Icons/review_kpi_icon.png',
      ),
      _buildDeliveryLeadMetricAssetCard(
        'Completion Rate',
        '$completionRate%',
        'assets/Icons/completion_kpi_icon.png',
      ),
    ];

    if (compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) => SizedBox(width: 240, child: c)).toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: cards[i]),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 4; i < 8; i++) ...[
              if (i > 4) const SizedBox(width: 10),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDeliveryLeadVelocityPanel() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _dashboardSurfaceColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStandaloneAssetIcon(
                'assets/Icons/revenue_forecast_icon.png',
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue Forecast',
                      style: _dashboardTextStyle(
                        size: 20,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Projected vs Actual Revenue',
                      style: _dashboardTextStyle(size: 11),
                    ),
                  ],
                ),
              ),
              _buildStandaloneAssetIcon(
                'assets/Icons/notification_icon.png',
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: SprintPerformanceChart(
              sprints: _dashboardSprints,
              chartType: _selectedChartType,
              showTitle: false,
              useCard: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryLeadKpiCard({
    required String title,
    required String value,
    required String assetPath,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _dashboardSurfaceColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _dashboardTextStyle(size: 16, weight: FontWeight.w700),
          ),
          Text(
            'Additional description information to include.',
            style: _dashboardTextStyle(size: 10, weight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: _dashboardTextStyle(size: 16, weight: FontWeight.w700),
              ),
              const Spacer(),
              _buildStandaloneAssetIcon(assetPath, size: 38),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryLeadMetricAssetCard(
    String title,
    String value,
    String assetPath,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _dashboardSurfaceColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _dashboardTextStyle(size: 18, weight: FontWeight.w700),
          ),
          Text(
            'Additional detail if required.',
            style: _dashboardTextStyle(size: 11),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                value,
                style: _dashboardTextStyle(size: 18, weight: FontWeight.w700),
              ),
              const Spacer(),
              _buildStandaloneAssetIcon(assetPath, size: 38),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryLeadVelocitySection({required bool compact}) {
    final total = _dashboardDeliverables.length;
    final completed = _dashboardDeliverables
        .where(
          (d) => (d['status'] ?? '').toString().toLowerCase() == 'completed',
        )
        .length;
    final planned = total;
    final carryOver = (planned - completed) < 0 ? 0 : (planned - completed);
    final avgVelocity =
        planned > 0 ? ((completed / planned) * 100).round() : 0;

    final cards = [
      _buildDeliveryLeadKpiCard(
        title: 'Average Velocity',
        value: '$avgVelocity%',
        assetPath: 'assets/Icons/average_red_icon.png',
      ),
      _buildDeliveryLeadKpiCard(
        title: 'Planned',
        value: '$planned',
        assetPath: 'assets/Icons/planned_red_icon.png',
      ),
      _buildDeliveryLeadKpiCard(
        title: 'Completed',
        value: '$completed',
        assetPath: 'assets/Icons/completed_red_icon.png',
      ),
      _buildDeliveryLeadKpiCard(
        title: 'Carry Over',
        value: '$carryOver',
        assetPath: 'assets/Icons/carry_over_red_icon.png',
      ),
      _buildDeliveryLeadKpiCard(
        title: 'Defects',
        value: '0',
        assetPath: 'assets/Icons/defects_red_icon.png',
      ),
    ];

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Velocity Trend',
          style: TextStyle(
            color: textColor,
            fontSize: compact ? 22 : 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _buildDeliveryLeadVelocityPanel(),
        const SizedBox(height: 10),
        if (compact)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards.map((c) => SizedBox(width: 240, child: c)).toList(),
          )
        else
          Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cards[i]),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildDeliveryLeadDashboard() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 980;
        final double headingSize = compact ? 22 : 26;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeliveryLeadTopHeader(),
                  const SizedBox(height: 12),
                  _buildDeliveryLeadApprovalRemindersPanel(compact: compact),
                  const SizedBox(height: 12),
                  Text(
                    'Team Metrics Overview',
                    style: TextStyle(
                      color: textColor,
                      fontSize: headingSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDeliveryLeadTeamMetricsCards(compact: compact),
                  const SizedBox(height: 12),
                  Text(
                    'Review Metrics Overview',
                    style: TextStyle(
                      color: textColor,
                      fontSize: headingSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDeliveryLeadReviewMetricsCards(compact: compact),
                  const SizedBox(height: 12),
                  compact
                      ? Column(
                          children: [
                            _buildAdminDeliverablesPanel(),
                            const SizedBox(height: 12),
                            _buildAdminProjectsPanel(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildAdminDeliverablesPanel(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildAdminProjectsPanel(),
                            ),
                          ],
                        ),
                  const SizedBox(height: 12),
                  _buildSprintOverview(),
                  const SizedBox(height: 12),
                  _buildDeliveryLeadVelocitySection(compact: compact),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientReviewerDashboard() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 980;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAdminTopHeader(),
                  const SizedBox(height: 12),
                  _buildAdminReminderHeroPanel(),
                  const SizedBox(height: 12),
                  Text(
                    'Review Metrics Overview',
                    style: TextStyle(
                      color: textColor,
                      fontSize: compact ? 22 : 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTeamReviewMetricsCards(compact: compact),
                  const SizedBox(height: 12),
                  if (compact)
                    Column(
                      children: [
                        _buildAdminDeliverablesPanel(),
                        const SizedBox(height: 12),
                        _buildAdminProjectsPanel(),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildAdminDeliverablesPanel(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildAdminProjectsPanel(),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (compact)
                    Column(
                      children: [
                        _buildTeamRecentActivitiesPanel(),
                        const SizedBox(height: 12),
                        _buildReviewHistoryPanel(),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTeamRecentActivitiesPanel(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildReviewHistoryPanel(),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewHistoryPanel() {
    return Container(
      decoration: _adminContentPanelDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTeamRoundIcon(
                Icons.rate_review_outlined,
                assetPath: 'assets/Quick_Actions.png',
                containerSize: 44,
                assetVisualScale: 1.45,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Review History',
                        style: _dashboardTextStyle(size: 20, weight: FontWeight.w700)),
                    Text('Additional description can be included.',
                        style: _dashboardTextStyle(size: 11)
                            .copyWith(color: _subtitleTextColor())),
                  ],
                ),
              ),
              _buildTeamRoundIcon(
                Icons.notifications_none,
                size: 16,
                assetPath: 'assets/notification.png',
              ),
              const SizedBox(width: 6),
              Text('${_filteredAuditLogs.length}',
                  style: _dashboardTextStyle(size: 16, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: _adminDividerColor, height: 1),
          const SizedBox(height: 8),
          if (_isLoadingAuditLogs)
            const Center(child: CircularProgressIndicator())
          else if (_auditLogsError != null)
            Text(_auditLogsError!, style: _dashboardTextStyle())
          else if (_filteredAuditLogs.isEmpty)
            Text('No review history found', style: _dashboardTextStyle())
          else
            ..._filteredAuditLogs.take(5).map((a) {
              final action = a['action'] ?? a['event'] ?? a['type'] ?? 'Review';
              final actor = a['actor'] ?? a['user'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.rate_review_outlined, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            actor.toString().isNotEmpty ? '$action • $actor' : action.toString(),
                            style: _dashboardTextStyle(size: 12))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSystemAdminDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keep side-by-side layout for desktop/tablet widths to match design.
          final bool isNarrow = constraints.maxWidth < 900;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdminTopHeader(),
              const SizedBox(height: 12),
              _buildAdminReminderHeroPanel(),
              const SizedBox(height: 12),
              _buildAdminQuickActionsPanel(),
              const SizedBox(height: 12),
              if (isNarrow) ...[
                _buildAdminDeliverablesPanel(),
                const SizedBox(height: 12),
                _buildAdminProjectsPanel(),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildAdminDeliverablesPanel()),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _buildAdminProjectsPanel()),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdminTopHeader() {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                'Client Reviewer Dashboard',
                style: _dashboardTextStyle(size: 20, weight: FontWeight.w700),
              ),
              const SizedBox(width: 14),
              Text(
                'Hello, ${_currentUser?.name ?? 'Name Surname'}',
                style: _dashboardTextStyle(size: 13, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
        _buildTeamHeaderIconButton(
          assetPath: 'assets/Message.png',
          icon: Icons.mail_outline,
          onTap: () => context.go('/notifications'),
        ),
        const SizedBox(width: 8),
        _buildTeamHeaderIconButton(
          assetPath: 'assets/notification.png',
          icon: Icons.notifications_none,
          onTap: () => _loadPendingReports(),
        ),
      ],
    );
  }

  Widget _buildAdminReminderHeroPanel() {
    return Container(
      width: double.infinity,
      decoration: _adminPanelDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _buildTeamRoundIcon(
            Icons.notifications_active_outlined,
            assetPath: 'assets/Approval_Reminders.png',
            containerSize: 44,
            assetVisualScale: 1.45,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approval Reminders',
                  style: _dashboardTextStyle(size: 20, weight: FontWeight.w700),
                ),
                Text(
                  'Dream BIG, work hard and stay focused - make it a productive day!',
                  style: _dashboardTextStyle(size: 9.2, weight: FontWeight.w400)
                      .copyWith(color: _subtitleTextColor(), height: 1.0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildTeamPillButton('SEND REMINDER', () => context.push('/send-reminder')),
              _buildTeamPillButton('TRIGGER ESCALATION', _triggerEscalation),
              _buildTeamPillButton('DELIVERABLES OVERVIEW', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeliverablesMetricsScreen(),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminQuickActionsPanel() {
    return Container(
      width: double.infinity,
      decoration: _adminContentPanelDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTeamRoundIcon(
                Icons.rocket_launch_outlined,
                assetPath: 'assets/Quick_Actions.png',
                containerSize: 44,
                assetVisualScale: 1.45,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Actions',
                      style: _dashboardTextStyle(size: 20, weight: FontWeight.w700)),
                  Text('Additional description can be included if required.',
                      style: _dashboardTextStyle(size: 11)
                          .copyWith(color: _subtitleTextColor())),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = [
                _buildAdminFeatureTile(
                  icon: Icons.settings_applications_outlined,
                  label: 'System Metrics',
                  iconAssetPath: 'assets/System_metrics.png',
                  onTap: () => context.go('/system-metrics'),
                ),
                _buildAdminFeatureTile(
                  icon: Icons.manage_accounts_outlined,
                  label: 'User Management',
                  iconAssetPath: 'assets/User_management.png',
                  onTap: () => context.go('/role-management'),
                ),
                _buildAdminFeatureTile(
                  icon: Icons.health_and_safety_outlined,
                  label: 'System Health',
                  iconAssetPath: 'assets/System_Health.png',
                  onTap: () => context.go('/system-health'),
                ),
                _buildAdminFeatureTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Audit Logs',
                  iconAssetPath: 'assets/Audit_Logs.png',
                  onTap: () => context.go('/audit-logs'),
                ),
                _buildAdminFeatureTile(
                  icon: Icons.assignment_outlined,
                  label: 'Deliverables Overview',
                  iconAssetPath: 'assets/Deliverables_overview.png',
                  onTap: () => context.go('/deliverables-overview'),
                ),
              ];

              // Match design: desktop cards fill the full row width.
              if (constraints.maxWidth >= 900) {
                return Row(
                  children: [
                    for (int i = 0; i < tiles.length; i++) ...[
                      Expanded(child: tiles[i]),
                      if (i != tiles.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                );
              }

              // Responsive fallback for narrower widths.
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiles
                    .map((tile) => SizedBox(width: 170, child: tile))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminFeatureTile({
    required IconData icon,
    required String label,
    String? iconAssetPath,
    required VoidCallback onTap,
  }) {
    final bool isHovered = _hoveredAdminQuickAction == label;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredAdminQuickAction = label),
      onExit: (_) => setState(() => _hoveredAdminQuickAction = null),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFB01313), width: 1),
            color: isHovered ? FlownetColors.primary : Colors.transparent,
          ),
          child: Column(
            children: [
              _buildTeamRoundIcon(
                icon,
                size: 16,
                assetPath: iconAssetPath,
                containerSize: 36,
                assetVisualScale: 1.5,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: _dashboardTextStyle(size: 11, weight: FontWeight.w700).copyWith(
                      color: isHovered ? Colors.white : _dashboardTextStyle().color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminDeliverablesPanel() {
    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(_dashboardDeliverables);
    if (_selectedAdminFilter != null) {
      switch (_selectedAdminFilter) {
        case 'HIGH PRIORITY':
          items = items.where((d) => (d['priority'] ?? '').toString().toLowerCase() == 'high').toList();
          break;
        case 'MEDIUM PRIORITY':
          items = items.where((d) => (d['priority'] ?? '').toString().toLowerCase() == 'medium').toList();
          break;
        case 'LOW PRIORITY':
          items = items.where((d) => (d['priority'] ?? '').toString().toLowerCase() == 'low').toList();
          break;
      }
    }

    return Container(
      decoration: _adminContentPanelDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTeamRoundIcon(
                Icons.error_outline,
                assetPath: 'assets/Deliverables_overview.png',
                containerSize: 44,
                assetVisualScale: 1.45,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pending Approvals',
                        style: _dashboardTextStyle(size: 20, weight: FontWeight.w700)),
                    Text('Additional description can be included if required.',
                        style: _dashboardTextStyle(size: 11)
                            .copyWith(color: _subtitleTextColor())),
                  ],
                ),
              ),
              _buildTeamRoundIcon(
                Icons.notifications_none,
                size: 16,
                assetPath: 'assets/notification.png',
              ),
              const SizedBox(width: 6),
              Text('${items.length}',
                  style: _dashboardTextStyle(size: 16, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: _adminDividerColor, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildAdminMiniFilter('VIEW ALL'),
              const SizedBox(width: 8),
              _buildAdminMiniFilter('HIGH PRIORITY'),
              const SizedBox(width: 8),
              _buildAdminMiniFilter('MEDIUM PRIORITY'),
              const SizedBox(width: 8),
              _buildAdminMiniFilter('LOW PRIORITY'),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingDashboardDeliverables)
            const Center(child: CircularProgressIndicator())
          else if (items.isEmpty)
            Text('No deliverables yet', style: _dashboardTextStyle())
          else
            ...items.take(8).map((d) {
              final title =
                  (d['title'] ?? d['name'] ?? d['deliverableName'] ?? 'Document Name').toString();
              final due = (d['due_date'] ?? d['dueDate'] ?? d['deadline'] ?? '').toString();
              final shortDue = due.isNotEmpty && due.length >= 10 ? due.substring(0, 10) : due;
              final id = (d['id']?.toString() ?? d['uuid']?.toString() ?? '');
              final priority = (d['priority'] ?? 'medium').toString().toLowerCase();
              final status = (d['status'] ?? '').toString().toLowerCase();
              final isCompleted = status == 'completed' || status == 'approved' || status == 'signed_off';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$title - Draft Description',
                          style: _dashboardTextStyle(size: 12)),
                    ),
                    if (shortDue.isNotEmpty)
                      Text(shortDue, style: _dashboardTextStyle(size: 11)),
                    const SizedBox(width: 8),
                    _buildTeamPriorityBadge(priority),
                    const SizedBox(width: 8),
                    _buildTeamActionPill('EDIT', () => _editDeliverable(d)),
                    const SizedBox(width: 6),
                    _buildTeamActionPill('COMPLETE', () {
                      if (id.isNotEmpty) {
                        _updateDeliverableStatus(id, 'completed');
                      }
                    }),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAdminProjectsPanel() {
    return Container(
      decoration: _adminContentPanelDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTeamRoundIcon(
                Icons.folder_copy_outlined,
                assetPath: 'assets/Projects_overview.png',
                containerSize: 44,
                assetVisualScale: 1.45,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projects Overview',
                        style: _dashboardTextStyle(size: 20, weight: FontWeight.w700)),
                    Text('Additional description can be included.',
                        style: _dashboardTextStyle(size: 11)
                            .copyWith(color: _subtitleTextColor())),
                  ],
                ),
              ),
              _buildTeamRoundIcon(
                Icons.notifications_none,
                size: 16,
                assetPath: 'assets/notification.png',
              ),
              const SizedBox(width: 6),
              Text('${_dashboardProjects.length}',
                  style: _dashboardTextStyle(size: 16, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: _adminDividerColor, height: 1),
          const SizedBox(height: 8),
          if (_isLoadingDashboardProjects)
            const Center(child: CircularProgressIndicator())
          else if (_dashboardProjects.isEmpty)
            Text('No projects found', style: _dashboardTextStyle())
          else
            ..._dashboardProjects.take(8).map((p) {
              final name = (p['name'] ?? 'Project').toString();
              final id = (p['id'] ?? '').toString();
              final description =
                  (p['description'] ?? 'Completed ${name.toLowerCase()}').toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: id.isNotEmpty ? () => context.go('/project-workspace/$id') : null,
                  child: Row(
                    children: [
                      Icon(Icons.check_box,
                          size: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$name: $description',
                          style: _dashboardTextStyle(size: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAdminMiniFilter(String label) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final bool isActive = _selectedAdminFilter == label || _hoveredAdminFilter == label;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredAdminFilter = label),
      onExit: (_) => setState(() => _hoveredAdminFilter = null),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedAdminFilter = label == 'VIEW ALL' ? null : label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFC10D00)),
            color: isActive ? const Color(0xFFC10D00) : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : textColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // Match Figma: only the reminder card uses the light grey fill.
  BoxDecoration _adminPanelDecoration() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDarkMode
          ? const Color(0x99818298)
          : const Color(0xFFA8A9B7),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: isDarkMode
            ? const Color(0xFF979797)
            : const Color(0xFF9FA0AE),
        width: 0.9,
      ),
    );
  }

  // Other content cards stay darker, not light-grey.
  BoxDecoration _adminContentPanelDecoration() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDarkMode
          ? const Color(0xCC1F1F23)
          : const Color(0xFFE8E8E8),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isDarkMode
            ? const Color(0xFF2F3138)
            : const Color(0xFFD5D5D9),
        width: isDarkMode ? 0.9 : 0.8,
      ),
    );
  }

  Color get _adminDividerColor {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode
        ? const Color(0x66BFC3CC)
        : const Color(0xFFCFCFCF);
  }

  Future<void> _triggerEscalation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trigger Escalation'),
          content: const Text(
              'This will check for stalled approvals and send escalation notifications. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Trigger'),
            ),
          ],
        ),
      );

      if (result != true) return;

      final resp = await _backendService.triggerEscalation(force: true);
      if (resp.isSuccess) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Escalation process triggered successfully')));
      } else {
        messenger.showSnackBar(SnackBar(
            content: Text('Failed to trigger escalation: ${resp.error}')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  bool _canShowRoleAction() {
    final auth = AuthService();
    final canCreateDeliverable = auth.canCreateDeliverable();
    final canManageUsers = auth.canManageUsers();
    return canCreateDeliverable || canManageUsers;
  }

  Widget _buildBottomRightExpandableFab() {
    if (!_canShowRoleAction()) return const SizedBox.shrink();
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor =
        _currentUser?.roleColor ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isBottomFabExpanded) ...[
          _buildFabCircleButton(
            icon: isDarkMode ? Icons.light_mode : Icons.dark_mode,
            backgroundColor:
                isDarkMode ? FlownetColors.surface : FlownetColors.pureWhite,
            foregroundColor: isDarkMode ? Colors.white : Colors.black,
            onTap: () {
              ProviderScope.containerOf(context, listen: false)
                  .read(themeProvider.notifier)
                  .toggleTheme();
            },
          ),
          const SizedBox(width: 8),
          _buildAgentFabButton(
            onTap: () => context.go('/ai-assistant'),
          ),
          const SizedBox(width: 8),
        ],
        _buildFabCircleButton(
          icon: _isBottomFabExpanded
              ? Icons.keyboard_arrow_right
              : Icons.keyboard_arrow_left,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          onTap: () {
            setState(() {
              _isBottomFabExpanded = !_isBottomFabExpanded;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFabCircleButton({
    IconData? icon,
    Widget? child,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: child ?? Icon(icon, color: foregroundColor, size: 20),
      ),
    );
  }

  Widget _buildAgentFabButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/red_icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFD10D00),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.smart_toy,
                size: 22,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildWelcomeCard() {
    return Card(
      child: ListTile(
        leading: FutureBuilder<Uint8List?>(
          future: _loadAvatarBytes(_currentUser!.id),
          builder: (context, snapshot) {
            final hasImage =
                snapshot.hasData && (snapshot.data?.isNotEmpty ?? false);
            return CircleAvatar(
              backgroundImage: hasImage ? MemoryImage(snapshot.data!) : null,
              child: hasImage
                  ? null
                  : Icon(_currentUser?.roleIcon ?? Icons.person),
            );
          },
        ),
        title: Text('Welcome, ${_currentUser?.name ?? 'User'}'),
        subtitle:
            Text('${_currentUser?.roleDisplayName ?? 'Member'} Dashboard'),
      ),
    );
  }

  Future<Uint8List?> _loadAvatarBytes(String userId) async {
    try {
      final base = Uri.parse(ApiService.baseUrl);
      final url =
          '${base.scheme}://${base.host}:${base.port}/api/v1/profile/$userId/picture?t=${DateTime.now().millisecondsSinceEpoch}';
      final headers = await ApiService.getAuthHeaders();
      final resp = await http.get(Uri.parse(url), headers: headers);
      if (resp.statusCode == 200) {
        return resp.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ignore: unused_element
  Widget _buildQuickActions() {
    final canCreate = _authService.canCreateDeliverable();
    final tiles = <Widget>[
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildActionButton(
              icon: Icons.folder_outlined,
              label: 'View Projects',
              onTap: () => context.go('/projects'),
            ),
          ),
        ),
      ),
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildActionButton(
              icon: Icons.assignment_outlined,
              label: 'View Deliverables',
              onTap: () => context.go('/deliverables'),
            ),
          ),
        ),
      ),
    ];

    if (canCreate) {
      tiles.insert(
        0,
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildActionButton(
                icon: Icons.assignment_add,
                label: 'Create Deliverable',
                onTap: () => context.go('/deliverable-setup'),
              ),
            ),
          ),
        ),
      );
      tiles.add(
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildActionButton(
                icon: Icons.description_outlined,
                label: 'Build Report',
                onTap: () {
                  final first =
                      _dashboardDeliverables.isNotEmpty ? _dashboardDeliverables.first : null;
                  final sprintId = first != null ? _extractFirstSprintId(first) : null;
                  if (sprintId != null && sprintId.isNotEmpty) {
                    context.go('/sprint-report/$sprintId');
                    return;
                  }
                  context.go('/sprint-console');
                },
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        for (int i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          tiles[i],
        ]
      ],
    );
  }

  // ignore: unused_element
  Widget _buildMyDeliverables() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoadingDashboardDeliverables
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader(Icons.assignment_outlined, 'My Deliverables',
                      route: '/deliverables'),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final uid = _currentUser?.id.toString() ?? '';
                    final my = _dashboardDeliverables.where((d) {
                      final assigned =
                          (d['assigned_to'] ?? d['assignedTo'] ?? '')
                              .toString();
                      final created =
                          (d['created_by'] ?? d['createdBy'] ?? '').toString();
                      return assigned == uid || created == uid;
                    }).toList();
                    if (my.isEmpty) {
                      return const Text('No deliverables yet');
                    }
                    return Column(
                      children: my.take(5).map((d) {
                        final title = d['title'] ??
                            d['name'] ??
                            d['deliverableName'] ??
                            'Untitled Deliverable';
                        final status =
                            (d['status'] ?? d['reviewStatus'] ?? '').toString();
                        final id = (d['id']?.toString() ??
                            d['uuid']?.toString() ??
                            '');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.assignment_turned_in,
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(status.isNotEmpty
                                          ? '$title • $status'
                                          : title)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _priorityChip(
                                      (d['priority'] ?? '').toString()),
                                  _dueDateChip(d['due_date'] ??
                                      d['dueDate'] ??
                                      d['deadline']),
                                  _ownerChip(_getOwnerName(d), _getOwnerId(d)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  TextButton.icon(
                                    onPressed: id.isEmpty
                                        ? null
                                        : () => _updateDeliverableStatus(
                                            id, 'in_progress'),
                                    icon: const Icon(Icons.play_circle_outline,
                                        size: 18),
                                    label: const Text('Start'),
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8)),
                                  ),
                                  TextButton.icon(
                                    onPressed: id.isEmpty
                                        ? null
                                        : () => _updateDeliverableStatus(
                                            id, 'completed'),
                                    icon: const Icon(Icons.check_circle_outline,
                                        size: 18),
                                    label: const Text('Complete'),
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8)),
                                  ),
                                  TextButton.icon(
                                    onPressed: id.isEmpty
                                        ? null
                                        : () =>
                                            _openSprintReportForDeliverable(d),
                                    icon: const Icon(Icons.description_outlined,
                                        size: 18),
                                    label: const Text('Report'),
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8)),
                                  ),
                                  TextButton.icon(
                                    onPressed: id.isEmpty
                                        ? null
                                        : () => _editDeliverable(d),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    label: const Text('Edit'),
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8)),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      if (id.isNotEmpty) {
                                        try {
                                          final deliverable =
                                              Deliverable.fromJson(d);
                                          context.push('/deliverable-detail',
                                              extra: deliverable);
                                        } catch (e) {
                                          debugPrint(
                                              'Error parsing deliverable for navigation: $e');
                                          context.go('/repository');
                                        }
                                      } else {
                                        context.go('/repository');
                                      }
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    tooltip: 'Open',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoadingAuditLogs
            ? const Center(child: CircularProgressIndicator())
            : (_auditLogsError != null
                ? Text(_auditLogsError!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardHeader(Icons.history, 'Recent Activity',
                          route: '/notifications'),
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final userId = _currentUser?.id.toString() ?? '';
                        final userName = _currentUser?.name ?? '';
                        final my = _filteredAuditLogs.where((a) {
                          final actor =
                              (a['actor'] ?? a['user'] ?? '').toString();
                          final uid =
                              (a['user_id'] ?? a['actor_id'] ?? '').toString();
                          return actor == userName || uid == userId;
                        }).toList();
                        if (my.isEmpty) return const Text('No recent activity');
                        return Column(
                          children: my.take(5).map((a) {
                            final action = a['action'] ??
                                a['event'] ??
                                a['type'] ??
                                'Activity';
                            final actor = a['actor'] ?? a['user'] ?? '';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: InkWell(
                                onTap: () {
                                  context.go('/notifications');
                                },
                                child: Row(
                                  children: [
                                    const Icon(Icons.history, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(actor.toString().isNotEmpty
                                            ? '$action • $actor'
                                            : action)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }),
                    ],
                  )),
      ),
    );
  }

  Widget _buildSprintOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoadingDashboardSprints
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader(Icons.flag_outlined,
                      'Sprint Overview (${_dashboardSprints.length})',
                      route: '/sprint-console'),
                  const SizedBox(height: 8),
                  ..._dashboardSprints.take(5).map((s) {
                    final name =
                        s['name'] ?? s['title'] ?? s['sprintName'] ?? 'Sprint';
                    final status = s['status'] ?? s['state'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: InkWell(
                        onTap: () {
                          final id = s['id']?.toString() ??
                              s['uuid']?.toString() ??
                              '';
                          final name = s['name']?.toString() ??
                              s['title']?.toString() ??
                              '';
                          final route = id.isNotEmpty
                              ? '/sprint-board/$id${name.isNotEmpty ? '?name=${Uri.encodeComponent(name)}' : ''}'
                              : '/sprint-console';
                          context.go(route);
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.flag_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(status.toString().isNotEmpty
                                    ? '$name • $status'
                                    : name)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildReviewMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(Icons.rate_review_outlined, 'Review Metrics',
                route: '/report-repository'),
            const SizedBox(height: 12),
            if (_isLoadingClientMetrics)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metricTile(
                      'Submitted',
                      _clientReviewMetrics['submitted'] ?? 0,
                      Icons.upload_outlined,
                      Colors.orange),
                  _metricTile('Approved', _clientReviewMetrics['approved'] ?? 0,
                      Icons.check_circle_outline, Colors.green),
                  _metricTile(
                      'Changes Requested',
                      _clientReviewMetrics['changes'] ?? 0,
                      Icons.edit_note,
                      Colors.blueGrey),
                  _metricTile('Rejected', _clientReviewMetrics['rejected'] ?? 0,
                      Icons.cancel_outlined, Colors.red),
                  _metricTile(
                      'Avg Review Time',
                      _clientReviewMetrics['avg_review_time'] ?? '-',
                      Icons.schedule_outlined,
                      Colors.blue),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPendingApprovals() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoadingPendingReports
            ? const Center(child: CircularProgressIndicator())
            : (_pendingReportsError != null
                ? Text(_pendingReportsError!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardHeader(Icons.rule_folder_outlined,
                          'Pending Approvals (${_pendingReports.length})',
                          route: '/report-repository'),
                      const SizedBox(height: 8),
                      ..._pendingReports.take(5).map((r) {
                        final title = (r['reportTitle'] ??
                                r['report_title'] ??
                                (r['content'] is Map
                                    ? (r['content']['reportTitle'] ??
                                        r['content']['title'])
                                    : null) ??
                                r['title'] ??
                                'Sign-Off Report')
                            .toString();
                        final createdBy = (r['createdBy'] ??
                                r['created_by_name'] ??
                                r['created_by'] ??
                                '')
                            .toString();
                        final id = (r['id'] ?? r['report_id'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    if (id.isNotEmpty) {
                                      context.go('/client-review/$id');
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(
                                          Icons.assignment_turned_in_outlined,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(createdBy.isNotEmpty
                                              ? '$title • $createdBy'
                                              : title)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: id.isEmpty
                                    ? null
                                    : () => _approveReport(id),
                                icon: const Icon(Icons.check_circle_outline,
                                    size: 18),
                                label: const Text('Approve'),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: id.isEmpty
                                    ? null
                                    : () => _promptChangeRequest(r),
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: const Text('Request Changes'),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  )),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildRecentSubmissions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(Icons.upload_outlined, 'Recent Submissions',
                route: '/report-repository'),
            const SizedBox(height: 8),
            if (_isLoadingPendingReports)
              const Center(child: CircularProgressIndicator())
            else if (_pendingReports.isEmpty)
              const Text('No recent submissions')
            else
              ..._pendingReports.take(5).map((r) {
                final title = (r['reportTitle'] ??
                        r['report_title'] ??
                        (r['content'] is Map
                            ? (r['content']['reportTitle'] ??
                                r['content']['title'])
                            : null) ??
                        r['title'] ??
                        'Sign-Off Report')
                    .toString();
                final createdAtStr =
                    (r['created_at'] ?? r['createdAt'] ?? r['created'] ?? '')
                        .toString();
                String ts = createdAtStr;
                try {
                  final dt = DateTime.tryParse(createdAtStr);
                  if (dt != null) ts = '${dt.toLocal()}';
                } catch (_) {}
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.upload_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(ts.isNotEmpty ? '$title • $ts' : title)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildReviewHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoadingAuditLogs
            ? const Center(child: CircularProgressIndicator())
            : (_auditLogsError != null
                ? Text(_auditLogsError!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardHeader(Icons.rate_review_outlined,
                          'Review History (${_filteredAuditLogs.length})',
                          route: '/report-repository'),
                      const SizedBox(height: 8),
                      ..._filteredAuditLogs.take(5).map((a) {
                        final action =
                            a['action'] ?? a['event'] ?? a['type'] ?? 'Review';
                        final actor = a['actor'] ?? a['user'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: InkWell(
                            onTap: () {
                              context.go('/report-repository');
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.rate_review_outlined,
                                    size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(actor.toString().isNotEmpty
                                        ? '$action • $actor'
                                        : action)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  )),
      ),
    );
  }

  Widget _metricTile(String label, dynamic value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              Text(value is String ? value : value.toString(),
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priorityChip(String priority) {
    final p = priority.toLowerCase();
    Color c;
    if (p == 'high') {
      c = Colors.red;
    } else if (p == 'medium') {
      c = Colors.orange;
    } else if (p == 'low') {
      c = Colors.green;
    } else {
      c = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        border: Border.all(color: c.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 14),
          const SizedBox(width: 4),
          Text(p.isNotEmpty ? p : 'priority'),
        ],
      ),
    );
  }

  Widget _dueDateChip(dynamic dueRaw) {
    String label = '';
    if (dueRaw != null) {
      final s = dueRaw.toString();
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        label = dt.toLocal().toString();
      } else {
        label = s;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event, size: 14),
          const SizedBox(width: 4),
          Text(label.isNotEmpty ? label : 'due date'),
        ],
      ),
    );
  }

  Widget _ownerChip(String? ownerName, String? ownerId) {
    // If we have a name, use it
    if (ownerName != null && ownerName.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 14),
            const SizedBox(width: 4),
            Text(ownerName),
          ],
        ),
      );
    }

    // If we only have an ID, try to resolve it asynchronously
    if (ownerId != null && ownerId.isNotEmpty) {
      return FutureBuilder<String>(
        future: _getUserNameById(ownerId),
        builder: (context, snapshot) {
          final label = snapshot.hasData 
              ? snapshot.data! 
              : 'Loading...';
          
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.12),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 14),
                const SizedBox(width: 4),
                Text(label),
              ],
            ),
          );
        },
      );
    }

    // Fallback to Unassigned
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 14),
          SizedBox(width: 4),
          Text('Unassigned'),
        ],
      ),
    );
  }

  Future<void> _editDeliverable(Map<String, dynamic> d) async {
    final id = (d['id']?.toString() ?? d['uuid']?.toString() ?? '');
    if (id.isEmpty) return;

    try {
      final deliverable = Deliverable.fromJson(d);
      await context.push('/deliverable-detail', extra: deliverable);
      // Reload deliverables when returning to reflect changes
      _loadDashboardDeliverables();
    } catch (e) {
      debugPrint('Error navigating to deliverable detail: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening deliverable: $e')),
      );
    }
  }

  Future<void> _updateDeliverableStatus(String id, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.updateDeliverableStatus(id: id, status: status);
      setState(() {
        _dashboardDeliverables = _dashboardDeliverables.map((d) {
          final dId = (d['id']?.toString() ?? d['uuid']?.toString() ?? '');
          if (dId == id) {
            final m = Map<String, dynamic>.from(d);
            m['status'] = status;
            return m;
          }
          return d;
        }).toList();
      });
      messenger
          .showSnackBar(SnackBar(content: Text('Status updated to $status')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  Future<void> _loadPendingReports() async {
    setState(() {
      _isLoadingPendingReports = true;
      _pendingReportsError = null;
    });
    try {
      final resp = await _reportService.getSignOffReports(status: 'submitted');
      if (resp.isSuccess && resp.data != null) {
        final raw = resp.data;
        List<dynamic> items = const [];
        if (raw is List) {
          items = raw;
        } else if (raw is Map) {
          final d = raw['data'];
          if (d is List) {
            items = d;
          } else if (d is Map) {
            final inner = d['reports'] ?? d['items'] ?? d['data'];
            if (inner is List) {
              items = inner;
            }
          } else {
            final r = raw['reports'];
            if (r is List) {
              items = r;
            } else if (r is Map) {
              final inner = r['items'] ?? r['data'];
              if (inner is List) items = inner;
            } else {
              final i = raw['items'];
              if (i is List) items = i;
            }
          }
        }
        setState(() {
          final parsed = items.whereType<Map>().map((e) {
            final m = e.cast<String, dynamic>();
            final c = m['content'];
            if (c is String) {
              try {
                final decoded = jsonDecode(c);
                if (decoded is Map) {
                  m['content'] = Map<String, dynamic>.from(decoded);
                }
              } catch (_) {}
            }
            return m;
          });
          _pendingReports = parsed.where((m) {
            final content = m['content'];
            final statusRaw = (m['status'] ??
                    m['review_status'] ??
                    (content is Map ? content['status'] : null) ??
                    '')
                .toString()
                .toLowerCase();
            if (statusRaw.isEmpty) {
              return true; // Default to include when unknown
            }
            return statusRaw == 'submitted' ||
                statusRaw == 'under_review' ||
                statusRaw == 'underreview';
          }).toList();
        });
      } else {
        setState(() {
          _pendingReports = [];
          _pendingReportsError = resp.error ?? 'Failed to load pending reports';
        });
      }
    } catch (_) {
      setState(() {
        _pendingReports = [];
        _pendingReportsError = 'Failed to load pending reports';
      });
    } finally {
      if (mounted) setState(() => _isLoadingPendingReports = false);
    }
  }

  Future<void> _loadClientReviewMetrics() async {
    if (!mounted) return;
    setState(() => _isLoadingClientMetrics = true);
    try {
      final resp = await _reportService.getSignOffReports();
      final m = {
        'draft': 0,
        'submitted': 0,
        'approved': 0,
        'changes': 0,
        'rejected': 0,
        'avg_review_time': '-',
      };
      if (resp.isSuccess && resp.data != null) {
        final raw = resp.data;
        List<dynamic> items = const [];
        if (raw is List) {
          items = raw;
        } else if (raw is Map) {
          final d = raw['data'];
          if (d is List) {
            items = d;
          } else if (d is Map) {
            final inner = d['reports'] ?? d['items'] ?? d['data'];
            if (inner is List) {
              items = inner;
            } else {
              items = const [];
            }
          } else {
            final r = raw['reports'];
            if (r is List) {
              items = r;
            } else if (r is Map) {
              final inner = r['items'] ?? r['data'];
              if (inner is List) items = inner;
            } else {
              final i = raw['items'];
              if (i is List) items = i;
            }
          }
        }
        int draft = 0;
        int submitted = 0;
        int approved = 0;
        int changes = 0;
        int rejected = 0;
        final durations = <double>[];
        for (final r in items.whereType<Map>()) {
          final s = (r['status'] ?? '').toString().toLowerCase();
          if (s == 'draft') draft++;
          if (s == 'submitted') submitted++;
          if (s == 'approved') approved++;
          if (s.contains('change')) changes++;
          if (s == 'rejected' || s == 'declined') rejected++;
          final createdStr =
              (r['created_at'] ?? r['createdAt'] ?? '').toString();
          final approvedStr =
              (r['approved_at'] ?? r['approvedAt'] ?? r['reviewed_at'] ?? '')
                  .toString();
          final created = DateTime.tryParse(createdStr);
          final approvedDt = DateTime.tryParse(approvedStr);
          if (created != null &&
              approvedDt != null &&
              approvedDt.isAfter(created)) {
            final hours = approvedDt.difference(created).inMinutes / 60.0;
            durations.add(hours);
          }
        }
        m['draft'] = draft;
        m['submitted'] = submitted;
        m['approved'] = approved;
        m['changes'] = changes;
        m['rejected'] = rejected;
        if (durations.isNotEmpty) {
          final avg = durations.reduce((a, b) => a + b) / durations.length;
          m['avg_review_time'] = '${avg.toStringAsFixed(1)}h';
        }
      }
      if (!mounted) return;
      setState(() {
        _clientReviewMetrics = m;
      });
    } finally {
      if (mounted) setState(() => _isLoadingClientMetrics = false);
    }
  }

  Future<void> _approveReport(String reportId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final signatureKey = GlobalKey<SignatureCaptureWidgetState>();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Digital Signature'),
            content: SizedBox(
              width: 520,
              child: SignatureCaptureWidget(
                key: signatureKey,
                allowSignatureReuse: true,
                showAuditInfo: true,
                reportId: reportId,
              ),
            ),
            actions: [
              TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => context.pop(true), child: const Text('Approve')),
            ],
          );
        },
      );
      if (confirmed != true) return;
      final signature = await signatureKey.currentState?.getSignature();
      if (signature == null || signature.trim().isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Digital signature is required')));
        return;
      }

      final resp = await _reportService.approveReport(reportId, digitalSignature: signature);
      if (resp.isSuccess) {
        setState(() {
          _pendingReports = _pendingReports
              .where((e) =>
                  (e['id']?.toString() ?? e['report_id']?.toString() ?? '') !=
                  reportId)
              .toList();
        });
        await _notifyReportSender(reportId, approved: true);
        messenger
            .showSnackBar(const SnackBar(content: Text('Report approved')));
        _loadClientReviewMetrics();
      } else {
        messenger.showSnackBar(
            SnackBar(content: Text(resp.error ?? 'Failed to approve report')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _requestChanges(String reportId, String details) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (details.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Change request details are required')),
        );
        return;
      }
      final signatureKey = GlobalKey<SignatureCaptureWidgetState>();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Digital Signature'),
            content: SizedBox(
              width: 520,
              child: SignatureCaptureWidget(
                key: signatureKey,
                allowSignatureReuse: true,
                showAuditInfo: true,
                reportId: reportId,
              ),
            ),
            actions: [
              TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => context.pop(true), child: const Text('Continue')),
            ],
          );
        },
      );
      if (confirmed != true) return;
      final signature = await signatureKey.currentState?.getSignature();
      if (signature == null || signature.trim().isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Digital signature is required')));
        return;
      }

      final resp = await _reportService.requestChanges(
        reportId,
        changeRequestDetails: details.isNotEmpty ? details : null,
        digitalSignature: signature,
      );
      if (resp.isSuccess) {
        setState(() {
          _pendingReports = _pendingReports
              .where((e) =>
                  (e['id']?.toString() ?? e['report_id']?.toString() ?? '') !=
                  reportId)
              .toList();
        });
        await _notifyReportSender(reportId, approved: false, details: details);
        messenger
            .showSnackBar(const SnackBar(content: Text('Change request sent')));
        _loadClientReviewMetrics();
      } else {
        messenger.showSnackBar(
            SnackBar(content: Text(resp.error ?? 'Failed to request changes')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _notifyReportSender(String reportId,
      {required bool approved, String? details}) async {
    try {
      final token = _authService.accessToken;
      final ns = NotificationService();
      if (token != null) ns.setAuthToken(token);
      final resp = await _backendService.getSignOffReport(reportId);
      String title = approved ? 'Report Approved' : 'Report Changes Requested';
      String message = approved
          ? '${_currentUser?.name ?? 'Reviewer'} approved "Report"'
          : '${_currentUser?.name ?? 'Reviewer'} requested changes on "Report"';
      String? targetUserId;
      if (resp.isSuccess && resp.data != null) {
        final raw = resp.data;
        Map<String, dynamic> m = {};
        if (raw is Map<String, dynamic>) {
          final d = raw['data'];
          if (d is Map<String, dynamic>) {
            m = d;
          } else {
            m = raw;
          }
        }
        final content = m['content'];
        final String reportTitle = (m['reportTitle'] ??
                m['report_title'] ??
                (content is Map
                    ? (content['reportTitle'] ?? content['title'])
                    : null) ??
                m['title'] ??
                'Report')
            .toString();
        title = approved ? 'Report Approved' : 'Report Changes Requested';
        message = approved
            ? '${_currentUser?.name ?? 'Reviewer'} approved "$reportTitle"'
            : '${_currentUser?.name ?? 'Reviewer'} requested changes for "$reportTitle"';
        final createdByRaw =
            (m['createdBy'] ?? m['created_by'] ?? '').toString();
        final createdByName =
            (m['createdByName'] ?? m['created_by_name'] ?? '').toString();
        if (createdByRaw.isNotEmpty) {
          final isUuidLike = RegExp(r'^[a-f0-9-]{8,}$', caseSensitive: false)
              .hasMatch(createdByRaw);
          final looksLikeEmail = createdByRaw.contains('@');
          final hasSpaces = createdByRaw.contains(' ');
          if (isUuidLike && !looksLikeEmail && !hasSpaces) {
            targetUserId = createdByRaw;
          }
        }
        if (targetUserId == null && createdByName.isNotEmpty) {
          try {
            final usersResp =
                await _backendService.getUsers(page: 1, limit: 200);
            final rawUsers = usersResp.isSuccess ? usersResp.data : null;
            final List<dynamic> items = rawUsers is List
                ? rawUsers
                : (rawUsers is Map<String, dynamic>
                    ? (rawUsers['data'] ??
                        rawUsers['users'] ??
                        rawUsers['items'] ??
                        [])
                    : []);
            for (final u in items) {
              if (u is Map) {
                final um = Map<String, dynamic>.from(u);
                final name = (um['name'] ?? '').toString();
                final first =
                    (um['first_name'] ?? um['firstName'] ?? '').toString();
                final last =
                    (um['last_name'] ?? um['lastName'] ?? '').toString();
                final combined = ('$first $last').trim();
                if (name.toLowerCase() == createdByName.toLowerCase() ||
                    (combined.isNotEmpty &&
                        combined.toLowerCase() ==
                            createdByName.toLowerCase())) {
                  targetUserId = (um['id'] ?? '').toString();
                  break;
                }
              }
            }
          } catch (_) {}
        }
      }
      await ns.createNotification(
          title: title,
          message: message,
          type: approved
              ? NotificationType.reportApproved
              : NotificationType.reportChangesRequested,
          userId: targetUserId);
      try {
        final event = approved ? 'report_approved' : 'report_change_requested';
        realtimeService.emit(event, {'reportId': reportId});
        realtimeService.emit('approval_updated', {'reportId': reportId});
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _promptChangeRequest(Map<String, dynamic> report) async {
    final id = (report['id'] ?? report['report_id'] ?? '').toString();
    if (id.isEmpty) return;
    String details = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Request Changes'),
          content: TextField(
            onChanged: (v) => details = v,
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Change Request Details',
                helperText: 'Required'),
            maxLines: 4,
          ),
          actions: [
            TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => context.pop(true), child: const Text('Send')),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _requestChanges(id, details.trim());
    }
  }

  Widget _buildDeveloperDashboard() => _buildTeamMemberDashboard();
  Widget _buildProjectManagerDashboard() => _buildDeliveryLeadDashboard();
  Widget _buildScrumMasterDashboard() => _buildDeliveryLeadDashboard();
  Widget _buildQAEngineerDashboard() => _buildTeamMemberDashboard();
  Widget _buildStakeholderDashboard() => _buildClientReviewerDashboard();

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: _currentUser?.isSystemAdmin == true
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      label: Text(label),
    );
  }

  String? _extractFirstSprintId(Map<String, dynamic> deliverable) {
    final ids = <String>[];

    void add(dynamic v) {
      final s = v?.toString();
      if (s != null && s.trim().isNotEmpty) ids.add(s.trim());
    }

    void addFromList(dynamic v) {
      if (v is List) {
        for (final item in v) {
          add(item);
        }
      }
    }

    addFromList(deliverable['sprintIds']);
    addFromList(deliverable['sprint_ids']);
    add(deliverable['sprint_id']);
    add(deliverable['sprintId']);

    final contributing = deliverable['contributing_sprints'] ??
        deliverable['contributingSprints'] ??
        deliverable['sprints'];
    if (contributing is List) {
      for (final item in contributing) {
        if (item is Map) {
          add(item['id'] ?? item['sprint_id'] ?? item['sprintId']);
        } else {
          add(item);
        }
      }
    }

    if (ids.isEmpty) return null;
    return ids.first;
  }

  void _openSprintReportForDeliverable(Map<String, dynamic> deliverable) {
    final sprintId = _extractFirstSprintId(deliverable);
    if (sprintId != null && sprintId.isNotEmpty) {
      context.go('/sprint-report/$sprintId');
      return;
    }
    context.go('/sprint-console');
  }

  Widget _buildCardHeader(IconData icon, String label, {String? route}) {
    final row = Row(
      children: [
        Icon(
          icon,
          color: _currentUser?.isSystemAdmin == true
              ? Theme.of(context).colorScheme.secondary
              : null,
        ),
        const SizedBox(width: 8),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
    if (route == null) return row;
    return InkWell(onTap: () => context.go(route), child: row);
  }

  void _setupRealtimeListeners() {
    // Clear existing listeners to prevent duplicates
    realtimeService.offAll('user_role_changed');
    realtimeService.offAll('sprint_created');
    realtimeService.offAll('sprint_updated');
    realtimeService.offAll('deliverable_created');
    realtimeService.offAll('deliverable_updated');
    realtimeService.offAll('approval_created');
    realtimeService.offAll('approval_updated');
    realtimeService.offAll('report_submitted');
    realtimeService.offAll('report_approved');
    realtimeService.offAll('report_change_requested');
    realtimeService.offAll('project_created');
    realtimeService.offAll('project_updated');
    realtimeService.offAll('audit_log_created');
    // Note: notifications listeners are handled by NotificationCenterWidget, do not offAll here

    realtimeService.on('user_role_changed', _handleRoleChanged);
    realtimeService.on('sprint_created', (_) => _loadDashboardSprints());
    realtimeService.on('sprint_updated', (_) => _loadDashboardSprints());
    realtimeService.on(
        'deliverable_created', (_) => _loadDashboardDeliverables());
    realtimeService.on(
        'deliverable_updated', (_) => _loadDashboardDeliverables());
    realtimeService.on('approval_created', (_) {
      _loadPendingReports();
      _loadClientReviewMetrics();
      _loadDashboardDeliverables();
    });
    realtimeService.on('approval_updated', (_) {
      _loadPendingReports();
      _loadClientReviewMetrics();
      _loadDashboardDeliverables();
    });
    realtimeService.on('report_submitted', (_) {
      _loadPendingReports();
      _loadClientReviewMetrics();
      _loadDashboardDeliverables();
    });
    realtimeService.on('report_approved', (_) {
      _loadPendingReports();
      _loadClientReviewMetrics();
      _loadDashboardDeliverables();
    });
    realtimeService.on('report_change_requested', (_) {
      _loadPendingReports();
      _loadClientReviewMetrics();
      _loadDashboardDeliverables();
    });
    realtimeService.on('project_created', (_) => _loadDashboardProjects());
    realtimeService.on('project_updated', (_) => _loadDashboardProjects());
    realtimeService.on('audit_log_created', _handleAuditLogCreated);
    realtimeService.on('notification_received', (data) {
      try {
        final type = (data['type'] ?? '').toString();
        if (type == 'project') {
          _loadDashboardProjects();
        } else if (type == 'sprint') {
          _loadDashboardSprints();
        } else if (type == 'deliverable' ||
            type == 'approval' ||
            type == 'change_request') {
          _loadDashboardDeliverables();
          _loadPendingReports();
          _loadClientReviewMetrics();
        }
      } catch (_) {}
    });
  }

  void _handleAuditLogCreated(dynamic data) {
    try {
      if (data is! Map) return;
      final log = Map<String, dynamic>.from(data);
      final id = log['id']?.toString() ?? '';
      if (id.isNotEmpty && _auditLogs.any((e) => (e['id']?.toString() ?? '') == id)) {
        return;
      }
      _hydrateAuditActors([log]).then((_) {
        if (!mounted) return;
        setState(() {
          _auditLogs = [log, ..._auditLogs];
        });
        _applySearchAndSort();
      });
    } catch (_) {}
  }

  void _handleRoleChanged(dynamic _) {
    _loadCurrentUser();
  }

}
