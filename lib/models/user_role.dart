import 'package:flutter/material.dart';

enum UserRole {
  teamMember,
  deliveryLead,
  client,
  clientReviewer,
  systemAdmin,
  developer,
  projectManager,
  scrumMaster,
  qaEngineer,
  stakeholder,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.teamMember:
        return 'Team Member';
      case UserRole.deliveryLead:
        return 'Delivery Lead';
      case UserRole.client:
        return 'Client';
      case UserRole.clientReviewer:
        return 'Client Reviewer';
      case UserRole.systemAdmin:
        return 'System Admin';
      case UserRole.developer:
        return 'Developer';
      case UserRole.projectManager:
        return 'Project Manager';
      case UserRole.scrumMaster:
        return 'Scrum Master';
      case UserRole.qaEngineer:
        return 'QA Engineer';
      case UserRole.stakeholder:
        return 'Stakeholder';
    }
  }

  String get description {
    switch (this) {
      case UserRole.teamMember:
        return 'Can create deliverables and view own work';
      case UserRole.deliveryLead:
        return 'Can manage team and submit for client review';
      case UserRole.client:
        return 'Can review deliverables and submit client approvals';
      case UserRole.clientReviewer:
        return 'Can review and approve deliverables';
      case UserRole.systemAdmin:
        return 'Full system access and administration';
      case UserRole.developer:
        return 'Can develop and test features';
      case UserRole.projectManager:
        return 'Can manage projects and resources';
      case UserRole.scrumMaster:
        return 'Can facilitate agile processes';
      case UserRole.qaEngineer:
        return 'Can test and validate deliverables';
      case UserRole.stakeholder:
        return 'Can view project progress and provide feedback';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.teamMember:
        return Colors.blue;
      case UserRole.deliveryLead:
        return Colors.orange;
      case UserRole.client:
        return Colors.teal;
      case UserRole.clientReviewer:
        return Colors.green;
      case UserRole.systemAdmin:
        return Colors.purple;
      case UserRole.developer:
        return Colors.blue;
      case UserRole.projectManager:
        return Colors.orange;
      case UserRole.scrumMaster:
        return Colors.green;
      case UserRole.qaEngineer:
        return Colors.red;
      case UserRole.stakeholder:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.teamMember:
        return Icons.person;
      case UserRole.deliveryLead:
        return Icons.leaderboard;
      case UserRole.client:
        return Icons.handshake;
      case UserRole.clientReviewer:
        return Icons.verified_user;
      case UserRole.systemAdmin:
        return Icons.admin_panel_settings;
      case UserRole.developer:
        return Icons.code;
      case UserRole.projectManager:
        return Icons.work;
      case UserRole.scrumMaster:
        return Icons.group_work;
      case UserRole.qaEngineer:
        return Icons.bug_report;
      case UserRole.stakeholder:
        return Icons.business;
    }
  }
}

class Permission {
  final String name;
  final String description;
  final List<UserRole> allowedRoles;

  const Permission({
    required this.name,
    required this.description,
    required this.allowedRoles,
  });
}

class PermissionManager {
  static const Map<String, Permission> _permissions = {
    'create_deliverable': Permission(
      name: 'Create Deliverable',
      description: 'Create new deliverables',
      allowedRoles: [UserRole.teamMember, UserRole.deliveryLead, UserRole.systemAdmin, UserRole.developer, UserRole.projectManager, UserRole.scrumMaster, UserRole.qaEngineer],
    ),
    'create_sprint': Permission(
      name: 'Create Sprint',
      description: 'Create new sprints',
      allowedRoles: [UserRole.deliveryLead, UserRole.systemAdmin],
    ),
    'edit_deliverable': Permission(
      name: 'Edit Deliverable',
      description: 'Edit existing deliverables',
      allowedRoles: [UserRole.teamMember, UserRole.deliveryLead, UserRole.systemAdmin, UserRole.developer, UserRole.projectManager, UserRole.scrumMaster, UserRole.qaEngineer],
    ),
    'submit_for_review': Permission(
      name: 'Submit for Review',
      description: 'Submit deliverables for client review',
      allowedRoles: [UserRole.deliveryLead, UserRole.systemAdmin, UserRole.projectManager, UserRole.scrumMaster],
    ),
    'approve_deliverable': Permission(
      name: 'Approve Deliverable',
      description: 'Approve or reject deliverables',
      allowedRoles: [UserRole.clientReviewer, UserRole.systemAdmin, UserRole.stakeholder],
    ),
    'view_approvals': Permission(
      name: 'View Approvals',
      description: 'View approval requests and reminder status',
      allowedRoles: [UserRole.deliveryLead, UserRole.clientReviewer, UserRole.systemAdmin],
    ),
    'view_team_dashboard': Permission(
      name: 'View Team Dashboard',
      description: 'View team performance dashboard',
      allowedRoles: [UserRole.deliveryLead, UserRole.systemAdmin, UserRole.projectManager, UserRole.scrumMaster, UserRole.clientReviewer],
    ),
    'manage_sprints': Permission(
      name: 'Manage Sprints',
      description: 'Create and manage sprints, projects, and tickets',
      allowedRoles: [UserRole.deliveryLead, UserRole.systemAdmin],
    ),
    'view_client_review': Permission(
      name: 'View Client Review',
      description: 'Access client review interface',
      allowedRoles: [UserRole.deliveryLead, UserRole.clientReviewer, UserRole.client, UserRole.systemAdmin, UserRole.stakeholder],
    ),
    'manage_users': Permission(
      name: 'Manage Users',
      description: 'Manage user accounts and roles',
      allowedRoles: [UserRole.systemAdmin],
    ),
    'manage_projects': Permission(
      name: 'Manage Projects',
      description: 'Create and manage projects',
      allowedRoles: [UserRole.systemAdmin, UserRole.deliveryLead],
    ),
    'view_audit_logs': Permission(
      name: 'View Audit Logs',
      description: 'View system audit logs',
      allowedRoles: [UserRole.systemAdmin],
    ),
    'override_readiness_gate': Permission(
      name: 'Override Readiness Gate',
      description: 'Override release readiness gates',
      allowedRoles: [UserRole.deliveryLead, UserRole.systemAdmin],
    ),
    'view_all_deliverables': Permission(
      name: 'View All Deliverables',
      description: 'View all team deliverables',
      allowedRoles: [UserRole.deliveryLead, UserRole.systemAdmin, UserRole.clientReviewer, UserRole.developer, UserRole.projectManager, UserRole.scrumMaster, UserRole.qaEngineer, UserRole.stakeholder],
    ),
    'view_sprints': Permission(
      name: 'View Sprints',
      description: 'View sprint lists and boards',
      allowedRoles: [UserRole.teamMember, UserRole.deliveryLead, UserRole.client, UserRole.clientReviewer, UserRole.systemAdmin],
    ),
    'update_tickets': Permission(
      name: 'Update Tickets',
      description: 'Move ticket progress status',
      allowedRoles: [UserRole.teamMember, UserRole.deliveryLead, UserRole.systemAdmin],
    ),
    'update_sprint_status': Permission(
      name: 'Update Sprint Status',
      description: 'Change sprint progress status',
      allowedRoles: [UserRole.teamMember, UserRole.deliveryLead, UserRole.systemAdmin],
    ),
  };

  static bool hasPermission(UserRole userRole, String permissionName) {
    final permission = _permissions[permissionName];
    if (permission == null) return false;
    return permission.allowedRoles.contains(userRole);
  }

  static List<Permission> getPermissionsForRole(UserRole userRole) {
    return _permissions.values
        .where((permission) => permission.allowedRoles.contains(userRole))
        .toList();
  }

  static List<String> getPermissionNamesForRole(UserRole userRole) {
    return _permissions.entries
        .where((entry) => entry.value.allowedRoles.contains(userRole))
        .map((entry) => entry.key)
        .toList();
  }
}
