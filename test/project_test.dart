import 'package:flutter_test/flutter_test.dart';
import 'package:khono/models/project.dart';

void main() {
  group('Project Model Tests', () {
    test('Project should create with required fields', () {
      final project = Project(
        id: 'test-project-1',
        name: 'Test Project',
        key: 'TEST',
        description: 'A test project for unit testing',
        status: ProjectStatus.planning,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(project.id, 'test-project-1');
      expect(project.name, 'Test Project');
      expect(project.description, 'A test project for unit testing');
      expect(project.status, ProjectStatus.planning);
      expect(project.priority, ProjectPriority.medium);
      expect(project.projectType, 'software');
      expect(project.members.isEmpty, true);
      expect(project.deliverableIds.isEmpty, true);
      expect(project.sprintIds.isEmpty, true);
    });

    test('Project should copy with updated values', () {
      final originalProject = Project(
        id: 'test-project-1',
        name: 'Test Project',
        key: 'TEST',
        description: 'A test project',
        status: ProjectStatus.planning,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      final updatedProject = originalProject.copyWith(
        name: 'Updated Project',
        status: ProjectStatus.active,
        priority: ProjectPriority.high,
      );

      expect(updatedProject.id, originalProject.id);
      expect(updatedProject.name, 'Updated Project');
      expect(updatedProject.description, originalProject.description);
      expect(updatedProject.status, ProjectStatus.active);
      expect(updatedProject.priority, ProjectPriority.high);
      expect(updatedProject.projectType, originalProject.projectType);
    });

    test('Project should convert to and from JSON', () {
      final originalProject = Project(
        id: 'test-project-1',
        name: 'Test Project',
        key: 'TEST',
        description: 'A test project',
        clientName: 'Test Client',
        status: ProjectStatus.active,
        priority: ProjectPriority.high,
        projectType: 'software',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 12, 31),
        tags: ['mobile', 'flutter'],
        members: [
          ProjectMember(
            userId: 'user-1',
            userName: 'John Doe',
            userEmail: 'john@example.com',
            role: ProjectRole.owner,
            assignedAt: DateTime.now(),
          ),
        ],
        deliverableIds: ['deliverable-1'],
        sprintIds: ['sprint-1'],
        createdBy: 'user-1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        updatedBy: 'user-1',
      );

      final json = originalProject.toJson();
      final deserializedProject = Project.fromJson(json);

      expect(deserializedProject.id, originalProject.id);
      expect(deserializedProject.name, originalProject.name);
      expect(deserializedProject.description, originalProject.description);
      expect(deserializedProject.clientName, originalProject.clientName);
      expect(deserializedProject.status, originalProject.status);
      expect(deserializedProject.priority, originalProject.priority);
      expect(deserializedProject.projectType, originalProject.projectType);
      expect(deserializedProject.tags, originalProject.tags);
      expect(deserializedProject.members.length, originalProject.members.length);
      expect(deserializedProject.deliverableIds, originalProject.deliverableIds);
      expect(deserializedProject.sprintIds, originalProject.sprintIds);
    });

    test('Project status display names should be correct', () {
      final project = Project(
        id: 'test-project',
        name: 'Test Project',
        key: 'TEST',
        description: 'A test project',
        status: ProjectStatus.planning,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(project.statusDisplayName, 'Planning');
      
      final activeProject = project.copyWith(status: ProjectStatus.active);
      expect(activeProject.statusDisplayName, 'Active');
      
      final onHoldProject = project.copyWith(status: ProjectStatus.onHold);
      expect(onHoldProject.statusDisplayName, 'On Hold');
      
      final completedProject = project.copyWith(status: ProjectStatus.completed);
      expect(completedProject.statusDisplayName, 'Completed');
      
      final cancelledProject = project.copyWith(status: ProjectStatus.cancelled);
      expect(cancelledProject.statusDisplayName, 'Cancelled');
    });

    test('Project priority display names should be correct', () {
      final project = Project(
        id: 'test-project',
        name: 'Test Project',
        key: 'TEST',
        description: 'A test project',
        status: ProjectStatus.planning,
        priority: ProjectPriority.low,
        projectType: 'software',
        startDate: DateTime.now(),
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(project.priorityDisplayName, 'Low');
      
      final mediumProject = project.copyWith(priority: ProjectPriority.medium);
      expect(mediumProject.priorityDisplayName, 'Medium');
      
      final highProject = project.copyWith(priority: ProjectPriority.high);
      expect(highProject.priorityDisplayName, 'High');
      
      final criticalProject = project.copyWith(priority: ProjectPriority.critical);
      expect(criticalProject.priorityDisplayName, 'Critical');
    });

    test('Project should correctly identify overdue projects', () {
      final overdueProject = Project(
        id: 'overdue-project',
        name: 'Overdue Project',
        key: 'OVERDUE',
        description: 'This project is overdue',
        status: ProjectStatus.active,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        createdBy: 'user-1',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      final notOverdueProject = Project(
        id: 'not-overdue-project',
        name: 'Not Overdue Project',
        key: 'NOTOVERDUE',
        description: 'This project is not overdue',
        status: ProjectStatus.active,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      final completedProject = Project(
        id: 'completed-project',
        name: 'Completed Project',
        key: 'COMPLETED',
        description: 'This project is completed',
        status: ProjectStatus.completed,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        createdBy: 'user-1',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      expect(overdueProject.isOverdue, true);
      expect(notOverdueProject.isOverdue, false);
      expect(completedProject.isOverdue, false);
    });

    test('Project should correctly calculate days until end', () {
      final futureProject = Project(
        id: 'future-project',
        name: 'Future Project',
        key: 'FUTURE',
        description: 'This project ends in the future',
        status: ProjectStatus.active,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 10)),
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      final noEndDateProject = Project(
        id: 'no-end-date-project',
        name: 'No End Date Project',
        key: 'NOENDDATE',
        description: 'This project has no end date',
        status: ProjectStatus.active,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(futureProject.daysUntilEnd, 10);
      expect(noEndDateProject.daysUntilEnd, -1);
    });

    test('Project should correctly identify active projects', () {
      final activeProject = Project(
        id: 'active-project',
        name: 'Active Project',
        key: 'ACTIVE',
        description: 'This project is active',
        status: ProjectStatus.active,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      final planningProject = Project(
        id: 'planning-project',
        name: 'Planning Project',
        key: 'PLANNING',
        description: 'This project is in planning',
        status: ProjectStatus.planning,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      expect(activeProject.isActive, true);
      expect(planningProject.isActive, false);
    });

    test('Project should correctly manage members', () {
      final owner = ProjectMember(
        userId: 'owner-1',
        userName: 'Owner User',
        userEmail: 'owner@example.com',
        role: ProjectRole.owner,
        assignedAt: DateTime.now(),
      );

      final contributor = ProjectMember(
        userId: 'contributor-1',
        userName: 'Contributor User',
        userEmail: 'contributor@example.com',
        role: ProjectRole.contributor,
        assignedAt: DateTime.now(),
      );

      final viewer = ProjectMember(
        userId: 'viewer-1',
        userName: 'Viewer User',
        userEmail: 'viewer@example.com',
        role: ProjectRole.viewer,
        assignedAt: DateTime.now(),
      );

      final project = Project(
        id: 'test-project',
        name: 'Test Project',
        key: 'TEST',
        description: 'A test project',
        status: ProjectStatus.active,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        createdBy: 'owner-1',
        createdAt: DateTime.now(),
        members: [owner, contributor, viewer],
      );

      expect(project.totalMembers, 3);
      expect(project.owners.length, 1);
      expect(project.contributors.length, 1);
      expect(project.viewers.length, 1);
      expect(project.hasMember('owner-1'), true);
      expect(project.hasMember('nonexistent-user'), false);
      expect(project.getMember('owner-1')?.userName, 'Owner User');
      expect(project.getMember('nonexistent-user'), null);
    });

    test('Project should generate audit metadata', () {
      final project = Project(
        id: 'test-project',
        name: 'Test Project',
        key: 'TEST',
        description: 'A test project',
        status: ProjectStatus.active,
        priority: ProjectPriority.high,
        projectType: 'software',
        startDate: DateTime.now(),
        members: [
          ProjectMember(
            userId: 'user-1',
            userName: 'Test User',
            userEmail: 'test@example.com',
            role: ProjectRole.owner,
            assignedAt: DateTime.now(),
          ),
        ],
        deliverableIds: ['deliverable-1', 'deliverable-2'],
        sprintIds: ['sprint-1'],
        createdBy: 'user-1',
        createdAt: DateTime.now(),
      );

      final auditMetadata = project.auditMetadata;

      expect(auditMetadata['projectId'], 'test-project');
      expect(auditMetadata['projectName'], 'Test Project');
      expect(auditMetadata['action'], 'project_updated');
      expect(auditMetadata['memberCount'], 1);
      expect(auditMetadata['deliverableCount'], 2);
      expect(auditMetadata['sprintCount'], 1);
      expect(auditMetadata['status'], 'active');
      expect(auditMetadata['priority'], 'high');
      expect(auditMetadata.containsKey('timestamp'), true);
    });

    test('ProjectMember should convert to and from JSON', () {
      final originalMember = ProjectMember(
        userId: 'user-1',
        userName: 'John Doe',
        userEmail: 'john@example.com',
        role: ProjectRole.contributor,
        assignedAt: DateTime(2024, 1, 1),
      );

      final json = originalMember.toJson();
      final deserializedMember = ProjectMember.fromJson(json);

      expect(deserializedMember.userId, originalMember.userId);
      expect(deserializedMember.userName, originalMember.userName);
      expect(deserializedMember.userEmail, originalMember.userEmail);
      expect(deserializedMember.role, originalMember.role);
      expect(deserializedMember.assignedAt, originalMember.assignedAt);
    });
  });
}
