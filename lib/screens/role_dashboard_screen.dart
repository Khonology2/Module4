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
import '../widgets/background_image.dart';
import '../widgets/notification_center_widget.dart';
import '../widgets/glass_card.dart';
import '../widgets/interactive_header_icon.dart';
import '../utils/app_icons.dart';
import '../theme/flownet_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class RoleDashboardScreen extends ConsumerStatefulWidget {
  const RoleDashboardScreen({super.key});

  @override
  ConsumerState<RoleDashboardScreen> createState() =>
      _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends ConsumerState<RoleDashboardScreen> {
  static const double _dashOuterPadding = 20;
  static const double _dashSectionGap = 20;

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
  Map<String, dynamic> _teamMetrics = {};
  bool _isLoadingTeamMetrics = false;
  
  // Cache for user names to avoid repeated API calls
  final Map<String, String> _userNamesCache = {};

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
  String _selectedChartType = 'velocity';
  bool _isLoadingClientMetrics = false;
  Map<String, dynamic> _clientReviewMetrics = {};

  /// Client reviewer dashboard: pending list filter (all | high | medium | low).
  String _crPendingTab = 'all';
  final Set<String> _crCheckedReportIds = {};

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
    _computeTeamMetrics();
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
    // Do not call offAll for notification_received as it affects other widgets
    super.dispose();
  }

  Future<void> _loadDashboardSprints() async {
    setState(() => _isLoadingDashboardSprints = true);
    try {
      final items = await ApiService.getSprints();
      _dashboardSprints = items;
      _computeTeamMetrics();
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

      _computeTeamMetrics();
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
      _computeTeamMetrics();
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

      // Always refresh from `/auth/me` so UI matches DB role (e.g. after promote to admin).
      final user = await _authService.getCurrentUser(refresh: true);
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackgroundImage(
        imagePath: 'assets/Icons/khono_bg.png',
        withGlassEffect: false,
        overlayOpacity: 0.25,
        child: Column(
          children: [
            // Role header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Builder(
                builder: (context) {
                  final sideSlot = MediaQuery.sizeOf(context).width < 420
                      ? 96.0
                      : 108.0;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildDashboardHeaderTitleRow(
                            titleFontSize: 22,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: sideSlot,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildDashboardHeaderTrailingActions(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Main content
            Expanded(
              child: _buildRoleSpecificContent(),
            ),
          ],
        ),
      ),
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

  /// Frosted panel for dashboard sections (shared blur/border/radius).
  Widget _glassDashboardSection({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double blur = 9,
    Color? solidTint,
    Gradient? gradientTint,
    Border? border,
  }) {
    return GlassCard(
      borderRadius: 12,
      blur: blur,
      padding: padding,
      color: solidTint,
      gradient: gradientTint,
      border: border,
      child: child,
    );
  }

  Widget _buildTeamMemberDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: _dashOuterPadding,
        vertical: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: _dashSectionGap),
          _buildQuickActions(),
          const SizedBox(height: _dashSectionGap),
          _buildKanbanLinkCard(),
          const SizedBox(height: _dashSectionGap),
          _buildMyDeliverables(),
          const SizedBox(height: _dashSectionGap),
          _buildReviewMetrics(),
          const SizedBox(height: _dashSectionGap),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildDeliveryLeadDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: _dashOuterPadding,
        vertical: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: _dashSectionGap),
          _buildReminderQuickActions(),
          const SizedBox(height: _dashSectionGap),
          _buildTeamMetrics(),
          const SizedBox(height: _dashSectionGap),
          _buildReviewMetrics(),
          const SizedBox(height: _dashSectionGap),
          _buildSprintOverview(),
          const SizedBox(height: _dashSectionGap),
          _buildKanbanLinkCard(),
          const SizedBox(height: _dashSectionGap),
          _buildDeliverablesOverview(),
          const SizedBox(height: _dashSectionGap),
          _buildProjectsOverview(),
          const SizedBox(height: _dashSectionGap),
          _buildPendingReviews(),
          const SizedBox(height: _dashSectionGap),
          _buildTeamPerformance(),
        ],
      ),
    );
  }

  Widget _buildClientReviewerDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            _dashOuterPadding,
            12,
            _dashOuterPadding,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title lives in the top header for client reviewer / client; stakeholder keeps it here.
              if (_currentUser!.role == UserRole.stakeholder) ...[
                _buildCrTitleBlock(),
                const SizedBox(height: 14),
              ],
              _buildCrApprovalRemindersBanner(),
              const SizedBox(height: 14),
              _buildCrReviewMetricsRow(),
              const SizedBox(height: 14),
              Expanded(child: _buildCrFourPanelGrid()),
            ],
          ),
        );
      },
    );
  }

  String _dashboardHeaderUserDisplayName() {
    final u = _currentUser!;
    final n = u.name.trim();
    if (n.isNotEmpty) return n;
    final e = u.email.trim();
    return e.isNotEmpty ? e : 'User';
  }

  /// Top bar: "{Role} Dashboard" (bold, larger) + "Hello, **name**" (single line, left-aligned).
  Widget _buildDashboardHeaderTitleRow({required double titleFontSize}) {
    final greetingSize = titleFontSize <= 20 ? 13.0 : 14.0;
    final baseGreeting = TextStyle(
      fontSize: greetingSize,
      color: Colors.white,
      fontWeight: FontWeight.w400,
      height: 1.2,
    );
    final name = _dashboardHeaderUserDisplayName();
    final role = _currentUser!.role;
    final titleText = (role == UserRole.client || role == UserRole.clientReviewer)
        ? 'Client Reviewer Dashboard'
        : '${role.displayName} Dashboard';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            titleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          flex: 2,
          child: Text.rich(
            TextSpan(
              style: baseGreeting,
              children: [
                const TextSpan(text: 'Hello, '),
                TextSpan(
                  text: name,
                  style: baseGreeting.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCrTitleBlock() {
    final name = _currentUser?.name ?? 'User';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Client Reviewer Dashboard',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlownetColors.pureWhite,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hello, $name',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: FlownetColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  /// Profile + notifications (active PNG on route or hover; header only).
  List<Widget> _headerProfileAndNotificationChildren() {
    final path = GoRouterState.of(context).uri.path;
    final onProfile = path == '/profile' || path.startsWith('/profile/');
    return [
      Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.go('/profile'),
          child: Tooltip(
            message: 'Profile',
            child: InteractiveHeaderIcon(
              inactiveAsset: AppIcons.accountProfileBadgeAsset,
              activeAsset: AppIcons.accountProfileBadgeAsset,
              routeActive: onProfile,
              size: 44,
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      const NotificationCenterWidget(
        showLabel: false,
        showBackground: false,
        circularLightButton: true,
      ),
    ];
  }

  /// Client roles: bell only (reference header). Others: profile + bell.
  Widget _buildDashboardHeaderTrailingActions() {
    final role = _currentUser!.role;
    if (role == UserRole.clientReviewer || role == UserRole.client) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotificationCenterWidget(
            showLabel: false,
            showBackground: false,
            circularLightButton: true,
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _headerProfileAndNotificationChildren(),
    );
  }

  Widget _buildCrApprovalRemindersBanner() {
    return _glassDashboardSection(
      blur: 8,
      solidTint: FlownetColors.surfaceLight.withValues(alpha: 0.48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.14),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 720;
          final row = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/icons/custom_bell.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.notifications_active,
                    color: FlownetColors.crimsonRed,
                    size: 60,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Approval Reminders',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: FlownetColors.pureWhite,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dream BIG, work hard and stay focused - make it a productive day!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FlownetColors.textSecondary,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
              if (!narrow) ...[
                const SizedBox(width: 8),
                _buildCrBannerActions(),
              ],
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row,
                const SizedBox(height: 10),
                _buildCrBannerActions(),
              ],
            );
          }
          return row;
        },
      ),
    );
  }

  Widget _buildCrBannerActions() {
    Widget btn(String label, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: FlownetColors.crimsonRed,
            foregroundColor: FlownetColors.pureWhite,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          child: Text(label),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 0,
      runSpacing: 8,
      children: [
        btn('SEND REMINDER', () => context.push('/send-reminder')),
        btn('TRIGGER ESCALATION', _triggerEscalation),
        btn(
          'DELIVERABLES OVERVIEW',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DeliverablesMetricsScreen(),
            ),
          ),
        ),
      ],
    );
  }

  static const String _crMetricBlurb =
      'Additional description information to include.';

  Widget _buildCrReviewMetricsRow() {
    if (_isLoadingClientMetrics) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final m = _clientReviewMetrics;
    final tiles = <_CrMetricSpec>[
      _CrMetricSpec(
        'Submitted',
        '${m['submitted'] ?? 0}',
        'assets/icons/review_metrics_submitted.png',
      ),
      _CrMetricSpec(
        'Approved',
        '${m['approved'] ?? 0}',
        'assets/icons/review_metrics_approved.png',
      ),
      _CrMetricSpec(
        'Changes Requested',
        '${m['changes'] ?? 0}',
        'assets/icons/review_metrics_changes_requested.png',
      ),
      _CrMetricSpec(
        'Rejected',
        '${m['rejected'] ?? 0}',
        'assets/icons/review_metrics_rejected.png',
      ),
      _CrMetricSpec(
        'Average Review Time',
        m['avg_review_time'] is String
            ? (m['avg_review_time'] as String)
            : (m['avg_review_time']?.toString() ?? '—'),
        'assets/icons/review_metrics_avg_review_time.png',
      ),
    ];
    return SizedBox(
      height: 118,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _buildCrMetricCard(tiles[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildCrMetricCard(_CrMetricSpec spec) {
    return _glassDashboardSection(
      blur: 8,
      solidTint: FlownetColors.surfaceLight.withValues(alpha: 0.45),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: FlownetColors.pureWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _crMetricBlurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: FlownetColors.textTertiary,
                      fontSize: 9,
                      height: 1.2,
                    ),
              ),
              const Spacer(),
              Text(
                spec.valueText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: FlownetColors.pureWhite,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Image.asset(
              spec.imageAsset,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(width: 40, height: 40);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _crFilteredPending() {
    if (_crPendingTab == 'all') return _pendingReports;
    return _pendingReports.where((r) {
      final p = (r['priority'] ?? r['Priority'] ?? 'medium').toString().toLowerCase();
      switch (_crPendingTab) {
        case 'high':
          return p == 'high';
        case 'medium':
          return p == 'medium';
        case 'low':
          return p == 'low';
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildCrFourPanelGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(child: _buildCrPendingApprovalsPanel()),
              const SizedBox(height: 12),
              Expanded(child: _buildCrRecentSubmissionsPanel()),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _buildCrProjectsOverviewPanel()),
              const SizedBox(height: 12),
              Expanded(child: _buildCrReviewHistoryPanel()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrPanelShell({
    required Widget header,
    required Widget child,
  }) {
    return _glassDashboardSection(
      blur: 8,
      solidTint: FlownetColors.surfaceLight.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildCrPanelHeader({
    IconData? leadingIcon,
    String? leadingImageAsset,
    double leadingImageWidth = 22,
    double leadingImageHeight = 22,
    required String title,
    required int badgeCount,
    String? route,
  }) {
    assert(
      leadingIcon != null || leadingImageAsset != null,
      'Provide leadingIcon or leadingImageAsset',
    );
    final Widget leading = leadingImageAsset != null
        ? Image.asset(
            leadingImageAsset,
            width: leadingImageWidth,
            height: leadingImageHeight,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                leadingIcon ?? Icons.warning_amber_rounded,
                color: FlownetColors.crimsonRed,
                size: 22,
              );
            },
          )
        : Icon(
            leadingIcon!,
            color: FlownetColors.crimsonRed,
            size: 22,
          );
    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: FlownetColors.pureWhite,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              AppIcons.smallBellAsset,
              width: 35,
              height: 35,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.notifications_none_rounded,
                  color: FlownetColors.textSecondary,
                  size: 35,
                );
              },
            ),
            if (badgeCount > 0)
              Positioned(
                right: -4,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: FlownetColors.crimsonRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
    if (route == null) return titleRow;
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(8),
      child: titleRow,
    );
  }

  Widget _buildCrPendingApprovalsPanel() {
    final list = _crFilteredPending();
    return _buildCrPanelShell(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCrPanelHeader(
            leadingImageAsset: 'assets/icons/pending_approvals.png',
            leadingImageWidth: 40,
            leadingImageHeight: 40,
            title: 'Pending Approvals',
            badgeCount: _pendingReports.length,
            route: '/report-repository',
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _crPriorityTab('all', 'VIEW ALL', filled: _crPendingTab == 'all'),
                _crPriorityTab('high', 'HIGH PRIORITY', filled: _crPendingTab == 'high'),
                _crPriorityTab('medium', 'MEDIUM PRIORITY',
                    filled: _crPendingTab == 'medium'),
                _crPriorityTab('low', 'LOW PRIORITY', filled: _crPendingTab == 'low'),
              ],
            ),
          ),
        ],
      ),
      child: _isLoadingPendingReports
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _pendingReportsError != null
              ? Center(
                  child: Text(
                    _pendingReportsError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                )
              : list.isEmpty
                  ? Center(
                      child: Text(
                        'No pending approvals',
                        style: TextStyle(color: FlownetColors.textTertiary, fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: list.length.clamp(0, 6),
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x22FFFFFF)),
                      itemBuilder: (context, index) {
                        final r = list[index];
                        final title = (r['reportTitle'] ??
                                r['report_title'] ??
                                (r['content'] is Map
                                    ? (r['content']['reportTitle'] ?? r['content']['title'])
                                    : null) ??
                                r['title'] ??
                                'Document Name - Draft Description')
                            .toString();
                        final id = (r['id'] ?? r['report_id'] ?? '').toString();
                        final created =
                            (r['created_at'] ?? r['createdAt'] ?? r['created'] ?? '').toString();
                        final dateLabel = _formatCrShortDate(created);
                        final priority =
                            (r['priority'] ?? r['Priority'] ?? 'medium').toString();
                        final checked = _crCheckedReportIds.contains(id);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                child: Checkbox(
                                  value: checked,
                                  activeColor: FlownetColors.crimsonRed,
                                  side: const BorderSide(color: FlownetColors.textTertiary),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: id.isEmpty
                                      ? null
                                      : (v) {
                                          setState(() {
                                            if (v == true) {
                                              _crCheckedReportIds.add(id);
                                            } else {
                                              _crCheckedReportIds.remove(id);
                                            }
                                          });
                                        },
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: id.isEmpty
                                      ? null
                                      : () => context.go('/client-review/$id'),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: FlownetColors.pureWhite,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateLabel,
                                        style: TextStyle(
                                          color: FlownetColors.textTertiary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _crPriorityPill(priority),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: id.isEmpty
                                            ? null
                                            : () => context.go('/client-review/$id'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: FlownetColors.textSecondary,
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('EDIT', style: TextStyle(fontSize: 11)),
                                      ),
                                      FilledButton(
                                        onPressed: id.isEmpty ? null : () => _approveReport(id),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: FlownetColors.crimsonRed,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('COMPLETE', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _crPriorityTab(String id, String label, {required bool filled}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _crPendingTab = id),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: filled ? FlownetColors.crimsonRed : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FlownetColors.crimsonRed, width: 1.2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? FlownetColors.pureWhite : FlownetColors.crimsonRed,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _crPriorityPill(String raw) {
    final p = raw.toLowerCase();
    String label;
    Color bg;
    Color fg;
    if (p == 'high') {
      label = 'High Priority';
      bg = const Color(0xFF1E3A5F);
      fg = const Color(0xFF5AC8FA);
    } else if (p == 'low') {
      label = 'Low Priority';
      bg = const Color(0xFF1B3D2A);
      fg = FlownetColors.emeraldGreen;
    } else {
      label = 'Medium Priority';
      bg = const Color(0xFF3D2E1A);
      fg = FlownetColors.amberOrange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatCrShortDate(String raw) {
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = (d.year % 100).toString().padLeft(2, '0');
    return '$dd-$mm-$yy';
  }

  Widget _buildCrProjectsOverviewPanel() {
    return _buildCrPanelShell(
      header: _buildCrPanelHeader(
        leadingIcon: Icons.folder_special_outlined,
        leadingImageAsset: 'assets/icons/projects_overview.png',
        leadingImageWidth: 40,
        leadingImageHeight: 40,
        title: 'Projects Overview',
        badgeCount: _dashboardProjects.length,
        route: '/projects',
      ),
      child: _isLoadingDashboardProjects
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _dashboardProjects.isEmpty
              ? Center(
                  child: Text(
                    'No projects yet',
                    style: TextStyle(color: FlownetColors.textTertiary, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _dashboardProjects.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = _dashboardProjects[i];
                    final title = p['name'] ?? 'Sample Project';
                    final id = p['id']?.toString() ?? '';
                    return InkWell(
                      onTap: id.isEmpty ? null : () => context.go('/project-workspace/$id'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: FlownetColors.crimsonRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Project Name: $title',
                              style: const TextStyle(
                                color: FlownetColors.pureWhite,
                                fontSize: 12,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildCrRecentSubmissionsPanel() {
    return _buildCrPanelShell(
      header: _buildCrPanelHeader(
        leadingIcon: Icons.send_rounded,
        leadingImageAsset: 'assets/icons/recent_submissions.png',
        leadingImageWidth: 40,
        leadingImageHeight: 40,
        title: 'Recent Submissions',
        badgeCount: _pendingReports.length,
        route: '/report-repository',
      ),
      child: _isLoadingPendingReports
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _pendingReports.isEmpty
              ? Center(
                  child: Text(
                    'No recent submissions',
                    style: TextStyle(color: FlownetColors.textTertiary, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _pendingReports.take(4).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = _pendingReports[i];
                    final title = (r['reportTitle'] ??
                            r['report_title'] ??
                            'Document Name - Draft Description')
                        .toString();
                    final created =
                        (r['created_at'] ?? r['createdAt'] ?? '').toString();
                    final id = (r['id'] ?? r['report_id'] ?? '').toString();
                    return InkWell(
                      onTap: id.isEmpty ? null : () => context.go('/client-review/$id'),
                      child: Row(
                        children: [
                          Icon(Icons.article_outlined,
                              size: 18, color: FlownetColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              created.isNotEmpty
                                  ? '$title • ${_formatCrShortDate(created)}'
                                  : title,
                              style: const TextStyle(fontSize: 12, color: FlownetColors.pureWhite),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildCrReviewHistoryPanel() {
    return _buildCrPanelShell(
      header: _buildCrPanelHeader(
        leadingIcon: Icons.fact_check_outlined,
        leadingImageAsset: 'assets/icons/recent_history.png',
        leadingImageWidth: 40,
        leadingImageHeight: 40,
        title: 'Review History',
        badgeCount: _filteredAuditLogs.length,
        route: '/report-repository',
      ),
      child: _isLoadingAuditLogs
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _auditLogsError != null
              ? Center(
                  child: Text(
                    _auditLogsError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                )
              : _filteredAuditLogs.isEmpty
                  ? Center(
                      child: Text(
                        'No history yet',
                        style: TextStyle(color: FlownetColors.textTertiary, fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _filteredAuditLogs.take(4).length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final a = _filteredAuditLogs[i];
                        final action = a['action'] ?? a['event'] ?? a['type'] ?? 'Review';
                        final actor = a['actor'] ?? a['user'] ?? '';
                        return InkWell(
                          onTap: () => context.go('/report-repository'),
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded,
                                  size: 18, color: FlownetColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  actor.toString().isNotEmpty
                                      ? '$action • $actor'
                                      : '$action',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: FlownetColors.pureWhite,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildSystemAdminDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: _dashOuterPadding,
        vertical: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: _dashSectionGap),
          _buildAdminFeatures(),
          const SizedBox(height: _dashSectionGap),
          _buildProjectsOverview(),
          const SizedBox(height: _dashSectionGap),
          _buildReminderQuickActions(),
        ],
      ),
    );
  }

  Widget _buildReminderQuickActions() {
    final canShow = _currentUser != null &&
        (_currentUser!.isDeliveryLead || _currentUser!.isSystemAdmin);
    if (!canShow) return const SizedBox.shrink();
    return _glassDashboardSection(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.notifications_active, 'Approval Reminders',
              route: '/approval-requests'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildActionButton(
                icon: Icons.assignment,
                label: 'Send Reminder',
                onTap: () => context.push('/send-reminder'),
              ),
              _buildActionButton(
                icon: Icons.trending_up,
                label: 'Trigger Escalation',
                onTap: _triggerEscalation,
              ),
              _buildActionButton(
                icon: Icons.analytics_outlined,
                label: 'Deliverables Overview',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          const DeliverablesMetricsScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildWelcomeCard() {
    return _glassDashboardSection(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        iconColor: FlownetColors.pureWhite,
        textColor: FlownetColors.pureWhite,
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
        title: Text(
          'Welcome, ${_currentUser?.name ?? 'User'}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: FlownetColors.pureWhite,
          ),
        ),
        subtitle: Text(
          '${_currentUser?.roleDisplayName ?? 'Member'} Dashboard',
          style: TextStyle(
            color: FlownetColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
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

  Widget _buildQuickActions() {
    final canCreate = _authService.canCreateDeliverable();
    final tiles = <Widget>[
      Expanded(
        child: _glassDashboardSection(
          padding: const EdgeInsets.all(14),
          child: _buildActionButton(
            icon: Icons.folder_outlined,
            label: 'View Projects',
            onTap: () => context.go('/projects'),
          ),
        ),
      ),
      Expanded(
        child: _glassDashboardSection(
          padding: const EdgeInsets.all(14),
          child: _buildActionButton(
            icon: Icons.assignment_outlined,
            label: 'View Deliverables',
            onTap: () => context.go('/deliverables'),
          ),
        ),
      ),
    ];

    if (canCreate) {
      tiles.insert(
        0,
        Expanded(
          child: _glassDashboardSection(
            padding: const EdgeInsets.all(14),
            child: _buildActionButton(
              icon: Icons.assignment_add,
              label: 'Create Deliverable',
              onTap: () => context.go('/deliverable-setup'),
            ),
          ),
        ),
      );
      tiles.add(
        Expanded(
          child: _glassDashboardSection(
            padding: const EdgeInsets.all(14),
            child: _buildActionButton(
              icon: Icons.description_outlined,
              label: 'Build Report',
              onTap: () {
                final first =
                    _dashboardDeliverables.isNotEmpty ? _dashboardDeliverables.first : null;
                final id = first != null
                    ? (first['id']?.toString() ?? first['uuid']?.toString() ?? '')
                    : '';
                if (id.isNotEmpty) context.go('/report-builder/$id');
              },
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        for (int i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          tiles[i],
        ]
      ],
    );
  }

  Widget _buildMyDeliverables() {
    return _glassDashboardSection(
      child: _isLoadingDashboardDeliverables
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(Icons.assignment_outlined, 'My Deliverables',
                    route: '/deliverables'),
                const SizedBox(height: 10),
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
                                            context.go('/report-builder/$id'),
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
    );
  }

  Widget _buildDeliverablesOverview() {
    // Filter out completed deliverables for the overview
    final overviewDeliverables = _dashboardDeliverables.where((d) {
      final status =
          (d['status'] ?? d['reviewStatus'] ?? '').toString().toLowerCase();
      return status != 'completed';
    }).toList();

    return _glassDashboardSection(
      child: _isLoadingDashboardDeliverables
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(Icons.assignment_outlined,
                    'Deliverables Overview (${overviewDeliverables.length})',
                    route: '/deliverables'),
                const SizedBox(height: 10),
                  if (overviewDeliverables.isEmpty)
                    const Text('No active deliverables'),
                  ...overviewDeliverables.take(6).map((d) {
                    final title = d['title'] ??
                        d['name'] ??
                        d['deliverableName'] ??
                        'Untitled Deliverable';
                    final status =
                        (d['status'] ?? d['reviewStatus'] ?? '').toString();
                    final id =
                        (d['id']?.toString() ?? d['uuid']?.toString() ?? '');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.assignment_outlined, size: 18),
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
                              _priorityChip((d['priority'] ?? '').toString()),
                              _dueDateChip(d['due_date'] ??
                                  d['dueDate'] ??
                                  d['deadline']),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: id.isEmpty
                                    ? null
                                    : () => _editDeliverable(d),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Edit'),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: id.isEmpty
                                    ? null
                                    : () => _updateDeliverableStatus(
                                        id, 'completed'),
                                icon: const Icon(Icons.check_circle_outline,
                                    size: 18),
                                label: const Text('Complete'),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () {
                                  final route = id.isNotEmpty
                                      ? '/report-editor/$id'
                                      : '/deliverables';
                                  context.go(route);
                                },
                                icon: const Icon(Icons.open_in_new),
                                tooltip: 'Open',
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
    );
  }

  Widget _buildRecentActivity() {
    return _glassDashboardSection(
      child: _isLoadingAuditLogs
            ? const Center(child: CircularProgressIndicator())
            : (_auditLogsError != null
                ? Text(_auditLogsError!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardHeader(Icons.history, 'Recent Activity',
                          route: '/notifications'),
                      const SizedBox(height: 10),
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
    );
  }

  Widget _buildTeamMetrics() {
    return _glassDashboardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.group_outlined, 'Team Metrics',
              route: '/sprint-console'),
          const SizedBox(height: 12),
          if (_isLoadingTeamMetrics)
              const Center(child: CircularProgressIndicator())
            else if (_teamMetrics.isEmpty)
              const Text('No team data available')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metricTile('Deliverables', _teamMetrics['deliverables'] ?? 0,
                      Icons.assignment_outlined, Colors.blue),
                  _metricTile('In Progress', _teamMetrics['in_progress'] ?? 0,
                      Icons.play_circle_outline, Colors.orange),
                  _metricTile('Completed', _teamMetrics['completed'] ?? 0,
                      Icons.check_circle_outline, Colors.green),
                  _metricTile('Overdue', _teamMetrics['overdue'] ?? 0,
                      Icons.warning_amber_outlined, Colors.red),
                  _metricTile(
                      'Active Sprints',
                      _teamMetrics['active_sprints'] ?? 0,
                      Icons.flag_outlined,
                      Colors.purple),
                  _metricTile(
                      'Active Projects',
                      _teamMetrics['active_projects'] ?? 0,
                      Icons.folder_open_outlined,
                      Colors.indigo),
                  _metricTile(
                      'Pending Reviews',
                      _teamMetrics['pending_reviews'] ?? 0,
                      Icons.rule_folder_outlined,
                      Colors.blueGrey),
                  _metricTile(
                      'Completion Rate',
                      _teamMetrics['completion_rate'] ?? '-',
                      Icons.pie_chart_outline,
                      Colors.teal),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildSprintOverview() {
    return _glassDashboardSection(
      child: _isLoadingDashboardSprints
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(Icons.flag_outlined,
                    'Sprint Overview (${_dashboardSprints.length})',
                    route: '/sprint-console'),
                const SizedBox(height: 10),
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
    );
  }

  Widget _buildTeamPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _glassDashboardSection(
          child: Row(
            children: [
              Expanded(
                  child: _buildCardHeader(
                      Icons.insights_outlined, 'Team Performance',
                      route: '/sprint-console')),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedChartType,
                items: const [
                  DropdownMenuItem(
                      value: 'velocity', child: Text('Velocity')),
                  DropdownMenuItem(
                      value: 'burndown', child: Text('Burndown')),
                  DropdownMenuItem(value: 'burnup', child: Text('Burnup')),
                  DropdownMenuItem(value: 'defects', child: Text('Defects')),
                  DropdownMenuItem(
                      value: 'test_pass_rate', child: Text('Test Pass Rate')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedChartType = v;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SprintPerformanceChart(
            sprints: _dashboardSprints, chartType: _selectedChartType),
        const SizedBox(height: 12),
        _teamPerformanceSummary(),
      ],
    );
  }

  Widget _buildReviewMetrics() {
    return _glassDashboardSection(
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
    );
  }

  Widget _buildProjectsOverview() {
    if (_isLoadingDashboardProjects) {
      return const Center(child: CircularProgressIndicator());
    }
    final now = DateTime.now();
    final overdueProjects = _dashboardProjects.where((p) {
      try {
        final status = (p['status'] ?? '').toString().toLowerCase();
        if (status == 'completed' || status == 'cancelled') {
          return false;
        }
        final endStr = p['end_date']?.toString() ?? p['endDate']?.toString() ?? '';
        if (endStr.isEmpty) return false;
        final end = DateTime.parse(endStr);
        return now.isAfter(end);
      } catch (_) {
        return false;
      }
    }).toList();

    return _glassDashboardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.folder_outlined,
              'Projects Overview (${_dashboardProjects.length})',
              route: null),
          const SizedBox(height: 10),
          if (_dashboardProjects.isEmpty) const Text('No active projects'),
            ..._dashboardProjects.take(3).map((p) {
              final title = p['name'] ?? 'Untitled Project';
              final status = (p['status'] ?? '').toString();
              final id = p['id']?.toString() ?? '';
              final isOverdue = overdueProjects.any((op) => op['id'] == p['id']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: InkWell(
                  onTap: id.isNotEmpty
                      ? () => context.go('/project-workspace/$id')
                      : null,
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 18,
                        color: isOverdue ? Colors.redAccent : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              status.isNotEmpty ? '$title • $status' : title)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPendingReviews() {
    return _buildPendingApprovals();
  }

  Widget _buildPendingApprovals() {
    return _glassDashboardSection(
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
                    const SizedBox(height: 10),
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
    );
  }

  Widget _buildRecentSubmissions() {
    return _glassDashboardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.upload_outlined, 'Recent Submissions',
              route: '/report-repository'),
          const SizedBox(height: 10),
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
    );
  }

  Widget _buildReviewHistory() {
    return _glassDashboardSection(
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
                    const SizedBox(height: 10),
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
    );
  }

  Widget _metricTile(String label, dynamic value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FlownetColors.textSecondary,
                    ),
              ),
              Text(
                value is String ? value : value.toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: FlownetColors.pureWhite,
                      fontWeight: FontWeight.w600,
                    ),
              ),
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
      _computeTeamMetrics();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  void _computeTeamMetrics() {
    if (!mounted) return;
    setState(() => _isLoadingTeamMetrics = true);
    try {
      final int totalDeliverables = _dashboardDeliverables.length;
      int completed = 0;
      int inProgress = 0;
      int overdue = 0;
      for (final d in _dashboardDeliverables) {
        final status =
            (d['status'] ?? d['state'] ?? '').toString().toLowerCase();
        if (status == 'completed' || status == 'done' || status == 'approved') {
          completed++;
        }
        if (status == 'in_progress' ||
            status == 'in-progress' ||
            status == 'progress') {
          inProgress++;
        }
        final dueStr =
            (d['due_date'] ?? d['dueDate'] ?? d['deadline'] ?? '').toString();
        final due = DateTime.tryParse(dueStr);
        if (due != null &&
            due.isBefore(DateTime.now()) &&
            status != 'completed' &&
            status != 'done' &&
            status != 'approved') {
          overdue++;
        }
      }
      int activeSprints = 0;
      for (final s in _dashboardSprints) {
        final status =
            (s['status'] ?? s['state'] ?? '').toString().toLowerCase();
        if (status == 'active' ||
            status == 'in_progress' ||
            status == 'in-progress') {
          activeSprints++;
        }
      }
      int activeProjects = 0;
      for (final p in _dashboardProjects) {
        final status = (p['status'] ?? '').toString().toLowerCase();
        if (status != 'completed' && status != 'archived') activeProjects++;
      }
      final pendingReviews = _pendingReports.length;
      String completionRateStr;
      if (totalDeliverables > 0) {
        final rate = (completed / totalDeliverables * 100).toStringAsFixed(1);
        completionRateStr = '$rate%';
      } else {
        completionRateStr = '-';
      }
      final m = <String, dynamic>{
        'deliverables': totalDeliverables,
        'completed': completed,
        'in_progress': inProgress,
        'overdue': overdue,
        'active_sprints': activeSprints,
        'active_projects': activeProjects,
        'pending_reviews': pendingReviews,
        'completion_rate': completionRateStr,
      };
      if (mounted) {
        setState(() {
          _teamMetrics = m;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _teamMetrics = {});
    } finally {
      if (mounted) setState(() => _isLoadingTeamMetrics = false);
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
        _computeTeamMetrics();
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
    setState(() {});
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
      setState(() {
        _clientReviewMetrics = {};
      });
    } finally {
      if (mounted) setState(() => _isLoadingClientMetrics = false);
    }
  }

  Widget _teamPerformanceSummary() {
    double planned = 0;
    double completed = 0;
    double defects = 0;
    for (final s in _dashboardSprints) {
      final p = s['planned_points'] ?? s['planned'] ?? 0;
      final c = s['completed_points'] ?? s['completed'] ?? 0;
      final d = s['defects_opened'] ?? s['defect_count'] ?? 0;
      planned += (p is num) ? p.toDouble() : double.tryParse(p.toString()) ?? 0;
      completed +=
          (c is num) ? c.toDouble() : double.tryParse(c.toString()) ?? 0;
      defects += (d is num) ? d.toDouble() : double.tryParse(d.toString()) ?? 0;
    }
    final avgVelocity = _dashboardSprints.isNotEmpty
        ? (completed / _dashboardSprints.length)
        : 0;
    final carryover = planned - completed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metricTile('Avg Velocity', avgVelocity.toStringAsFixed(1),
              Icons.speed, Colors.blue),
          _metricTile('Planned', planned.toStringAsFixed(1), Icons.trending_up,
              Colors.orange),
          _metricTile('Completed', completed.toStringAsFixed(1),
              Icons.check_circle_outline, Colors.green),
          _metricTile('Carryover', carryover.toStringAsFixed(1),
              Icons.sync_problem, Colors.red),
          _metricTile('Defects', defects.toStringAsFixed(0), Icons.bug_report,
              Colors.purple),
        ],
      ),
    );
  }

  Widget _buildAdminFeatures() {
    return _glassDashboardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.settings_applications, 'Admin Features',
              route: '/settings'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _featureTile(Icons.dashboard_outlined, 'System Metrics',
                  () => context.go('/system-metrics')),
              _featureTile(Icons.security, 'Role Management',
                  () => context.go('/role-management')),
              _featureTile(Icons.health_and_safety, 'System Health',
                  () => context.go('/system-health')),
              _featureTile(Icons.receipt_long, 'Audit Logs',
                  () => context.go('/audit-logs')),
              _featureTile(Icons.assignment, 'Deliverables Overview',
                  () => context.go('/deliverables-overview')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Future<void> _approveReport(String reportId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final resp = await _reportService.approveReport(reportId);
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
      final resp = await _reportService.requestChanges(reportId, details);
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
                border: OutlineInputBorder(), labelText: 'Details'),
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
    if (confirmed == true && details.trim().isNotEmpty) {
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
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(
        icon,
        size: 20,
        color: _currentUser?.isSystemAdmin == true
            ? Theme.of(context).colorScheme.primary
            : FlownetColors.pureWhite,
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildCardHeader(IconData icon, String label, {String? route}) {
    final iconColor = _currentUser?.isSystemAdmin == true
        ? Theme.of(context).colorScheme.secondary
        : FlownetColors.crimsonRed;
    final row = Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: FlownetColors.pureWhite,
                  height: 1.2,
                ),
          ),
        ),
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

  void _handleRoleChanged(dynamic _) {
    _loadCurrentUser();
  }

  Widget _buildKanbanLinkCard() {
    return InkWell(
      onTap: () => context.push('/deliverables-overview'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.view_kanban,
                  color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deliverables Board',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Track progress and manage status',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }
}

class _CrMetricSpec {
  final String title;
  final String valueText;
  /// Review Metrics Overview badge art (red circle assets include their own background).
  final String imageAsset;
  const _CrMetricSpec(this.title, this.valueText, this.imageAsset);
}
