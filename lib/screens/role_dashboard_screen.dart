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
import '../widgets/app_modal.dart';
import '../utils/date_utils.dart' as app_date_utils;
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
  Future<void> _preloadUserNames(
      List<Map<String, dynamic>> deliverables) async {
    final Set<String> userIds = {};

    for (final deliverable in deliverables) {
      final ownerId = _getOwnerId(deliverable);
      final assignedToId = deliverable['assigned_to']?.toString() ??
          deliverable['assignedTo']?.toString();

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
    if (data['created_by_name'] != null) {
      return data['created_by_name'].toString();
    }

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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  const SizedBox(
                      width: 48), // Space for hamburger menu alignment
                  Expanded(
                    child: Text(
                      '${_currentUser!.role.displayName} Dashboard',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) => PopupMenuButton<String>(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onSelected: (value) {
                        switch (value) {
                          case 'profile':
                            context.go('/profile');
                            break;
                          case 'notifications':
                            context.go('/notifications');
                            break;
                          case 'settings':
                            context.go('/settings');
                            break;
                          case 'logout':
                            _handleLogout();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(Icons.person),
                              SizedBox(width: 8),
                              Text('Profile'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'notifications',
                          child: Row(
                            children: [
                              Icon(Icons.notifications),
                              SizedBox(width: 8),
                              Text('Notifications'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings),
                              SizedBox(width: 8),
                              Text('Settings'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout),
                              SizedBox(width: 8),
                              Text('Logout'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: _buildRoleSpecificContent(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildRoleSpecificFAB(),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 24),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildKanbanLinkCard(),
          const SizedBox(height: 24),
          _buildMyDeliverables(),
          const SizedBox(height: 24),
          _buildReviewMetrics(),
          const SizedBox(height: 24),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildDeliveryLeadDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 24),
          _buildReminderQuickActions(),
          const SizedBox(height: 24),
          _buildTeamMetrics(),
          const SizedBox(height: 24),
          _buildReviewMetrics(),
          const SizedBox(height: 24),
          _buildSprintOverview(),
          const SizedBox(height: 24),
          _buildKanbanLinkCard(),
          const SizedBox(height: 24),
          _buildDeliverablesOverview(),
          const SizedBox(height: 24),
          _buildProjectsOverview(),
          const SizedBox(height: 24),
          _buildPendingReviews(),
          const SizedBox(height: 24),
          _buildTeamPerformance(),
        ],
      ),
    );
  }

  Widget _buildClientReviewerDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 24),
          _buildReviewMetrics(),
          const SizedBox(height: 24),
          _buildPendingApprovals(),
          const SizedBox(height: 24),
          _buildRecentSubmissions(),
          const SizedBox(height: 24),
          _buildReviewHistory(),
        ],
      ),
    );
  }

  Widget _buildSystemAdminDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 24),
          _buildAdminFeatures(),
          const SizedBox(height: 24),
          _buildProjectsOverview(),
          const SizedBox(height: 24),
          _buildReminderQuickActions(),
        ],
      ),
    );
  }

  Widget _buildReminderQuickActions() {
    final canShow = _currentUser != null &&
        (_currentUser!.isDeliveryLead || _currentUser!.isSystemAdmin);
    if (!canShow) return const SizedBox.shrink();
    return Card(
      child: Padding(
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

  Widget? _buildRoleSpecificFAB() {
    final auth = AuthService();
    final canCreateDeliverable = auth.canCreateDeliverable();
    final canManageUsers = auth.canManageUsers();

    if (!canCreateDeliverable && !canManageUsers) return null;

    return FloatingActionButton(
      onPressed: () {
        if ((_currentUser!.role == UserRole.teamMember ||
                _currentUser!.role == UserRole.deliveryLead) &&
            canCreateDeliverable) {
          _showCreateDeliverableModal();
          return;
        }

        showAppModalBottomSheet(
          context: context,
          builder: (context) {
            final items = <Widget>[];

            if (canCreateDeliverable) {
              items.add(
                ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: const Text('Create Deliverable'),
                  onTap: () => context.go('/deliverable-setup'),
                ),
              );
            }

            if (canManageUsers) {
              items.add(
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Role Management'),
                  onTap: () => context.go('/role-management'),
                ),
              );
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items,
              ),
            );
          },
        );
      },
      backgroundColor:
          _currentUser?.roleColor ?? Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showCreateDeliverableModal() {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Deliverable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose the type of deliverable setup:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Quick Setup'),
              subtitle: const Text('Basic deliverable creation'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/deliverable-setup');
              },
            ),
            ListTile(
              leading: const Icon(Icons.engineering),
              title: const Text('Enhanced Setup'),
              subtitle: const Text('Full DoD, evidence, and readiness check'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/enhanced-deliverable-setup');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

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
                  final first = _dashboardDeliverables.isNotEmpty
                      ? _dashboardDeliverables.first
                      : null;
                  final sprintId =
                      first != null ? _extractFirstSprintId(first) : null;
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

  Widget _buildDeliverablesOverview() {
    // Filter out completed deliverables for the overview
    final overviewDeliverables = _dashboardDeliverables.where((d) {
      final status =
          (d['status'] ?? d['reviewStatus'] ?? '').toString().toLowerCase();
      return status != 'completed';
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoadingDashboardDeliverables
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader(Icons.assignment_outlined,
                      'Deliverables Overview (${overviewDeliverables.length})',
                      route: '/deliverables'),
                  const SizedBox(height: 8),
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
                                  if (id.isNotEmpty) {
                                    _openSprintReportForDeliverable(d);
                                    return;
                                  }
                                  context.go('/deliverables');
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
      ),
    );
  }

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

  Widget _buildTeamMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(Icons.group_outlined, 'Team Metrics', route: null),
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

  Widget _buildTeamPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                    child: _buildCardHeader(
                        Icons.insights_outlined, 'Team Performance',
                        route: null)),
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
        ),
        const SizedBox(height: 8),
        SprintPerformanceChart(
            sprints: _dashboardSprints, chartType: _selectedChartType),
        const SizedBox(height: 12),
        _teamPerformanceSummary(),
      ],
    );
  }

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
        final endStr =
            p['end_date']?.toString() ?? p['endDate']?.toString() ?? '';
        if (endStr.isEmpty) return false;
        final end = DateTime.parse(endStr);
        return now.isAfter(end);
      } catch (_) {
        return false;
      }
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(Icons.folder_outlined,
                'Projects Overview (${_dashboardProjects.length})',
                route: null),
            const SizedBox(height: 8),
            if (_dashboardProjects.isEmpty) const Text('No active projects'),
            ..._dashboardProjects.take(3).map((p) {
              final title = p['name'] ?? 'Untitled Project';
              final status = (p['status'] ?? '').toString();
              final id = p['id']?.toString() ?? '';
              final isOverdue =
                  overdueProjects.any((op) => op['id'] == p['id']);
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
      ),
    );
  }

  Widget _buildPendingReviews() {
    return _buildPendingApprovals();
  }

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
                        // Extract user information from content object if available
                        String createdBy = '';
                        String projectName = '';

                        // Check if content is a Map and extract user info
                        final content = r['content'];
                        if (content is Map<String, dynamic>) {
                          createdBy = (content['createdBy'] ??
                                  content['created_by_name'] ??
                                  content['created_by'] ??
                                  content['author'] ??
                                  content['author_name'] ??
                                  content['submitted_by'] ??
                                  content['submitter_name'] ??
                                  content['owner_name'] ??
                                  content['user_name'] ??
                                  content['name'] ??
                                  '')
                              .toString();

                          projectName = (content['projectName'] ??
                                  content['project_name'] ??
                                  content['project'] ??
                                  content['sprint_name'] ??
                                  content['sprintName'] ??
                                  '')
                              .toString();
                        }

                        // Fallback to root level fields if not found in content
                        if (createdBy.isEmpty) {
                          createdBy = (r['createdBy'] ??
                                  r['created_by_name'] ??
                                  r['created_by'] ??
                                  r['author'] ??
                                  r['author_name'] ??
                                  r['submitted_by'] ??
                                  r['submitter_name'] ??
                                  r['owner_name'] ??
                                  r['user_name'] ??
                                  r['name'] ??
                                  '')
                              .toString();
                        }

                        if (projectName.isEmpty) {
                          projectName = (r['projectName'] ??
                                  r['project_name'] ??
                                  r['project'] ??
                                  r['sprint_name'] ??
                                  r['sprintName'] ??
                                  '')
                              .toString();
                        }

                        final id = (r['id'] ?? r['report_id'] ?? '').toString();

                        // Create user-friendly display text
                        String displayText = title;
                        if (createdBy.isNotEmpty && projectName.isNotEmpty) {
                          displayText = '$title by $createdBy ($projectName)';
                        } else if (createdBy.isNotEmpty) {
                          displayText = '$title by $createdBy';
                        } else if (projectName.isNotEmpty) {
                          displayText = '$title ($projectName)';
                        } else {
                          // Only show ID as last resort with minimal format
                          displayText = title;
                        }

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
                                      Expanded(child: Text(displayText)),
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
                final ts = createdAtStr.isNotEmpty
                    ? app_date_utils.DateUtils
                        .formatDatabaseTimestampWithTime(createdAtStr)
                    : '';
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
      label = app_date_utils.DateUtils.formatTimestampWithTime(s);
      if (label == 'N/A') label = '';
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
          final label = snapshot.hasData ? snapshot.data! : 'Loading...';

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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

  void _handleLogout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        context.go('/');
      }
    }
  }
}
