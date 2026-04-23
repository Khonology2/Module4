import 'package:flutter/material.dart';
import '../models/project.dart';

class ProjectAuditService {
  static Future<void> logProjectCreation(Project project, String createdBy) async {
    final auditData = {
      'action': 'project_created',
      'projectId': project.id,
      'projectName': project.name,
      'createdBy': createdBy,
      'timestamp': DateTime.now().toIso8601String(),
      'details': {
        'status': project.status.name,
        'priority': project.priority.name,
        'projectType': project.projectType,
        'clientName': project.clientName,
        'tags': project.tags,
        'startDate': project.startDate.toIso8601String(),
        'endDate': project.endDate?.toIso8601String(),
        'initialMemberCount': project.members.length,
        'initialDeliverableCount': project.deliverableIds.length,
        'initialSprintCount': project.sprintIds.length,
      },
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logProjectUpdate(Project project, String updatedBy, Map<String, dynamic> changes) async {
    final auditData = {
      'action': 'project_updated',
      'projectId': project.id,
      'projectName': project.name,
      'updatedBy': updatedBy,
      'timestamp': DateTime.now().toIso8601String(),
      'changes': changes,
      'currentStatus': {
        'status': project.status.name,
        'priority': project.priority.name,
        'memberCount': project.members.length,
        'deliverableCount': project.deliverableIds.length,
        'sprintCount': project.sprintIds.length,
      },
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logProjectDeletion(String projectId, String projectName, String deletedBy) async {
    final auditData = {
      'action': 'project_deleted',
      'projectId': projectId,
      'projectName': projectName,
      'deletedBy': deletedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logMemberAdded(String projectId, String projectName, ProjectMember member, String addedBy) async {
    final auditData = {
      'action': 'project_member_added',
      'projectId': projectId,
      'projectName': projectName,
      'memberId': member.userId,
      'memberName': member.userName,
      'memberEmail': member.userEmail,
      'memberRole': member.role.name,
      'addedBy': addedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logMemberRemoved(String projectId, String projectName, String memberId, String memberName, String removedBy) async {
    final auditData = {
      'action': 'project_member_removed',
      'projectId': projectId,
      'projectName': projectName,
      'memberId': memberId,
      'memberName': memberName,
      'removedBy': removedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logMemberRoleChanged(String projectId, String projectName, String memberId, String memberName, ProjectRole oldRole, ProjectRole newRole, String changedBy) async {
    final auditData = {
      'action': 'project_member_role_changed',
      'projectId': projectId,
      'projectName': projectName,
      'memberId': memberId,
      'memberName': memberName,
      'oldRole': oldRole.name,
      'newRole': newRole.name,
      'changedBy': changedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logDeliverableLinked(String projectId, String projectName, String deliverableId, String deliverableTitle, String linkedBy) async {
    final auditData = {
      'action': 'deliverable_linked_to_project',
      'projectId': projectId,
      'projectName': projectName,
      'deliverableId': deliverableId,
      'deliverableTitle': deliverableTitle,
      'linkedBy': linkedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logDeliverableUnlinked(String projectId, String projectName, String deliverableId, String deliverableTitle, String unlinkedBy) async {
    final auditData = {
      'action': 'deliverable_unlinked_from_project',
      'projectId': projectId,
      'projectName': projectName,
      'deliverableId': deliverableId,
      'deliverableTitle': deliverableTitle,
      'unlinkedBy': unlinkedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logSprintAssociated(String projectId, String projectName, String sprintId, String sprintName, String associatedBy) async {
    final auditData = {
      'action': 'sprint_associated_with_project',
      'projectId': projectId,
      'projectName': projectName,
      'sprintId': sprintId,
      'sprintName': sprintName,
      'associatedBy': associatedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logSprintDissociated(String projectId, String projectName, String sprintId, String sprintName, String dissociatedBy) async {
    final auditData = {
      'action': 'sprint_dissociated_from_project',
      'projectId': projectId,
      'projectName': projectName,
      'sprintId': sprintId,
      'sprintName': sprintName,
      'dissociatedBy': dissociatedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logStatusChanged(String projectId, String projectName, ProjectStatus oldStatus, ProjectStatus newStatus, String changedBy) async {
    final auditData = {
      'action': 'project_status_changed',
      'projectId': projectId,
      'projectName': projectName,
      'oldStatus': oldStatus.name,
      'newStatus': newStatus.name,
      'changedBy': changedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logPriorityChanged(String projectId, String projectName, ProjectPriority oldPriority, ProjectPriority newPriority, String changedBy) async {
    final auditData = {
      'action': 'project_priority_changed',
      'projectId': projectId,
      'projectName': projectName,
      'oldPriority': oldPriority.name,
      'newPriority': newPriority.name,
      'changedBy': changedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> logDatesChanged(String projectId, String projectName, DateTime? oldStartDate, DateTime? newStartDate, DateTime? oldEndDate, DateTime? newEndDate, String changedBy) async {
    final auditData = {
      'action': 'project_dates_changed',
      'projectId': projectId,
      'projectName': projectName,
      'oldStartDate': oldStartDate?.toIso8601String(),
      'newStartDate': newStartDate?.toIso8601String(),
      'oldEndDate': oldEndDate?.toIso8601String(),
      'newEndDate': newEndDate?.toIso8601String(),
      'changedBy': changedBy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _writeAuditLog(auditData);
  }

  static Future<void> _writeAuditLog(Map<String, dynamic> auditData) async {
    try {
      // In a real implementation, this would write to your audit log system
      // For now, we'll use debug logging as a placeholder
      debugPrint('Project Audit: ${auditData['action']} - ${auditData['projectName']} by ${auditData['updatedBy'] ?? auditData['createdBy'] ?? auditData['deletedBy'] ?? 'system'}');
      
      // Implementation: Write to database audit table
      // await ApiService.writeAuditLog(auditData);
      
    } catch (e) {
      debugPrint('Failed to write project audit log: $e');
      // Audit log failures should not crash the application
    }
  }

  static Future<List<Map<String, dynamic>>> getProjectAuditHistory(String projectId) async {
    try {
      // Implementation: Query audit logs for specific project
      debugPrint('Retrieving audit history for project: $projectId');
      
      // Example implementation:
      // final response = await ApiService.getProjectAuditLogs(projectId);
      // return response.isSuccess ? response.data : [];
      
      return [];
      
    } catch (e) {
      debugPrint('Failed to retrieve project audit history: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllProjectAuditHistory() async {
    try {
      // Implementation: Query all project audit logs
      debugPrint('Retrieving all project audit history');
      
      // Example implementation:
      // final response = await ApiService.getAllProjectAuditLogs();
      // return response.isSuccess ? response.data : [];
      
      return [];
      
    } catch (e) {
      debugPrint('Failed to retrieve all project audit history: $e');
      return [];
    }
  }
}
