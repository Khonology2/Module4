import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import 'backend_api_service.dart';

class UserDataService {
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();

  final BackendApiService _apiService = BackendApiService();
  final List<User> _cachedUsers = [];
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Get all users from backend API
  Future<List<User>> getUsers({
    bool forceRefresh = false,
    String? searchQuery,
    UserRole? filterRole,
    int page = 1,
    int limit = 1000,
  }) async {
    // Check cache first if not forcing refresh
    if (!forceRefresh && _isCacheValid()) {
      return _filterUsers(_cachedUsers, searchQuery, filterRole);
    }

    try {
      // Use direct HTTP call to avoid type conversion issues with BackendApiService
      final users = await _getUsersDirectApiCall(page, limit, searchQuery);
      
      // Update cache
      _cachedUsers.clear();
      _cachedUsers.addAll(users);
      _lastFetchTime = DateTime.now();
      
      // Save to local storage for offline access
      await _saveUsersToStorage(users);
      
      return _filterUsers(users, searchQuery, filterRole);
    } catch (e) {
      debugPrint('Error fetching users via direct API call: $e');
      
      // Fallback to local storage
      final localUsers = await _loadUsersFromStorage();
      if (localUsers.isNotEmpty) {
        return _filterUsers(localUsers, searchQuery, filterRole);
      }
      
      // No mock data fallback - throw error instead
      debugPrint('Failed to fetch users and no cached data available');
      throw Exception('Failed to fetch users: $e');
    }
  }

  // Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      // Check cache first
      final cachedUser = _cachedUsers.firstWhere(
          (user) => user.id == userId,
          orElse: () => User(
            id: '',
            email: '',
            name: '',
            role: UserRole.teamMember,
            createdAt: DateTime.now(),
            isActive: false,
        ),
      );
      
      if (cachedUser.id.isNotEmpty) {
        return cachedUser;
      }

      // Fetch from API
      final response = await _apiService.getUser(userId);
      if (response.isSuccess && response.data != null) {
        // Handle different response formats:
        // 1. Direct user object: {user data}
        // 2. List containing user object: [{user data}]
        dynamic userData;
        
        if (response.data is List && (response.data as List).isNotEmpty) {
          // List format - take first element
          userData = (response.data as List).first;
        } else if (response.data is Map) {
          // Direct object format
          userData = response.data;
        } else {
          userData = response.data;
        }
        
        return _parseUserFromApi(userData);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching user by ID: $e');
      return null;
    }
  }

  // Search users
  Future<List<User>> searchUsers(String query, {UserRole? filterRole}) async {
    return getUsers(searchQuery: query, filterRole: filterRole, forceRefresh: true);
  }

  // Filter users by role
  Future<List<User>> getUsersByRole(UserRole role) async {
    return getUsers(filterRole: role, forceRefresh: true);
  }

  // Get active users
  Future<List<User>> getActiveUsers() async {
    final allUsers = await getUsers();
    return allUsers.where((user) => user.isActive).toList();
  }

  // Get users count by role
  Future<Map<UserRole, int>> getUsersCountByRole() async {
    final users = await getUsers();
    final counts = <UserRole, int>{};
    
    for (final role in UserRole.values) {
      counts[role] = users.where((user) => user.role == role).length;
    }
    
    return counts;
  }

  // Update user role
  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      final response = await _apiService.updateUserRole(userId, newRole);
      if (response.isSuccess) {
        // Update cache
        final index = _cachedUsers.indexWhere((user) => user.id == userId);
        if (index != -1) {
          final updatedUser = _cachedUsers[index].copyWith(role: newRole);
          _cachedUsers[index] = updatedUser;
          await _saveUsersToStorage(_cachedUsers);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating user role: $e');
      return false;
    }
  }

  // Update user information
  Future<User> updateUser({
    required String userId,
    String? firstName,
    String? lastName,
    String? email,
    String? role,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (email != null) updates['email'] = email;
      if (role != null) updates['role'] = _parseUserRole(role).name;
      if (isActive != null) updates['is_active'] = isActive;
      
      // Update user via API
      final response = await _apiService.updateUser(userId, updates);
      
      if (response.isSuccess && response.data != null) {
        // Handle different response formats:
        // 1. Direct user object: {user data}
        // 2. List containing user object: [{user data}]
        dynamic userData;
        
        if (response.data is List && (response.data as List).isNotEmpty) {
          // List format - take first element
          userData = (response.data as List).first;
        } else if (response.data is Map) {
          // Direct object format
          userData = response.data;
        } else {
          userData = response.data;
        }
        
        // Parse the updated user from response
        final updatedUser = _parseUserFromApi(userData);
        
        // Update cache
        final index = _cachedUsers.indexWhere((user) => user.id == userId);
        if (index != -1) {
          _cachedUsers[index] = updatedUser;
          await _saveUsersToStorage(_cachedUsers);
        }
        
        return updatedUser;
      } else {
        throw Exception('Failed to update user: \${response.error}');
      }
    } catch (e) {
      debugPrint('Error updating user: \$e');
      rethrow;
    }
  }

  // Create new user (admin only)
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String name,
    required String role,
    required String password,
  }) async {
    try {
      // Create user via admin API endpoint
      final response = await _apiService.createUser(
        email: email,
        name: name,
        role: _parseUserRole(role).name,
        password: password,
      );
      
      if (response.isSuccess && response.data != null) {
        // Handle different response formats:
        // 1. Direct user object: {user data}
        // 2. List containing user object: [{user data}]
        dynamic userData;
        
        if (response.data is List && (response.data as List).isNotEmpty) {
          // List format - take first element
          userData = (response.data as List).first;
        } else if (response.data is Map) {
          // Direct object format
          userData = response.data;
        } else {
          userData = response.data;
        }
        
        // Parse the created user from response
        final newUser = _parseUserFromApi(userData);
        
        // Add to cache
        _cachedUsers.add(newUser);
        await _saveUsersToStorage(_cachedUsers);
        
        return {
          'success': true,
          'data': newUser,
        };
      } else {
        return {
          'success': false,
          'error': response.error ?? 'Failed to create user',
        };
      }
    } catch (e) {
      debugPrint('Error creating user: \$e');
      return {
        'success': false,
        'error': 'Error creating user: \$e',
      };
    }
  }

  // Delete user
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      // Delete user via API
      final response = await _apiService.deleteUser(userId);
      
      if (response.isSuccess) {
        // Remove from cache
        _cachedUsers.removeWhere((user) => user.id == userId);
        await _saveUsersToStorage(_cachedUsers);
        
        return {
          'success': true,
          'message': 'User deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to delete user: \${response.error}',
        };
      }
    } catch (e) {
      debugPrint('Error deleting user: \$e');
      return {
        'success': false,
        'error': 'Error deleting user: \$e',
      };
    }
  }

  // Clear cache
  void clearCache() {
    _cachedUsers.clear();
    _lastFetchTime = null;
  }

  // Private helper methods
  bool _isCacheValid() {
    return _lastFetchTime != null && 
           DateTime.now().difference(_lastFetchTime!) < _cacheDuration &&
           _cachedUsers.isNotEmpty;
  }

  // Direct API call to avoid type conversion issues
  Future<List<User>> _getUsersDirectApiCall(int page, int limit, String? searchQuery) async {
    try {
      // Use the existing BackendApiService method but handle the response differently
      final response = await _apiService.getUsers(
        page: page,
        limit: limit,
        search: searchQuery,
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('Direct API call successful - response type: ${response.data.runtimeType}');
        
        // Handle the response data directly without type assumptions
        final responseData = response.data;
        
        if (responseData == null) {
          debugPrint('Response data is null');
          throw Exception('No data received from API');
        }
        
        List<dynamic> usersDataList = const [];
        
        if (responseData is List) {
          usersDataList = responseData;
        } else if (responseData is Map) {
          final map = Map<String, dynamic>.from(responseData);
          dynamic usersField = map['users'];
          usersField ??= map['data'];
          usersField ??= map['items'];
          if (usersField == null && map['data'] is Map) {
            final nested = Map<String, dynamic>.from(map['data']);
            usersField = nested['users'] ?? nested['items'] ?? nested['data'];
          }
          if (usersField is List) {
            usersDataList = usersField;
          } else if (usersField is Map) {
            usersDataList = [usersField];
          } else if (usersField == null) {
            usersDataList = const [];
          }
        }
        
        if (usersDataList.isEmpty) {
          throw Exception('Invalid API response format: missing users array');
        }
        
        final users = <User>[];
        for (final userData in usersDataList) {
          try {
            Map<String, dynamic> userMap;
            if (userData is Map<String, dynamic>) {
              userMap = userData;
            } else if (userData is Map) {
              userMap = Map<String, dynamic>.from(userData);
            } else if (userData is String) {
              userMap = Map<String, dynamic>.from(jsonDecode(userData));
            } else {
              continue;
            }
            final user = _parseUserFromApi(userMap);
            users.add(user);
          } catch (_) {}
        }
        if (users.isNotEmpty) {
          return users;
        } else {
          throw Exception('No valid users found in response');
        }

      } else {
        throw Exception('API call failed: ${response.error}');
      }
    } catch (e) {
      debugPrint('Error in direct API call: $e');
      rethrow;
    }
  }



  List<User> _filterUsers(List<User> users, String? searchQuery, UserRole? filterRole) {
    var filteredUsers = users;
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filteredUsers = filteredUsers.where((user) =>
        user.name.toLowerCase().contains(query) ||
        user.email.toLowerCase().contains(query),
      ).toList();
    }
    
    if (filterRole != null) {
      filteredUsers = filteredUsers.where((user) => user.role == filterRole).toList();
    }
    
    return filteredUsers;
  }

  User _parseUserFromApi(dynamic userData) {
    // Handle both Map and other data types safely
    if (userData is! Map<String, dynamic>) {
      debugPrint('Warning: Expected Map<String, dynamic> but got ${userData.runtimeType}');
      debugPrint('User data content: $userData');
      
      // Try to convert to map if it's a string representation
      if (userData is String) {
        try {
          final parsed = jsonDecode(userData);
          if (parsed is Map<String, dynamic>) {
            userData = parsed;
          }
        } catch (e) {
          debugPrint('Failed to parse string as JSON: $e');
        }
      }
      
      // Handle JavaScript objects that might be converted to different types
      if (userData is Map) {
        try {
          // Convert any Map to Map<String, dynamic>
          userData = Map<String, dynamic>.from(userData);
        } catch (e) {
          debugPrint('Failed to convert Map to Map<String, dynamic>: $e');
        }
      }
      
      // If still not a map, return a default user
      if (userData is! Map<String, dynamic>) {
        debugPrint('Returning default user due to invalid data format');
        return User(
          id: '',
          email: '',
          name: 'Unknown User',
          role: UserRole.teamMember,
          createdAt: DateTime.now(),
          isActive: false,
        );
      }
    }
    
    final userMap = userData;
    
    // Handle different field name variations from backend
    final firstName = userMap['first_name'] ?? userMap['firstName'] ?? '';
    final lastName = userMap['last_name'] ?? userMap['lastName'] ?? '';
    final username = userMap['username']?.toString() ?? '';
    
    // Determine the name - prefer username if available, otherwise combine first/last names
    final name = username.isNotEmpty 
        ? username 
        : '$firstName $lastName'.trim();
    
    return User(
      id: userMap['id']?.toString() ?? '',
      email: userMap['email']?.toString() ?? '',
      name: name,
      role: _parseUserRole(userMap['role']?.toString()),
      avatarUrl: userMap['avatar_url'] ?? userMap['avatarUrl']?.toString(),
      createdAt: _parseDateTime(userMap['created_at'] ?? userMap['createdAt']),
      lastLoginAt: _parseDateTime(userMap['last_login'] ?? userMap['lastLoginAt']),
      isActive: userMap['is_active'] ?? userMap['isActive'] ?? true,
      projectIds: List<String>.from(userMap['project_ids'] ?? userMap['projectIds'] ?? []),
      preferences: Map<String, dynamic>.from(userMap['preferences'] ?? {}),
      emailVerified: userMap['email_verified'] ?? userMap['emailVerified'] ?? false,
      emailVerifiedAt: _parseDateTime(userMap['email_verified_at'] ?? userMap['emailVerifiedAt']),
    );
  }

  UserRole _parseUserRole(String? roleString) {
    if (roleString == null) return UserRole.teamMember;
    
    switch (roleString.toLowerCase()) {
      case 'admin':
      case 'systemadmin':
        return UserRole.systemAdmin;
      case 'deliverylead':
        return UserRole.deliveryLead;
      case 'teammember':
      case 'team member':
        return UserRole.teamMember;
      case 'clientreviewer':
      case 'client':
        return UserRole.clientReviewer;
      case 'manager':
        return UserRole.systemAdmin; // Map manager to systemAdmin
      default:
        return UserRole.teamMember;
    }
  }

  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is DateTime) return dateValue;
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Future<void> _saveUsersToStorage(List<User> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = users.map((user) => user.toJson()).toList();
      await prefs.setString('cached_users', jsonEncode(usersJson));
      await prefs.setString('users_last_fetch', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error saving users to storage: $e');
    }
  }

  Future<List<User>> _loadUsersFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('cached_users');
      if (usersJson != null) {
        final usersData = jsonDecode(usersJson) as List;
        return usersData.map((userData) => User.fromJson(userData)).toList();
      }
    } catch (e) {
      debugPrint('Error loading users from storage: $e');
    }
    return [];
  }
}

// Extension for User model to add toJson/fromJson methods
extension UserSerialization on User {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'projectIds': projectIds,
      'preferences': preferences,
      'emailVerified': emailVerified,
      'emailVerifiedAt': emailVerifiedAt?.toIso8601String(),
    };
  }

  static User fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: UserRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => UserRole.teamMember,
      ),
      avatarUrl: json['avatarUrl']?.toString(),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      lastLoginAt: json['lastLoginAt'] != null ? DateTime.parse(json['lastLoginAt']) : null,
      isActive: json['isActive'] ?? true,
      projectIds: List<String>.from(json['projectIds'] ?? []),
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
      emailVerified: json['emailVerified'] ?? false,
      emailVerifiedAt: json['emailVerifiedAt'] != null ? DateTime.parse(json['emailVerifiedAt']) : null,
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    List<String>? projectIds,
    Map<String, dynamic>? preferences,
    bool? emailVerified,
    DateTime? emailVerifiedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      projectIds: projectIds ?? this.projectIds,
      preferences: preferences ?? this.preferences,
      emailVerified: emailVerified ?? this.emailVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
    );
  }
}
