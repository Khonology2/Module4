import 'package:flutter_test/flutter_test.dart';
import 'package:khono/models/approval_request.dart';

void main() {
  group('ApprovalRequest model', () {
    test('fromJson maps fields and computed getters', () {
      final json = {
        'id': '123',
        'title': 'Security Review',
        'description': 'Please review the security changes',
        'requested_by': 'u1',
        'requested_by_name': 'Jane Doe',
        'requested_at': '2024-10-10T00:00:00Z',
        'status': 'pending',
        'priority': 'high',
        'category': 'Security',
      };

      final r = ApprovalRequest.fromJson(json);

      expect(r.id, '123');
      expect(r.title, 'Security Review');
      expect(r.description, 'Please review the security changes');
      expect(r.requestedByName, 'Jane Doe');
      expect(r.status, 'pending');
      expect(r.priority, 'high');
      expect(r.category, 'Security');

      expect(r.statusDisplay, 'PENDING');
      expect(r.priorityDisplay, 'High');
      expect(r.isPending, true);
      expect(r.isApproved, false);
    });

    test('statusDisplay falls back to uppercase for unknown', () {
      final r = ApprovalRequest(
        id: '1',
        title: 'Unknown',
        description: 'Desc',
        requestedBy: 'u',
        requestedByName: 'User',
        requestedAt: DateTime.now(),
        status: 'custom_status',
        priority: 'low',
        category: 'General',
      );
      expect(r.statusDisplay, 'CUSTOM_STATUS');
    });

    test('screen cast to typed list works', () {
      final r1 = ApprovalRequest(
        id: '1',
        title: 'A',
        description: 'D',
        requestedBy: 'u',
        requestedByName: 'User',
        requestedAt: DateTime.now(),
        status: 'approved',
        priority: 'medium',
        category: 'Database',
      );
      final r2 = ApprovalRequest(
        id: '2',
        title: 'B',
        description: 'E',
        requestedBy: 'u',
        requestedByName: 'User2',
        requestedAt: DateTime.now(),
        status: 'pending',
        priority: 'urgent',
        category: 'Security',
      );

      final data = {'requests': [r1, r2]};
      final typed = (data['requests'] as List).cast<ApprovalRequest>();
      expect(typed.length, 2);
      expect(typed.first.title, 'A');
      expect(typed.last.isPending, true);
    });
  });
}
