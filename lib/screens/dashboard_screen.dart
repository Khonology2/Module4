import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/deliverable.dart';
import '../widgets/deliverable_card.dart';
import '../widgets/metrics_card.dart';
import '../widgets/sprint_performance_chart.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/notification_center_widget.dart';
import '../services/backend_api_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../utils/app_icons.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardNotifierProvider.notifier).loadDashboardData();
      _loadCurrentUser();
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      debugPrint('=== Loading current user for dashboard ===');
      final user = AuthService().currentUser;
      debugPrint(
          'AuthService().currentUser: ${user?.name}, role: ${user?.role.displayName}');

      if (user != null) {
        setState(() {
          _currentUser = user;
        });
        debugPrint(
            '✅ User loaded successfully: ${user.name}, Role: ${user.role.displayName}');
      } else {
        debugPrint('❌ User is null, attempting to refresh...');
        // Try to refresh the user
        await AuthService().refreshCurrentUser();
        final refreshedUser = AuthService().currentUser;
        debugPrint(
            'After refresh - user: ${refreshedUser?.name}, role: ${refreshedUser?.role.displayName}');

        if (refreshedUser != null) {
          setState(() {
            _currentUser = refreshedUser;
          });
          debugPrint(
              '✅ User refreshed successfully: ${refreshedUser.name}, Role: ${refreshedUser.role.displayName}');
        } else {
          debugPrint('❌ Failed to load user after refresh');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading current user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardNotifierProvider);
    final canCreate = AuthService().canCreateDeliverable();
    debugPrint(
        '🏗️ Building dashboard - _currentUser: ${_currentUser?.name}, title: ${_currentUser != null ? '${_currentUser!.role.displayName} Dashboard' : 'Flow-Space Dashboard'}');

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentUser != null
            ? '${_currentUser!.role.displayName} Dashboard'
            : 'Flow-Space Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add_task),
              onPressed: () => context.go('/deliverable-setup'),
              tooltip: 'Create Deliverable',
            ),
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: () => context.go('/projects'),
            tooltip: 'Projects',
          ),
          const NotificationCenterWidget(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              _showSettingsDialog();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    AppIcons.getIconWidget(
                      'logout',
                      fallbackIcon: Icons.logout,
                      isActive: true,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text('Logout'),
                  ],
                ),
              ),
            ],
            child: AppIcons.accountProfileBadge(size: 28),
          ),
        ],
      ),
      body: dashboardState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : dashboardState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dashboardState.error!,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref
                              .read(dashboardNotifierProvider.notifier)
                              .loadDashboardData();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(),
                      const SizedBox(height: 24),
                      _buildMetricsRow(dashboardState),
                      const SizedBox(height: 24),
                      _buildSprintPerformanceSection(dashboardState),
                      const SizedBox(height: 24),
                      _buildDeliverablesSection(dashboardState),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(
                Icons.dashboard,
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Khonology',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deliverable & Sprint Sign-Off Hub',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track deliverables, monitor sprint performance, and manage client approvals',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(DashboardState dashboardState) {
    final totalDeliverables = dashboardState.deliverables.length;
    final approvedDeliverables = dashboardState.deliverables
        .where((d) => d.status == DeliverableStatus.approved)
        .length;
    final pendingDeliverables = dashboardState.deliverables
        .where((d) => d.status == DeliverableStatus.submitted)
        .length;

    return Row(
      children: [
        Expanded(
          child: MetricsCard(
            title: 'Total Deliverables',
            value: totalDeliverables.toString(),
            icon: Icons.assignment,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricsCard(
            title: 'Approved',
            value: approvedDeliverables.toString(),
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricsCard(
            title: 'Pending Review',
            value: pendingDeliverables.toString(),
            icon: Icons.pending,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: MetricsCard(
            title: 'Avg. Sign-off',
            value: '2.3d',
            icon: Icons.schedule,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildSprintPerformanceSection(DashboardState dashboardState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sprint Performance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        context.go('/projects');
                      },
                      icon: const Icon(Icons.folder),
                      label: const Text('View Projects'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.analytics),
                      onPressed: () {
                        context.go('/performance-dashboard');
                      },
                      tooltip: 'Performance Dashboard',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SprintPerformanceChart(
                sprints: dashboardState.sprints.map((sprint) {
                  return {
                    'id': sprint.id,
                    'name': sprint.name,
                    'start_date': sprint.startDate.toIso8601String(),
                    'end_date': sprint.endDate.toIso8601String(),
                    'planned_points': sprint.committedPoints,
                    'completed_points': sprint.completedPoints,
                    'status': 'completed',
                  };
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverablesSection(DashboardState dashboardState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Deliverables',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton.icon(
              onPressed: () {
                _showAllDeliverablesDialog();
              },
              icon: const Icon(Icons.list),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (dashboardState.deliverables.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.assignment, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No deliverables yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first deliverable to get started',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...dashboardState.deliverables.take(5).map(
                (deliverable) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DeliverableCard(
                    deliverable: deliverable,
                    onTap: () {
                      _showDeliverableDetailsDialog(deliverable);
                    },
                  ),
                ),
              ),
      ],
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content:
            const Text('Settings panel will be implemented in the next phase.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAllDeliverablesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Deliverables'),
        content: const Text(
            'Complete deliverables list will be implemented in the next phase.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeliverableDetailsDialog(Deliverable deliverable) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(deliverable.title),
        content: Text(deliverable.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Call backend logout API and clear local tokens
              try {
                await BackendApiService().signOut();
              } catch (e) {
                // Even if backend logout fails, clear local tokens
                debugPrint('Logout error: $e');
              }

              // Navigate to login screen using a different approach
              if (mounted) {
                // Use WidgetsBinding to safely navigate after async operation
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    GoRouter.of(context).go('/');
                  }
                });
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
