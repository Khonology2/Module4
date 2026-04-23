import 'package:flutter_test/flutter_test.dart';
import 'package:khono/models/project.dart';
import 'package:khono/test_helpers/project_setup_test_helper.dart';

void main() {
  group('Project Validation Tests', () {
    late TestableProjectSetupScreen setupScreen;

    setUp(() {
      setupScreen = TestableProjectSetupScreen();
    });

    test('Project name validation - empty string', () {
      final result = setupScreen.validateField('name', '');
      expect(result, 'Project name is required');
    });

    test('Project name validation - too short', () {
      final result = setupScreen.validateField('name', 'ab');
      expect(result, 'Project name must be at least 3 characters');
    });

    test('Project name validation - too long', () {
      final result = setupScreen.validateField('name', 'a' * 101);
      expect(result, 'Project name must not exceed 100 characters');
    });

    test('Project name validation - invalid characters', () {
      final result = setupScreen.validateField('name', 'Project@Name');
      expect(result, 'Project name can only contain letters, numbers, spaces, hyphens, and underscores');
    });

    test('Project name validation - valid', () {
      final result = setupScreen.validateField('name', 'Valid Project Name-123');
      expect(result, null);
    });

    test('Project key validation - empty string', () {
      final result = setupScreen.validateField('key', '');
      expect(result, 'Project key is required');
    });

    test('Project key validation - too short', () {
      final result = setupScreen.validateField('key', 'a');
      expect(result, 'Project key must be at least 2 characters');
    });

    test('Project key validation - too long', () {
      final result = setupScreen.validateField('key', 'A' * 21);
      expect(result, 'Project key must not exceed 20 characters');
    });

    test('Project key validation - invalid format', () {
      final result = setupScreen.validateField('key', 'invalid-key');
      expect(result, 'Project key must start with letter and contain only uppercase letters, numbers, and underscores');
    });

    test('Project key validation - valid', () {
      final result = setupScreen.validateField('key', 'VALID_KEY_123');
      expect(result, null);
    });

    test('Description validation - empty string', () {
      final result = setupScreen.validateField('description', '');
      expect(result, 'Description is required');
    });

    test('Description validation - too short', () {
      final result = setupScreen.validateField('description', 'Short');
      expect(result, 'Description must be at least 10 characters');
    });

    test('Description validation - too long', () {
      final result = setupScreen.validateField('description', 'a' * 1001);
      expect(result, 'Description must not exceed 1000 characters');
    });

    test('Description validation - valid', () {
      final result = setupScreen.validateField('description', 'This is a valid project description');
      expect(result, null);
    });

    test('Client name validation - empty string', () {
      final result = setupScreen.validateField('clientName', '');
      expect(result, 'Client name is required');
    });

    test('Client name validation - too short', () {
      final result = setupScreen.validateField('clientName', 'a');
      expect(result, 'Client name must be at least 2 characters');
    });

    test('Client name validation - too long', () {
      final result = setupScreen.validateField('clientName', 'a' * 101);
      expect(result, 'Client name must not exceed 100 characters');
    });

    test('Client name validation - valid', () {
      final result = setupScreen.validateField('clientName', 'Valid Client Name');
      expect(result, null);
    });
  });

  group('Project Model Tests', () {
    test('Project should create with required fields', () {
      final project = Project(
        id: '1',
        name: 'Test Project',
        key: 'TEST',
        description: 'Test Description',
        clientName: 'Test Client',
        status: ProjectStatus.planning,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        createdBy: 'user1',
        createdAt: DateTime.now(),
      );

      expect(project.name, 'Test Project');
      expect(project.description, 'Test Description');
      expect(project.clientName, 'Test Client');
      expect(project.projectType, 'software');
      expect(project.status, ProjectStatus.planning);
      expect(project.priority, ProjectPriority.medium);
    });

    test('Project should serialize to JSON correctly', () {
      final project = Project(
        id: '1',
        name: 'Test Project',
        key: 'TEST',
        description: 'Test Description',
        clientName: 'Test Client',
        status: ProjectStatus.planning,
        priority: ProjectPriority.medium,
        projectType: 'software',
        startDate: DateTime.now(),
        createdBy: 'user1',
        createdAt: DateTime.now(),
      );

      final json = project.toJson();
      expect(json['name'], 'Test Project');
      expect(json['description'], 'Test Description');
      expect(json['clientName'], 'Test Client');
      expect(json['projectType'], 'software');
      expect(json['status'], 'planning');
      expect(json['priority'], 'medium');
    });

    test('Project should deserialize from JSON correctly', () {
      final json = {
        'id': '1',
        'name': 'Test Project',
        'description': 'Test Description',
        'clientName': 'Test Client',
        'status': 'planning',
        'priority': 'medium',
        'projectType': 'software',
        'startDate': DateTime.now().toIso8601String(),
        'createdBy': 'user1',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final project = Project.fromJson(json);
      expect(project.name, 'Test Project');
      expect(project.description, 'Test Description');
      expect(project.clientName, 'Test Client');
      expect(project.projectType, 'software');
      expect(project.status, ProjectStatus.planning);
      expect(project.priority, ProjectPriority.medium);
    });

    test('Project status enum values', () {
      expect(ProjectStatus.planning.name, 'planning');
      expect(ProjectStatus.active.name, 'active');
      expect(ProjectStatus.onHold.name, 'onHold');
      expect(ProjectStatus.completed.name, 'completed');
      expect(ProjectStatus.cancelled.name, 'cancelled');
    });

    test('Project priority enum values', () {
      expect(ProjectPriority.low.name, 'low');
      expect(ProjectPriority.medium.name, 'medium');
      expect(ProjectPriority.high.name, 'high');
      expect(ProjectPriority.critical.name, 'critical');
    });
  });

  group('Project Type Tests', () {
    test('Project types should include expected values', () {
      final types = ['software', 'hardware', 'consulting', 'research', 'marketing', 'infrastructure', 'other'];
      expect(types.contains('software'), true);
      expect(types.contains('hardware'), true);
      expect(types.contains('consulting'), true);
      expect(types.contains('research'), true);
      expect(types.contains('marketing'), true);
      expect(types.contains('infrastructure'), true);
      expect(types.contains('other'), true);
      expect(types.length, 7);
    });
  });
}
