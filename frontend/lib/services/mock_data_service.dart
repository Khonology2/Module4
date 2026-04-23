import 'dart:math';

class MockDataService {
  static Map<String, dynamic> getDashboardData() {
    final random = Random();
    
    return {
      'totalRequests': random.nextInt(50) + 10,
      'pendingApproval': random.nextInt(10) + 1,
      'approved': random.nextInt(30) + 5,
      'rejected': random.nextInt(5),
      'totalDeliverables': random.nextInt(20) + 15,
      'inProgress': random.nextInt(8) + 2,
      'completed': random.nextInt(25) + 10,
      'pending': random.nextInt(5) + 1,
      'signOffReports': {
        'draft': random.nextInt(3) + 1,
        'submitted': random.nextInt(5) + 2,
        'approved': random.nextInt(8) + 3,
        'changeRequested': random.nextInt(2),
      },
      'recentActivity': [
        {
          'id': '1',
          'type': 'deliverable_submitted',
          'description': 'New deliverable submitted for review',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          'user': 'John Doe'
        },
        {
          'id': '2',
          'type': 'approval_granted',
          'description': 'Deliverable approved by client',
          'timestamp': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
          'user': 'Jane Smith'
        },
        {
          'id': '3',
          'type': 'sprint_completed',
          'description': 'Sprint 3 completed successfully',
          'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'user': 'Mike Johnson'
        },
      ],
      'teamMetrics': {
        'totalMembers': 12,
        'activeMembers': 8,
        'completedTasks': 45,
        'pendingTasks': 12,
        'averageCompletionTime': '2.5 days',
      },
      'performanceMetrics': {
        'onTimeDelivery': '85%',
        'clientSatisfaction': '4.2/5.0',
        'qualityScore': '92%',
        'reworkRate': '8%',
      },
    };
  }
  
  static List<Map<String, dynamic>> getRecentDeliverables() {
    return [
      {
        'id': '1',
        'title': 'Q4 Marketing Campaign Assets',
        'status': 'completed',
        'completionDate': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'assignedTo': 'John Doe',
        'priority': 'high',
      },
      {
        'id': '2',
        'title': 'Website Redesign Mockups',
        'status': 'in_progress',
        'dueDate': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
        'assignedTo': 'Jane Smith',
        'priority': 'medium',
      },
      {
        'id': '3',
        'title': 'Mobile App Wireframes',
        'status': 'pending_approval',
        'completionDate': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
        'assignedTo': 'Mike Johnson',
        'priority': 'low',
      },
    ];
  }
  
  static List<Map<String, dynamic>> getUpcomingDeadlines() {
    return [
      {
        'id': '1',
        'title': 'Q4 Campaign Assets - Client Review',
        'dueDate': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'priority': 'high',
        'type': 'milestone',
      },
      {
        'id': '2',
        'title': 'Sprint 4 Retrospective',
        'dueDate': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
        'priority': 'medium',
        'type': 'meeting',
      },
      {
        'id': '3',
        'title': 'Monthly Performance Report',
        'dueDate': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'priority': 'low',
        'type': 'report',
      },
    ];
  }
}
