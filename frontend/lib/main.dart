import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'widgets/app_container.dart';
import 'screens/welcome_screen.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/backend_api_service.dart';
import 'services/version_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/enhanced_deliverable_setup_screen.dart';
import 'screens/sprint_console_screen.dart';
import 'screens/sprint_metrics_screen.dart';
import 'screens/report_builder_screen.dart';
import 'screens/client_review_workflow_screen.dart';
import 'screens/report_editor_screen.dart';
import 'screens/report_view_screen.dart';
import 'screens/client_review_screen.dart';
import 'screens/sprint_report_screen.dart';
import 'models/sign_off_report.dart';
import 'models/deliverable.dart';
import 'screens/report_repository_screen.dart';
// Approvals unified: use ApprovalRequestsScreen
import 'screens/approval_requests_screen.dart';
import 'screens/repository_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/smtp_config_screen.dart';
import 'screens/send_reminder_screen.dart';
import 'screens/role_dashboard_screen.dart';
import 'screens/role_management_screen.dart';
// import 'screens/user_management_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sprint_board_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/system_metrics_screen.dart';
import 'screens/system_health_screen.dart';
import 'screens/projects_overview_screen.dart';
import 'screens/audit_logs_screen.dart';
import 'providers/service_providers.dart';
// Removed imports for non-existent screens to resolve analyzer errors
import 'widgets/sidebar_scaffold.dart';
//
import 'widgets/role_guard.dart';
import 'theme/flownet_theme.dart';
import 'screens/deadlines_screen.dart';
import 'screens/deliverables_list_screen.dart';
import 'screens/deliverables_overview_screen.dart';
import 'screens/skill_assessment_screen.dart';
import 'screens/deliverable_detail_screen.dart';
import 'screens/deliverable_detail_by_id_screen.dart';
import 'screens/environment_management_screen.dart';
import 'screens/project_workspace_screen.dart';
import 'screens/project_details_screen.dart';
import 'screens/ai_assistant_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    // Initialize API Services
    await BackendApiService().initialize();
    await AuthService().initialize();
    await VersionService.getVersionDetailsFromAsset(forceRefresh: true);
    // RealAuthService removed - using AuthService instead

    // Test SMTP connection on startup (optional)
    // Uncomment the lines below to test SMTP on app startup
    // final emailService = SmtpEmailService();
    // final isConnected = await emailService.testSmtpConnection();
    // debugPrint('SMTP Connection: ${isConnected ? "✅ Success" : "❌ Failed"}');
  } catch (e) {
    debugPrint('API Service initialization failed: $e');
    // Continue without API service for now
  }

  runApp(const ProviderScope(child: KhonoApp()));
}

class KhonoApp extends ConsumerWidget {
  const KhonoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    final lightTheme = FlownetTheme.lightTheme.copyWith(
      textTheme: FlownetTheme.lightTheme.textTheme.apply(fontFamily: 'Poppins'),
      primaryTextTheme:
          FlownetTheme.lightTheme.primaryTextTheme.apply(fontFamily: 'Poppins'),
    );
    final darkTheme = FlownetTheme.darkTheme.copyWith(
      textTheme: FlownetTheme.darkTheme.textTheme.apply(fontFamily: 'Poppins'),
      primaryTextTheme:
          FlownetTheme.darkTheme.primaryTextTheme.apply(fontFamily: 'Poppins'),
    );
    return MaterialApp.router(
      title: 'Flownet Workspaces - Project Management Hub',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return AppContainer(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    // Email verification via extra payload (used in-app)
    GoRoute(
      path: '/verify-email',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final email = extra?['email'] as String? ?? '';
        return EmailVerificationScreen(email: email);
      },
    ),
    // Email verification via direct URL (used from email links)
    GoRoute(
      path: '/email-verification',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        return EmailVerificationScreen(email: email);
      },
    ),
    GoRoute(
      path: '/verify-email/:code',
      builder: (context, state) {
        final code = state.pathParameters['code']!;
        final emailFromQuery = state.uri.queryParameters['email'] ?? '';
        return EmailVerificationScreen(
          email: emailFromQuery,
          verificationCode: code,
        );
      },
    ),
    GoRoute(
      path: '/email-verification/:code',
      builder: (context, state) {
        final code = state.pathParameters['code']!;
        final emailFromQuery = state.uri.queryParameters['email'] ?? '';
        return EmailVerificationScreen(
          email: emailFromQuery,
          verificationCode: code,
        );
      },
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const RoleGuard(
        requiredPermission: 'authenticated',
        child: SidebarScaffold(
          child: RoleDashboardScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/projects/create',
      builder: (context, state) => const RoleGuard(
        requiredPermission: 'manage_projects',
        child: SidebarScaffold(
          child: ProjectWorkspaceScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/projects/:projectId/details',
      builder: (context, state) {
        final projectId = state.pathParameters['projectId']!;
        return RoleGuard(
          requiredPermission: 'authenticated',
          child: SidebarScaffold(
            child: ProjectDetailsScreen(projectId: projectId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/projects/:projectId/edit',
      builder: (context, state) {
        final projectId = state.pathParameters['projectId']!;
        return RoleGuard(
          requiredPermission: 'manage_projects',
          child: SidebarScaffold(
            child: ProjectWorkspaceScreen(projectId: projectId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/project-setup',
      builder: (context, state) => const RoleGuard(
        requiredPermission: 'manage_projects',
        child: SidebarScaffold(
          child: ProjectWorkspaceScreen(projectId: 'new'),
        ),
      ),
    ),
    GoRoute(
      path: '/deliverable-setup',
      builder: (context, state) => const RouteGuard(
        route: '/deliverable-setup',
        child: SidebarScaffold(
          child: EnhancedDeliverableSetupScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/enhanced-deliverable-setup',
      builder: (context, state) => const RouteGuard(
        route: '/enhanced-deliverable-setup',
        child: SidebarScaffold(
          child: EnhancedDeliverableSetupScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/deliverable-detail',
      builder: (context, state) {
        final deliverable = state.extra as Deliverable;
        return RouteGuard(
          route: '/deliverable-detail',
          child: SidebarScaffold(
            child: DeliverableDetailScreen(deliverable: deliverable),
          ),
        );
      },
    ),
    GoRoute(
      path: '/sprint-metrics/:sprintId',
      builder: (context, state) {
        final sprintId = state.pathParameters['sprintId']!;
        return RouteGuard(
          route: '/sprint-metrics',
          child: SidebarScaffold(
            child: SprintMetricsScreen(sprintId: sprintId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/timeline',
      builder: (context, state) => const RouteGuard(
        route: '/timeline',
        child: SidebarScaffold(
          child: TimelineScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/ai-assistant',
      builder: (context, state) => const RouteGuard(
        route: '/ai-assistant',
        child: SidebarScaffold(
          child: AIAssistantScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/report-builder/:deliverableId',
      builder: (context, state) {
        final deliverableId = state.pathParameters['deliverableId']!;
        return RouteGuard(
          route: '/report-builder',
          child: SidebarScaffold(
            child: ReportBuilderScreen(deliverableId: deliverableId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/report-editor/:deliverableId',
      builder: (context, state) {
        final deliverableId = state.pathParameters['deliverableId']!;
        final reportId = state.uri.queryParameters['reportId'];
        return RouteGuard(
          route: '/report-editor',
          child: SidebarScaffold(
            child: ReportEditorScreen(
                deliverableId: deliverableId, reportId: reportId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/report-view/:reportId',
      builder: (context, state) {
        final reportId = state.pathParameters['reportId']!;
        return RouteGuard(
          route: '/report-builder', // Using same guard as builder for now
          child: SidebarScaffold(
            child: ReportViewScreen(reportId: reportId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/report-sent/:reportId',
      builder: (context, state) {
        final reportId = state.pathParameters['reportId']!;
        return RouteGuard(
          route: '/report-builder',
          child: SidebarScaffold(
            child: ReportViewScreen(
                reportId: reportId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/client-review/:reportId',
      builder: (context, state) {
        final reportId = state.pathParameters['reportId']!;
        final extra = state.extra;
        SignOffReport? initialReport;
        Deliverable? initialDeliverable;
        if (extra is Map) {
          try {
            initialReport = extra['report'] as SignOffReport?;
          } catch (_) {}
          try {
            initialDeliverable = extra['deliverable'] as Deliverable?;
          } catch (_) {}
        }
        return RouteGuard(
          route: '/client-review',
          child: SidebarScaffold(
            child: ClientReviewScreen(
              reportId: reportId,
              initialReport: initialReport,
              initialDeliverable: initialDeliverable,
            ),
          ),
        );
      },
    ),
    // Token-based client review route (no auth required)
    GoRoute(
      path: '/client-review-token/:token',
      builder: (context, state) {
        final token = state.pathParameters['token']!;
        return ClientReviewScreen(
          reportId: '', // Will be fetched via token
          reviewToken: token,
        );
      },
    ),
    GoRoute(
      path: '/enhanced-client-review/:reportId',
      builder: (context, state) {
        final reportId = state.pathParameters['reportId']!;
        return RouteGuard(
          route: '/enhanced-client-review',
          child: SidebarScaffold(
            child: ClientReviewWorkflowScreen(reportId: reportId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/notification-center',
      redirect: (context, state) => '/notifications',
    ),
    GoRoute(
      path: '/report-repository',
      builder: (context, state) => const RouteGuard(
        route: '/report-repository',
        child: SidebarScaffold(
          child: ReportRepositoryScreen(),
        ),
      ),
    ),

    GoRoute(
      path: '/send-reminder',
      builder: (context, state) => const RouteGuard(
        route: '/send-reminder',
        child: SidebarScaffold(
          child: SendReminderScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/deadlines',
      builder: (context, state) => const RouteGuard(
        route: '/deadlines',
        child: SidebarScaffold(
          child: DeadlinesScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/sprint-console',
      builder: (context, state) {
        final projectKey = state.uri.queryParameters['projectKey'];
        final projectId = state.uri.queryParameters['projectId'];
        final sprintId = state.uri.queryParameters['sprintId'];
        return RouteGuard(
          route: '/sprint-console',
          child: SidebarScaffold(
            child: SprintConsoleScreen(
              initialProjectKey: projectKey ?? projectId,
              initialSprintId: sprintId,
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/sprint-board/:sprintId',
      builder: (context, state) {
        final sprintId = state.pathParameters['sprintId']!;
        final sprintName = state.uri.queryParameters['name'] ?? 'Sprint Board';
        return RouteGuard(
          route: '/sprint-board',
          child: SidebarScaffold(
            child: SprintBoardScreen(
              sprintId: sprintId,
              sprintName: sprintName,
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/sprint-report/:sprintId',
      builder: (context, state) {
        final sprintId = state.pathParameters['sprintId']!;
        final sprintName = state.uri.queryParameters['name'];
        return RouteGuard(
          route: '/sprint-report',
          child: SidebarScaffold(
            child: SprintReportScreen(
              sprintId: sprintId,
              sprintName: sprintName,
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/approvals',
      builder: (context, state) => const RouteGuard(
        route: '/approval-requests',
        child: SidebarScaffold(
          child: ApprovalRequestsScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/approval-requests',
      builder: (context, state) => const RouteGuard(
        route: '/approval-requests',
        child: SidebarScaffold(
          child: ApprovalRequestsScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/deliverables/:deliverableId',
      builder: (context, state) {
        final deliverableId = state.pathParameters['deliverableId']!;
        return RouteGuard(
          route: '/deliverables-overview',
          child: SidebarScaffold(
            child: DeliverableDetailByIdScreen(deliverableId: deliverableId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/deliverables',
      builder: (context, state) => const RouteGuard(
        route: '/deliverables',
        child: SidebarScaffold(
          child: DeliverablesListScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/deliverables-overview',
      builder: (context, state) => const RouteGuard(
        route: '/deliverables-overview',
        child: SidebarScaffold(
          child: DeliverablesOverviewScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/epics',
      redirect: (context, state) => '/deliverables-overview',
    ),
    GoRoute(
      path: '/epics/:epicId',
      redirect: (context, state) => '/deliverables-overview',
    ),
    GoRoute(
      path: '/repository',
      builder: (context, state) => const RouteGuard(
        route: '/repository',
        child: SidebarScaffold(
          child: RepositoryScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/repository/:projectKey',
      builder: (context, state) => RouteGuard(
        route: '/repository',
        child: SidebarScaffold(
          child:
              RepositoryScreen(projectKey: state.pathParameters['projectKey']),
        ),
      ),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const RouteGuard(
        route: '/notifications',
        child: SidebarScaffold(
          child: NotificationsScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/smtp-config',
      builder: (context, state) => const RouteGuard(
        route: '/smtp-config',
        child: SidebarScaffold(
          child: SmtpConfigScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/role-management',
      builder: (context, state) => const RouteGuard(
        route: '/role-management',
        child: SidebarScaffold(
          child: RoleManagementScreen(),
        ),
      ),
    ),
    // Removed redundant user-management route; role-management covers it

    GoRoute(
      path: '/profile',
      builder: (context, state) => RouteGuard(
        route: '/profile',
        child: SidebarScaffold(
          child: ProfileScreen(mode: state.uri.queryParameters['mode']),
        ),
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const RouteGuard(
        route: '/settings',
        child: SidebarScaffold(
          child: SettingsScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/system-metrics',
      builder: (context, state) => const RouteGuard(
        route: '/system-metrics',
        child: SidebarScaffold(
          child: SystemMetricsScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/system-health',
      builder: (context, state) => const RouteGuard(
        route: '/system-health',
        child: SidebarScaffold(
          child: SystemHealthScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/audit-logs',
      builder: (context, state) => const RouteGuard(
        route: '/audit-logs',
        child: SidebarScaffold(
          child: AuditLogsScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/assessment/:skill',
      builder: (context, state) => RouteGuard(
        route: '/skill-assessment',
        child: SidebarScaffold(
          child: SkillAssessmentScreen(
              selectedSkill: state.pathParameters['skill']),
        ),
      ),
    ),
    GoRoute(
      path: '/environment-management',
      builder: (context, state) => const RouteGuard(
        route: '/environment-management',
        child: SidebarScaffold(
          child: EnvironmentManagementScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/project-workspace',
      builder: (context, state) => const RouteGuard(
        route: '/project-workspace',
        child: SidebarScaffold(
          child: ProjectWorkspaceScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/projects',
      builder: (context, state) => const RouteGuard(
        route: '/projects',
        child: SidebarScaffold(
          child: ProjectsOverviewScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/project-workspace/:projectId',
      builder: (context, state) {
        final projectId = state.pathParameters['projectId'];
        return RouteGuard(
          route: '/project-workspace',
          child: SidebarScaffold(
            child: ProjectWorkspaceScreen(projectId: projectId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/project-details/:projectId',
      builder: (context, state) {
        final projectId = state.pathParameters['projectId']!;
        return RouteGuard(
          route: '/project-details',
          child: SidebarScaffold(
            child: ProjectDetailsScreen(projectId: projectId),
          ),
        );
      },
    ),
    GoRoute(
      path: '/account',
      redirect: (context, state) => '/profile',
    ),
  ],
);
