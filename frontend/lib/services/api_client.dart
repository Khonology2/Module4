import 'dart:convert';
import 'dart:async';
import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../utils/debug_helper.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

static String get _baseUrlWithVersion => Environment.apiBaseUrl;
  static Duration get _timeout {
    const isProdFlag = bool.fromEnvironment('IS_PRODUCTION', defaultValue: false);
    if (isProdFlag || Environment.isRenderDeployed) {
      return const Duration(seconds: 180);
    }
    return const Duration(seconds: 20);
  }

  static String _fallbackSignoffEndpoint(String endpoint) {
    if (endpoint.startsWith('/sign-off-reports')) {
      return endpoint.replaceFirst('/sign-off-reports', '/signoff');
    }
    return endpoint;
  }

  bool _initialized = false;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  // Getters
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null && _isTokenValid();
  
  // Get auth token for API calls
  String? getAuthToken() => _accessToken;
  
  // Get current user (cached)
  User? _currentUser;
  
  User? get currentUser => _currentUser;
  
  // Set current user
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  // Initialize API client
  Future<void> initialize() async {
    if (_initialized) return;
    await _resolveAndSetApiBaseUrlOverride();
    await _loadStoredTokens();
    DebugHelper.logEnvironmentInfo();
    debugPrint('API Client initialized with base URL: $_baseUrlWithVersion');
    debugPrint('DEBUG: Environment.apiBaseUrl = ${Environment.apiBaseUrl}');
    debugPrint('DEBUG: Environment.isRenderDeployed = ${Environment.isRenderDeployed}');
    debugPrint('FINAL DEBUG: _baseUrlWithVersion = $_baseUrlWithVersion');
    Future.microtask(() async {
      try {
        final url = '$_baseUrlWithVersion/health';
        final resp = await http
            .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
        final ct = (resp.headers['content-type'] ?? '').toLowerCase();
        if (resp.statusCode >= 200 &&
            resp.statusCode < 300 &&
            ct.contains('application/json')) {
          return;
        }
      } catch (_) {}
    });
    _initialized = true;
  }

  Future<void> _resolveAndSetApiBaseUrlOverride({bool force = false}) async {
    if (Environment.isLocalDevelopment) return;

    const envDefined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final envBase = envDefined.trim();

    String normalize(String url) {
      final trimmed = url.trim();
      if (trimmed.isEmpty) return trimmed;
      if (trimmed.endsWith('/')) return trimmed.substring(0, trimmed.length - 1);
      return trimmed;
    }

    final candidates = <String>[
      if (envBase.isNotEmpty) normalize(envBase),
      'https://flow-space-backend.onrender.com/api/v1',
      'https://backend-532p.onrender.com/api/v1',
    ].map(normalize).where((u) => u.isNotEmpty).toList();

    final uniqueCandidates = <String>[];
    for (final c in candidates) {
      if (!uniqueCandidates.contains(c)) uniqueCandidates.add(c);
    }

    bool _looksLikeHtml(http.Response resp) {
      final ct = (resp.headers['content-type'] ?? '').toLowerCase();
      final b = resp.body.trimLeft();
      return ct.contains('text/html') || b.startsWith('<!DOCTYPE') || b.startsWith('<html');
    }

    Future<bool> isHealthy(String baseUrl) async {
      try {
        final uri = Uri.parse('$baseUrl/health');
        final resp = await http
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
        if (_looksLikeHtml(resp)) return false;
        return true;
      } catch (_) {
        return false;
      }
    }

    if (!force) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = (prefs.getString('resolved_api_base_url') ?? '').trim();
        if (cached.isNotEmpty) {
          if (await isHealthy(cached)) {
            Environment.setOverrideApiBaseUrl(cached);
            return;
          }
          await prefs.remove('resolved_api_base_url');
        }
      } catch (_) {}
    }

    for (final baseUrl in uniqueCandidates) {
      final ok = await isHealthy(baseUrl);
      if (ok) {
        Environment.setOverrideApiBaseUrl(baseUrl);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('resolved_api_base_url', baseUrl);
        } catch (_) {}
        return;
      }
    }

    // If nothing is healthy, do not force an override.
    // Environment.apiBaseUrl already has a production fallback that points at the backend service.
  }

  // Token management
  Future<void> _loadStoredTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');
      final expiryString = prefs.getString('token_expiry');
      if (expiryString != null) {
        _tokenExpiry = DateTime.parse(expiryString);
      }
    } catch (e) {
      debugPrint('Error loading stored tokens: $e');
    }
  }

  Future<void> saveTokens(String accessToken, String refreshToken, DateTime expiry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);
      await prefs.setString('token_expiry', expiry.toIso8601String());
      
      _accessToken = accessToken;
      _refreshToken = refreshToken;
      _tokenExpiry = expiry;
    } catch (e) {
      debugPrint('Error saving tokens: $e');
    }
  }

  Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('token_expiry');
      
      _accessToken = null;
      _refreshToken = null;
      _tokenExpiry = null;
    } catch (e) {
      debugPrint('Error clearing tokens: $e');
    }
  }

  bool _isTokenValid() {
    if (_tokenExpiry == null) return false;
    return DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrlWithVersion/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_refreshToken',
        },
        body: jsonEncode({
          'refresh_token': _refreshToken,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access_token'];
        final newRefreshToken = data['refresh_token'] ?? _refreshToken;
        final expiry = DateTime.now().add(Duration(seconds: data['expires_in'] ?? 3600));
        
        await saveTokens(newAccessToken, newRefreshToken, expiry);
        return true;
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
    }
    return false;
  }

  // HTTP Methods
  Future<ApiResponse> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requireAuth = true,
    Duration? timeout,
  }) async {
    // BYPASSES DISABLED: Backend is now working correctly on Render
    // The deployed app should use real API calls to backend-532p.onrender.com

    if (!requireAuth) {
      // Make unauthenticated request
      return await _makeUnauthenticatedRequest('GET', endpoint, queryParams: queryParams);
    }

    // Check auth
    if (isAuthenticated && !_isTokenValid()) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        return ApiResponse.error('Authentication expired. Please login again.');
      }
    }

    return await _makeRequest('GET', endpoint, queryParams: queryParams, timeout: timeout);
  }

  Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requireAuth = true,
    Duration? timeout,
  }) async {
    // BYPASSES DISABLED: Backend is now working correctly on Render
    // The deployed app should use real API calls to backend-532p.onrender.com

    if (!requireAuth && queryParams != null && queryParams.containsKey('token')) {
      // For token-based requests, we can skip auth but still need to pass token
      // The token will be in query params, so we'll make a special request
      return await _makeTokenBasedRequest('POST', endpoint, body: body, queryParams: queryParams);
    }
    return await _makeRequest('POST', endpoint, body: body, queryParams: queryParams, timeout: timeout);
  }

  Future<ApiResponse> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Duration? timeout,
  }) async {
    // BYPASSES DISABLED: Backend is now working correctly on Render
    // The deployed app should use real API calls to backend-532p.onrender.com
    return await _makeRequest('PUT', endpoint, body: body, queryParams: queryParams, timeout: timeout);
  }

  Future<ApiResponse> delete(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? timeout,
  }) async {
    // BYPASSES DISABLED: Backend is now working correctly on Render
    // The deployed app should use real API calls to backend-532p.onrender.com
    return await _makeRequest('DELETE', endpoint, queryParams: queryParams, timeout: timeout);
  }

  Future<Uint8List> getBytes(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requireAuth = true,
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    if (requireAuth) {
      if (isAuthenticated && !_isTokenValid()) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          throw Exception('Authentication expired. Please login again.');
        }
      }
    }

    String buildUrl(String ep) {
      String url = '$_baseUrlWithVersion$ep';
      if (queryParams != null && queryParams.isNotEmpty) {
        final uri = Uri.parse(url);
        url = uri.replace(queryParameters: queryParams).toString();
      }
      return url;
    }

    String url = buildUrl(endpoint);

    final reqHeaders = <String, String>{
      'Accept': 'application/pdf',
      if (headers != null) ...headers,
    };
    if (requireAuth && _accessToken != null) {
      reqHeaders['Authorization'] = 'Bearer $_accessToken';
    }

    final effectiveTimeout = timeout ?? _timeout;
    try {
      http.Response resp = await http.get(Uri.parse(url), headers: reqHeaders).timeout(effectiveTimeout);
      if (requireAuth &&
          resp.statusCode == 404 &&
          endpoint.startsWith('/sign-off-reports') &&
          _fallbackSignoffEndpoint(endpoint) != endpoint) {
        url = buildUrl(_fallbackSignoffEndpoint(endpoint));
        resp = await http.get(Uri.parse(url), headers: reqHeaders).timeout(effectiveTimeout);
      }
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return resp.bodyBytes;
      }
      final msg = resp.body.isNotEmpty ? resp.body : 'Request failed (${resp.statusCode})';
      throw Exception(msg);
    } on TimeoutException {
      throw Exception('Request timed out. If this is the first request on Render, the backend may be waking up. Please try again.');
    }
  }

  // Multipart file upload method
  Future<ApiResponse> uploadFile(
    String endpoint, 
    String filePath, 
    String fileName, 
    String fileType, 
    {
      Map<String, String>? fields,
      List<int>? fileBytes,
    }
  ) async {
    try {
      // Check if token needs refresh
      if (_accessToken != null && !_isTokenValid()) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          await clearTokens();
          return ApiResponse.error('Authentication expired. Please login again.');
        }
      }

      // Build URL
      final String url = '$_baseUrlWithVersion$endpoint';

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(url));

      // Add authorization header
      if (_accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }

      // Add file
      if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
        ));
      }

      // Add additional fields
      if (fields != null) {
        fields.forEach((key, value) {
          request.fields[key] = value;
        });
      }

      // Add file type field
      request.fields['fileType'] = fileType;

      // Send request
      final response = await request.send().timeout(_timeout);
      final responseBody = await response.stream.bytesToString();

      // Convert to regular response
      final httpResponse = http.Response(responseBody, response.statusCode);
      return _handleResponse(httpResponse);
    } on SocketException {
      return ApiResponse.error('No internet connection. Please check your network.');
    } on TimeoutException {
      return ApiResponse.error('Request timed out. If this is the first request on Render, the backend may be waking up. Please try again.');
    } on HttpException catch (e) {
      return ApiResponse.error('HTTP error: ${e.message}');
    } catch (e) {
      debugPrint('File upload error: $e');
      return ApiResponse.error('An unexpected error occurred during file upload: $e');
    }
  }

  Future<ApiResponse> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    try {
      // Check if token needs refresh
      if (_accessToken != null && !_isTokenValid()) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          await clearTokens();
          return ApiResponse.error('Authentication expired. Please login again.');
        }
      }

      String buildUrl(String ep) {
        String url = '$_baseUrlWithVersion$ep';
        if (queryParams != null && queryParams.isNotEmpty) {
          final uri = Uri.parse(url);
          url = uri.replace(queryParameters: queryParams).toString();
        }
        return url;
      }

      String url = buildUrl(endpoint);

      // Prepare headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (includeAuth && _accessToken != null) {
        headers['Authorization'] = 'Bearer $_accessToken';
      }

      final headersForLog = Map<String, String>.from(headers);
      if (headersForLog.containsKey('Authorization')) {
        headersForLog['Authorization'] = 'Bearer ***';
      }
      debugPrint('Request Headers: $headersForLog');

      Future<http.Response> send(String requestUrl) async {
        final effectiveTimeout = timeout ?? _timeout;
        switch (method.toUpperCase()) {
          case 'GET':
            return await http.get(Uri.parse(requestUrl), headers: headers).timeout(effectiveTimeout);
          case 'POST':
            debugPrint('🌐 API POST to: $requestUrl');
            debugPrint('📤 POST body: ${body != null ? jsonEncode(body) : 'null'}');
            return await http.post(
              Uri.parse(requestUrl),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            ).timeout(effectiveTimeout);
          case 'PUT':
            return await http.put(
              Uri.parse(requestUrl),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            ).timeout(effectiveTimeout);
          case 'DELETE':
            return await http.delete(Uri.parse(requestUrl), headers: headers).timeout(effectiveTimeout);
          default:
            throw Exception('Unsupported HTTP method: $method');
        }
      }

      bool isHtmlResponse(http.Response r) {
        final ct = (r.headers['content-type'] ?? '').toLowerCase();
        final b = r.body.trimLeft();
        return ct.contains('text/html') || b.startsWith('<!DOCTYPE') || b.startsWith('<html');
      }

      String currentEndpoint = endpoint;
      bool didResolve = false;
      bool didFallback = false;

      while (true) {
        url = buildUrl(currentEndpoint);
        http.Response response;
        try {
          response = await send(url);
        } on TimeoutException {
          if (!didResolve && !Environment.isLocalDevelopment) {
            didResolve = true;
            await _resolveAndSetApiBaseUrlOverride(force: true);
            continue;
          }
          rethrow;
        }

        if (!didResolve && !Environment.isLocalDevelopment && isHtmlResponse(response)) {
          didResolve = true;
          await _resolveAndSetApiBaseUrlOverride(force: true);
          continue;
        }

        if (includeAuth &&
            !didFallback &&
            response.statusCode == 404 &&
            currentEndpoint.startsWith('/sign-off-reports') &&
            _fallbackSignoffEndpoint(currentEndpoint) != currentEndpoint) {
          didFallback = true;
          currentEndpoint = _fallbackSignoffEndpoint(currentEndpoint);
          continue;
        }

        return _handleResponse(response);
      }
    } on SocketException {
      return ApiResponse.error('No internet connection. Please check your network.');
    } on TimeoutException {
      return ApiResponse.error('Request timed out. If this is the first request on Render, the backend may be waking up. Please try again.');
    } on HttpException catch (e) {
      return ApiResponse.error('HTTP error: ${e.message}');
    } catch (e) {
      debugPrint('API request error: $e');
      return ApiResponse.error('An unexpected error occurred: $e');
    }
  }

  Future<ApiResponse> _makeUnauthenticatedRequest(
    String method,
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      // Build URL
      String url = '$_baseUrlWithVersion$endpoint';
      if (queryParams != null && queryParams.isNotEmpty) {
        final uri = Uri.parse(url);
        url = uri.replace(queryParameters: queryParams).toString();
      }

      // Prepare headers (no auth)
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Make request
      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
          break;
        default:
          throw Exception('Unsupported HTTP method for unauthenticated request: $method');
      }

      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('No internet connection. Please check your network.');
    } on TimeoutException {
      return ApiResponse.error('Request timed out. If this is the first request on Render, the backend may be waking up. Please try again.');
    } on HttpException catch (e) {
      return ApiResponse.error('HTTP error: ${e.message}');
    } catch (e) {
      debugPrint('Unauthenticated API request error: $e');
      return ApiResponse.error('An unexpected error occurred: $e');
    }
  }

  Future<ApiResponse> _makeTokenBasedRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      // Build URL
      String url = '$_baseUrlWithVersion$endpoint';
      if (queryParams != null && queryParams.isNotEmpty) {
        final uri = Uri.parse(url);
        url = uri.replace(queryParameters: queryParams).toString();
      }

      // Prepare headers (include token in header if present in query)
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      // If token is in query params, also add it to header for backend compatibility
      if (queryParams != null && queryParams.containsKey('token')) {
        headers['x-review-token'] = queryParams['token']!;
      }

      // Make request
      http.Response response;
      switch (method.toUpperCase()) {
        case 'POST':
          response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(_timeout);
          break;
        default:
          throw Exception('Unsupported HTTP method for token-based request: $method');
      }

      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('No internet connection. Please check your network.');
    } on TimeoutException {
      return ApiResponse.error('Request timed out. If this is the first request on Render, the backend may be waking up. Please try again.');
    } on HttpException catch (e) {
      return ApiResponse.error('HTTP error: ${e.message}');
    } catch (e) {
      debugPrint('Token-based API request error: $e');
      return ApiResponse.error('An unexpected error occurred: $e');
    }
  }

  Future<ApiResponse> uploadFileBytes(
    String endpoint, {
    required List<int> fileBytes,
    required String filename,
    String fileField = 'file',
    Map<String, String>? fields,
  }) async {
    // Check auth
    if (isAuthenticated && !_isTokenValid()) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        return ApiResponse.error('Authentication expired. Please login again.');
      }
    }

    try {
      final uri = Uri.parse('$_baseUrlWithVersion$endpoint');
      final request = http.MultipartRequest('POST', uri);

      // Auth header
      if (_accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }

      // Add fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: filename,
      ));

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error('Request timed out. If this is the first request on Render, the backend may be waking up. Please try again.');
    } catch (e) {
      debugPrint('Upload error: $e');
      return ApiResponse.error('Upload failed: $e');
    }
  }

  ApiResponse _handleResponse(http.Response response) {
    try {
      final rawBody = response.body;
      if (response.statusCode == 204 || rawBody.trim().isEmpty) {
        return ApiResponse.success(null, response.statusCode);
      }
      // Check if response is HTML (error pages) instead of JSON
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') || response.body.trim().startsWith('<!DOCTYPE')) {
        // Server returned HTML (likely a 404 or error page)
        String errorMsg = 'Server returned HTML instead of JSON';
        if (response.statusCode == 404) {
          errorMsg = 'Endpoint not found (404). Check the API endpoint path.';
        } else if (response.statusCode >= 500) {
          errorMsg = 'Server error (${response.statusCode})';
        }
        return ApiResponse.error(errorMsg, response.statusCode);
      }
      
      final responseBody = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody == null) {
          return ApiResponse.success(null, response.statusCode);
        }

        // Support top-level lists (e.g., files, users collections)
        if (responseBody is List) {
          return ApiResponse.success(responseBody, response.statusCode);
        }

        // From here on, raw must be a Map-like structure
        if (responseBody is! Map) {
          return ApiResponse.success(responseBody, response.statusCode);
        }

        final Map<String, dynamic> body = responseBody as Map<String, dynamic>;

        // 1) Standard format: { success: true, data: ... }
        final bool isStandardFormat = body['success'] == true && body.containsKey('data');
        // 2) Auth format: { token: '...', user: {...} }
        final bool isAuthFormat = body.containsKey('token') || body.containsKey('user');

        if (isStandardFormat) {
          final data = body['data'];
          return ApiResponse.success(data, response.statusCode);
        }

        if (isAuthFormat) {
          return ApiResponse.success(body, response.statusCode);
        }

        // 3) Fallback: return entire map as data
        return ApiResponse.success(body, response.statusCode);
      } else {
        if (responseBody is Map) {
          final Map<String, dynamic> body = responseBody as Map<String, dynamic>;
          String errorMessage = body['message']?.toString() ?? body['error']?.toString() ?? 'Request failed';
          if (body.containsKey('details')) {
            errorMessage += ': ${body['details']}';
          }
          return ApiResponse.error(errorMessage, response.statusCode);
        }
        return ApiResponse.error('Request failed', response.statusCode);
      }
    } catch (e) {
      // If JSON parsing fails, provide a more helpful error message
      String errorMsg = 'Invalid response format: $e';
      if (response.body.trim().startsWith('<!DOCTYPE')) {
        errorMsg = 'Server returned HTML instead of JSON. Check if the endpoint exists.';
      }
      return ApiResponse.error(errorMsg, response.statusCode);
    }
  }

  // Authentication methods
  Future<ApiResponse> login(String email, String password) async {

    // BYPASSES DISABLED: Backend is now working correctly on Render
    // The deployed app should use real API calls to backend-532p.onrender.com

    // Retry a limited number of times for transient startup/network failures.
    ApiResponse response = ApiResponse.error('Login request not sent');
    const isProdFlag = bool.fromEnvironment('IS_PRODUCTION', defaultValue: false);
    final maxAttempts = (isProdFlag || Environment.isRenderDeployed) ? 6 : 2;

    Future<bool> pingHealthOnce() async {
      try {
        await _resolveAndSetApiBaseUrlOverride(force: true);
      } catch (_) {}
      try {
        final url = '$_baseUrlWithVersion/health';
        final resp = await http
            .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
        final ct = (resp.headers['content-type'] ?? '').toLowerCase();
        if (!ct.contains('application/json')) return false;
        final body = resp.body.trimLeft();
        if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) return false;
        return true;
      } catch (_) {}
      return false;
    }

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint('🔐 Login attempt $attempt for: $email');

      if (attempt == 1) {
        for (int i = 0; i < 6; i++) {
          final ok = await pingHealthOnce();
          if (ok) break;
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      try {
        String url = '$_baseUrlWithVersion/auth/login';
        final raw = await http
            .post(
              Uri.parse(url),
              headers: const {'Accept': 'application/json'},
              body: {
                'email': email,
                'password': password,
              },
            )
            .timeout(const Duration(seconds: 20));

        bool looksHtml(http.Response r) {
          final ct = (r.headers['content-type'] ?? '').toLowerCase();
          final b = r.body.trimLeft();
          return ct.contains('text/html') || b.startsWith('<!DOCTYPE') || b.startsWith('<html');
        }

        if (looksHtml(raw) || raw.statusCode == 502 || raw.statusCode == 503 || raw.statusCode == 504) {
          response = ApiResponse.error('Backend is starting up. Please try again.', 0);
        } else {
          response = _handleResponse(raw);
        }
      } on TimeoutException {
        response = ApiResponse.error('Backend is starting up. Please try again.', 0);
      }

      // Any HTTP response (2xx/4xx/5xx) should stop retrying immediately.
      if (response.statusCode != 0) {
        break;
      }

      // statusCode == 0 means transport-level failure (e.g. Failed to fetch).
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final accessToken = data['token'] ?? data['access_token'];
      final refreshToken = data['refresh_token'] ?? '';
      final expiresIn = data['expires_in'] ?? 86400;
      final expiry = DateTime.now().add(Duration(seconds: expiresIn));
      
      await saveTokens(accessToken, refreshToken, expiry);
    }

    return response;
  }

  Future<ApiResponse> ssoLogin(String token) async {
    final response = await post(
      '/auth/sso-login',
      body: {'token': token},
      requireAuth: false,
    );
    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'] ?? '';
      if (accessToken != null) {
        final expiry = DateTime.now().add(const Duration(minutes: 15));
        await saveTokens(accessToken, refreshToken, expiry);
      }
    }
    return response;
  }

  Future<ApiResponse> register(String email, String password, String name, String role) async {
    // Parse the full name into firstName and lastName for the backend
    final nameParts = name.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final response = await post('/auth/register', body: {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
    },);

    // Save tokens if registration is successful
    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final accessToken = data['token']; // Backend returns 'token' in registration
      if (accessToken != null) {
        final refreshToken = data['refresh_token'] ?? '';
        final expiresIn = data['expires_in'] ?? 86400; // Default to 24 hours
        final expiry = DateTime.now().add(Duration(seconds: expiresIn));
        
        await saveTokens(accessToken, refreshToken, expiry);
      }
    }

    return response;
  }

  Future<ApiResponse> logout() async {

    // BYPASSES DISABLED: Backend is now working correctly on Render
    // The deployed app should use real API calls to backend-532p.onrender.com

    final response = await post('/auth/logout');
    await clearTokens();
    return response;
  }

  Future<ApiResponse> getCurrentUser() async {

    // BYPASSES DISABLED: Backend is now working correctly on Render
    // The deployed app should use real API calls to backend-532p.onrender.com

    // Don't call /auth/me if we don't have an access token
    if (_accessToken == null) {
      return ApiResponse.error('No access token available. Please login first.');
    }

    return await get('/auth/me');
  }

  Future<ApiResponse> updateProfile(Map<String, dynamic> updates) async {
    return await put('/auth/profile', body: updates);
  }

  Future<ApiResponse> changePassword(String currentPassword, String newPassword) async {
    return await post('/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    },);
  }

  Future<ApiResponse> forgotPassword(String email) async {
    return await post('/auth/forgot-password', body: {
      'email': email,
    },);
  }

  Future<ApiResponse> resetPassword(String token, String newPassword) async {
    return await post('/auth/reset-password', body: {
      'token': token,
      'password': newPassword,
    },);
  }

}

class ApiResponse {
  final bool isSuccess;
  final dynamic data; // Changed to dynamic to support both Map and List
  final String? error;
  final int statusCode;

  ApiResponse._({
    required this.isSuccess,
    this.data,
    this.error,
    required this.statusCode,
  });

  factory ApiResponse.success(dynamic data, int statusCode) {
    return ApiResponse._(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error(String error, [int statusCode = 0]) {
    return ApiResponse._(
      isSuccess: false,
      error: error,
      statusCode: statusCode,
    );
  }

  String? get deliverableId => null;

  @override
  String toString() {
    return 'ApiResponse(isSuccess: $isSuccess, data: $data, error: $error, statusCode: $statusCode)';
  }
}
