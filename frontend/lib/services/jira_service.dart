import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class JiraService {
  String? _apiToken;
  String? _email;
  String? _domain;
  String? _userId; // Add user ID for backend proxy

  // Initialize Jira service with credentials
  void initialize({
    required String domain,
    required String email,
    required String apiToken,
    String? userId,
  }) {
    _domain = domain;
    _email = email;
    _apiToken = apiToken;
    _userId = userId;
  }

  // Check if service is initialized
  bool get isInitialized => _domain != null && _email != null && _apiToken != null;

  // Get backend proxy URL for API calls (instead of direct Jira API)
  String get _proxyBaseUrl => 'https://flow-space.onrender.com/api/jira';

  // Get standard headers for proxy requests
  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // Test connection to Jira via backend proxy
  Future<bool> testConnection() async {
    try {
      if (!isInitialized) {
        debugPrint('❌ Jira service not initialized');
        return false;
      }

      // First, save credentials to backend
      await _saveCredentials();

      // Test connection via backend proxy
      final response = await http.post(
        Uri.parse('$_proxyBaseUrl/test-connection'),
        headers: _headers,
        body: jsonEncode({
          'domain': _domain,
          'email': _email,
          'apiToken': _apiToken,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Jira connection successful via backend proxy');
          return true;
        } else {
          debugPrint('❌ Jira connection failed: ${data['error']}');
          return false;
        }
      } else {
        debugPrint('❌ Jira connection failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Jira connection error: $e');
      return false;
    }
  }

  // Save credentials to backend
  Future<void> _saveCredentials() async {
    if (_userId == null) {
      debugPrint('⚠️ User ID not provided, skipping credential save');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_proxyBaseUrl/credentials'),
        headers: _headers,
        body: jsonEncode({
          'userId': _userId,
          'domain': _domain,
          'email': _email,
          'apiToken': _apiToken,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Jira credentials saved to backend');
      } else {
        debugPrint('⚠️ Failed to save Jira credentials: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Error saving Jira credentials: $e');
    }
  }

  // Get all projects via backend proxy
  Future<List<JiraProject>> getProjects() async {
    try {
      if (_userId == null) {
        debugPrint('❌ User ID required for backend proxy');
        return [];
      }

      final response = await http.get(
        Uri.parse('$_proxyBaseUrl/projects?userId=$_userId'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> projectsJson = data['data'];
          return projectsJson.map((json) => JiraProject.fromJson(json)).toList();
        } else {
          debugPrint('❌ Failed to fetch projects: ${data['error']}');
          return [];
        }
      } else {
        debugPrint('❌ Failed to fetch projects: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching projects: $e');
      return [];
    }
  }

  // Get project by key via backend proxy
  Future<JiraProject> getProject(String projectKey) async {
    try {
      if (_userId == null) {
        throw Exception('User ID required for backend proxy');
      }

      final response = await http.get(
        Uri.parse('$_proxyBaseUrl/projects?userId=$_userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> projectsJson = data['data'];
          final project = projectsJson.firstWhere(
            (p) => p['key'] == projectKey,
            orElse: () => throw Exception('Project not found'),
          );
          return JiraProject.fromJson(project);
        } else {
          throw Exception('Failed to fetch project: ${data['error']}');
        }
      } else {
        throw Exception('Failed to fetch project: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching project: $e');
      rethrow;
    }
  }

  // Get all boards for a project via backend proxy
  Future<List<JiraBoard>> getBoards({String? projectKey}) async {
    try {
      if (_userId == null) {
        debugPrint('❌ User ID required for backend proxy');
        return [];
      }

      String url = '$_proxyBaseUrl/boards?userId=$_userId';
      if (projectKey != null) {
        url += '&projectKey=$projectKey';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> boardsJson = data['data'];
          return boardsJson.map((json) => JiraBoard.fromJson(json)).toList();
        } else {
          debugPrint('❌ Failed to fetch boards: ${data['error']}');
          return [];
        }
      } else {
        debugPrint('❌ Failed to fetch boards: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching boards: $e');
      return [];
    }
  }

  // Get sprints for a board via backend proxy
  Future<List<JiraSprint>> getSprints(int boardId) async {
    try {
      if (_userId == null) {
        debugPrint('❌ User ID required for backend proxy');
        return [];
      }

      final response = await http.get(
        Uri.parse('$_proxyBaseUrl/sprints?userId=$_userId&boardId=$boardId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> sprintsJson = data['data'];
          return sprintsJson.map((json) => JiraSprint.fromJson(json)).toList();
        } else {
          debugPrint('❌ Failed to fetch sprints: ${data['error']}');
          return [];
        }
      } else {
        debugPrint('❌ Failed to fetch sprints: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching sprints: $e');
      return [];
    }
  }

  // Create a new sprint via backend proxy
  Future<JiraSprint> createSprint({
    required String name,
    required int boardId,
    String? goal,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (_userId == null) {
        throw Exception('User ID required for backend proxy');
      }

      final body = {
        'userId': _userId,
        'boardId': boardId,
        'name': name,
        if (goal != null) 'goal': goal,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$_proxyBaseUrl/create-sprint'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return JiraSprint.fromJson(data['data']);
        } else {
          throw Exception('Failed to create sprint: ${data['error']}');
        }
      } else {
        throw Exception('Failed to create sprint: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error creating sprint: $e');
      rethrow;
    }
  }

  // Get issues for a sprint via backend proxy
  Future<List<JiraIssue>> getSprintIssues(int sprintId) async {
    try {
      if (_userId == null) {
        debugPrint('❌ User ID required for backend proxy');
        return [];
      }

      final response = await http.get(
        Uri.parse('$_proxyBaseUrl/sprint-issues?userId=$_userId&sprintId=$sprintId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> issuesJson = data['data'];
          return issuesJson.map((json) => JiraIssue.fromJson(json)).toList();
        } else {
          debugPrint('❌ Failed to fetch sprint issues: ${data['error']}');
          return [];
        }
      } else {
        debugPrint('❌ Failed to fetch sprint issues: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching sprint issues: $e');
      return [];
    }
  }

  // Add issues to sprint via backend proxy
  Future<void> addIssuesToSprint(int sprintId, List<String> issueKeys) async {
    try {
      if (_userId == null) {
        throw Exception('User ID required for backend proxy');
      }

      final body = {
        'userId': _userId,
        'sprintId': sprintId,
        'issues': issueKeys,
      };

      final response = await http.post(
        Uri.parse('$_proxyBaseUrl/add-issues-to-sprint'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] != true) {
          throw Exception('Failed to add issues to sprint: ${data['error']}');
        }
      } else {
        throw Exception('Failed to add issues to sprint: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error adding issues to sprint: $e');
      rethrow;
    }
  }

  // Get users in a project via backend proxy
  Future<List<JiraUser>> getProjectUsers(String projectKey) async {
    try {
      if (_userId == null) {
        debugPrint('❌ User ID required for backend proxy');
        return [];
      }

      final response = await http.get(
        Uri.parse('$_proxyBaseUrl/project-users?userId=$_userId&projectKey=$projectKey'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> usersJson = data['data'];
          return usersJson.map((json) => JiraUser.fromJson(json)).toList();
        } else {
          debugPrint('❌ Failed to fetch project users: ${data['error']}');
          return [];
        }
      } else {
        debugPrint('❌ Failed to fetch project users: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching project users: $e');
      return [];
    }
  }

  // Search for issues via backend proxy
  Future<List<JiraIssue>> searchIssues({
    String? projectKey,
    String? assignee,
    String? status,
    int maxResults = 50,
  }) async {
    try {
      if (_userId == null) {
        debugPrint('❌ User ID required for backend proxy');
        return [];
      }

      String jql = '';
      if (projectKey != null) jql += 'project = $projectKey';
      if (assignee != null) jql += ' AND assignee = $assignee';
      if (status != null) jql += ' AND status = "$status"';

      final response = await http.get(
        Uri.parse('$_proxyBaseUrl/search-issues?userId=$_userId&jql=${Uri.encodeComponent(jql)}&maxResults=$maxResults'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> issuesJson = data['data'];
          return issuesJson.map((json) => JiraIssue.fromJson(json)).toList();
        } else {
          debugPrint('❌ Failed to search issues: ${data['error']}');
          return [];
        }
      } else {
        debugPrint('❌ Failed to search issues: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error searching issues: $e');
      return [];
    }
  }

  // Get issue transitions via backend proxy
  Future<List<JiraTransition>> getIssueTransitions(String issueKey) async {
    try {
      if (_userId == null) {
        debugPrint('❌ User ID required for backend proxy');
        return [];
      }

      final response = await http.get(
        Uri.parse('$_proxyBaseUrl/issue-transitions?userId=$_userId&issueKey=$issueKey'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> transitionsJson = data['data'];
          return transitionsJson.map((json) => JiraTransition.fromJson(json)).toList();
        } else {
          debugPrint('❌ Failed to fetch issue transitions: ${data['error']}');
          return [];
        }
      } else {
        debugPrint('❌ Failed to fetch issue transitions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching issue transitions: $e');
      return [];
    }
  }

  // Transition issue via backend proxy
  Future<bool> transitionIssue({
    required String issueKey,
    required String transitionId,
    String? comment,
  }) async {
    try {
      if (_userId == null) {
        debugPrint('❌ User ID required for backend proxy');
        return false;
      }

      final body = {
        'userId': _userId,
        'issueKey': issueKey,
        'transitionId': transitionId,
        if (comment != null) 'comment': comment,
      };

      final response = await http.post(
        Uri.parse('$_proxyBaseUrl/transition-issue'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Issue transitioned successfully');
          return true;
        } else {
          debugPrint('❌ Failed to transition issue: ${data['error']}');
          return false;
        }
      } else {
        debugPrint('❌ Failed to transition issue: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error transitioning issue: $e');
      return false;
    }
  }
}

// Jira Data Models
class JiraProject {
  final String id;
  final String key;
  final String name;
  final String? description;
  final String? projectTypeKey;
  final String? leadAccountId;

  JiraProject({
    required this.id,
    required this.key,
    required this.name,
    this.description,
    this.projectTypeKey,
    this.leadAccountId,
  });

  factory JiraProject.fromJson(Map<String, dynamic> json) {
    return JiraProject(
      id: json['id'] ?? '',
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      projectTypeKey: json['projectTypeKey'],
      leadAccountId: json['lead']?['accountId'],
    );
  }
}

class JiraBoard {
  final int id;
  final String name;
  final String type;
  final String? locationName;
  final String? projectKey;

  JiraBoard({
    required this.id,
    required this.name,
    required this.type,
    this.locationName,
    this.projectKey,
  });

  factory JiraBoard.fromJson(Map<String, dynamic> json) {
    return JiraBoard(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      locationName: json['location']?['name'],
      projectKey: json['location']?['projectKey'],
    );
  }
}

class JiraSprint {
  final int id;
  final String name;
  final String state;
  final String? goal;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? completeDate;
  final int? originBoardId;

  JiraSprint({
    required this.id,
    required this.name,
    required this.state,
    this.goal,
    this.startDate,
    this.endDate,
    this.completeDate,
    this.originBoardId,
  });

  factory JiraSprint.fromJson(Map<String, dynamic> json) {
    return JiraSprint(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      state: json['state'] ?? '',
      goal: json['goal'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      completeDate: json['completeDate'] != null ? DateTime.parse(json['completeDate']) : null,
      originBoardId: json['originBoardId'],
    );
  }
}

class JiraIssue {
  final String id;
  final String key;
  final String summary;
  final String? description;
  final String? status;
  final String? priority;
  final String? issueType;
  final String? assignee;
  final String? reporter;
  final DateTime? created;
  final DateTime? updated;
  final List<String>? labels;

  JiraIssue({
    required this.id,
    required this.key,
    required this.summary,
    this.description,
    this.status,
    this.priority,
    this.issueType,
    this.assignee,
    this.reporter,
    this.created,
    this.updated,
    this.labels,
  });

  factory JiraIssue.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'] ?? {};
    return JiraIssue(
      id: json['id'] ?? '',
      key: json['key'] ?? '',
      summary: fields['summary'] ?? '',
      description: fields['description'],
      status: fields['status']?['name'],
      priority: fields['priority']?['name'],
      issueType: fields['issuetype']?['name'],
      assignee: fields['assignee']?['displayName'],
      reporter: fields['reporter']?['displayName'],
      created: fields['created'] != null ? DateTime.parse(fields['created']) : null,
      updated: fields['updated'] != null ? DateTime.parse(fields['updated']) : null,
      labels: fields['labels']?.cast<String>(),
    );
  }
}

class JiraUser {
  final String accountId;
  final String displayName;
  final String? emailAddress;
  final String? avatarUrl;

  JiraUser({
    required this.accountId,
    required this.displayName,
    this.emailAddress,
    this.avatarUrl,
  });

  factory JiraUser.fromJson(Map<String, dynamic> json) {
    return JiraUser(
      accountId: json['accountId'] ?? '',
      displayName: json['displayName'] ?? '',
      emailAddress: json['emailAddress'],
      avatarUrl: json['avatarUrls']?['48x48'],
    );
  }
}

class JiraTransition {
  final String id;
  final String name;
  final String toStatus;

  const JiraTransition({
    required this.id,
    required this.name,
    required this.toStatus,
  });

  factory JiraTransition.fromJson(Map<String, dynamic> json) {
    return JiraTransition(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      toStatus: json['to']?['name'] ?? '',
    );
  }
}
