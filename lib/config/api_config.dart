import 'environment.dart';

class ApiConfig {
  // Base API configuration - prioritize production URL for deployed apps
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3001/api',
  );
  static const String apiVersion = '/v1';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration tokenRefreshBuffer = Duration(minutes: 5);

  // Environment-specific URLs
  static const String developmentUrl = 'http://127.0.0.1:3001/api';
  static const String stagingUrl = 'https://staging-api.flownet.works';
  static const String productionUrl = 'https://flow-space.onrender.com/api';

  // API Endpoints
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authLogout = '/auth/logout';
  static const String authRefresh = '/auth/refresh';
  static const String authMe = '/auth/me';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authResetPassword = '/auth/reset-password';
  static const String authChangePassword = '/auth/change-password';

  // User endpoints
  static const String users = '/users';
  static const String userProfile = '/auth/profile';

  // Deliverable endpoints
  static const String deliverables = '/deliverables';
  static const String deliverableSubmit = '/deliverables/{id}/submit';
  static const String deliverableApprove = '/deliverables/{id}/approve';
  static const String deliverableRequestChanges =
      '/deliverables/{id}/request-changes';

  // Sprint endpoints
  static const String sprints = '/sprints';
  static const String sprintMetrics = '/sprints/{id}/metrics';

  // Sign-off report endpoints
  static const String signOffReports = '/sign-off-reports';
  static const String signOffReportSubmit = '/sign-off-reports/{id}/submit';
  static const String signOffReportApprove = '/sign-off-reports/{id}/approve';
  static const String signOffReportRequestChanges =
      '/sign-off-reports/{id}/request-changes';

  // Release readiness endpoints
  static const String releaseReadiness = '/deliverables/{id}/readiness-checks';

  // Notification endpoints
  static const String notifications = '/notifications';
  static const String notificationRead = '/notifications/{id}/read';
  static const String notificationReadAll = '/notifications/read-all';

  // Dashboard and analytics endpoints
  static const String dashboard = '/dashboard';
  static const String analytics = '/analytics/{type}';
  static const String auditLogs = '/audit-logs';

  // System endpoints
  static const String health = '/health';
  static const String systemSettings = '/system/settings';

  // File upload endpoints
  static const String fileUpload = '/files/upload';
  static const String fileDelete = '/files/{id}';

  // Authentication
  static String authToken = '';

  // Helper methods
  static String getFullUrl(String endpoint) {
    return '${Environment.apiBaseUrl}$endpoint';
  }

  static String replacePathParameter(
      String endpoint, String parameter, String value) {
    return endpoint.replaceAll('{$parameter}', value);
  }

  // Environment detection - improved logic
  static bool get isDevelopment =>
      const bool.fromEnvironment('dart.vm.product') == false &&
      const String.fromEnvironment('FLUTTER_WEB', defaultValue: '') == '';
  static bool get isProduction =>
      const bool.fromEnvironment('dart.vm.product') == true ||
      const String.fromEnvironment('FLUTTER_WEB', defaultValue: '') != '';

  // Get environment-specific base URL
  static String get environmentBaseUrl {
    if (isDevelopment) {
      return developmentUrl;
    } else if (isProduction) {
      return productionUrl;
    } else {
      return stagingUrl;
    }
  }

  // API Headers
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Flownet-Mobile/1.0.0',
      };

  static Map<String, String> getAuthHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };

  // Error codes
  static const int unauthorizedCode = 401;
  static const int forbiddenCode = 403;
  static const int notFoundCode = 404;
  static const int serverErrorCode = 500;
  static const int serviceUnavailableCode = 503;

  // Retry configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration exponentialBackoffMultiplier =
      Duration(milliseconds: 500);

  // Cache configuration
  static const Duration cacheExpiry = Duration(minutes: 5);
  static const Duration userCacheExpiry = Duration(hours: 1);
  static const Duration deliverableCacheExpiry = Duration(minutes: 15);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // File upload limits
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedFileTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'application/pdf',
    'text/plain',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ];
}
