// Enhanced Project model with fallback values for missing database columns
// This file provides temporary fixes while database migration is pending

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';

extension ProjectExtensions on Project {
  // Enhanced getters with fallbacks for missing database data
  String get displayName {
    if (name.isNotEmpty && name != 'Unknown') return name;
    return 'Project ${key.isNotEmpty ? key : 'Untitled'}';
  }
  
  String get displayClientName {
    if (clientName != null && clientName!.isNotEmpty) return clientName!;
    return 'Internal Client';
  }
  
  String get displayProjectType {
    if (projectType.isNotEmpty && projectType != 'Unknown') return projectType;
    return 'software';
  }
  
  DateTime get displayStartDate {
    return startDate;
  }
  
  DateTime? get displayEndDate {
    if (endDate != null) return endDate;
    // Calculate fallback end date (3 months from start)
    return displayStartDate.add(const Duration(days: 90));
  }
  
  String get formattedStartDate {
    return DateFormat('d MMM yyyy').format(displayStartDate);
  }
  
  String get formattedEndDate {
    final end = displayEndDate;
    if (end != null) {
      return DateFormat('d MMM yyyy').format(end);
    }
    return 'Not set';
  }
  
  String get durationText {
    final start = displayStartDate;
    final end = displayEndDate;
    if (end != null) {
      final days = end.difference(start).inDays;
      return '$days days';
    }
    return 'Ongoing';
  }
  
  // Enhanced member handling
  List<ProjectMember> get displayMembers {
    if (members.isNotEmpty) return members;
    
    // Fallback mock members when database doesn't have real members
    return [
      ProjectMember(
        userId: ownerId ?? 'unknown',
        userName: 'Project Owner',
        userEmail: 'owner@company.com',
        role: ProjectRole.owner,
        assignedAt: createdAt,
      ),
    ];
  }
  
  int get memberCount => displayMembers.length;
  
  // Enhanced status display
  String get statusDisplay {
    switch (status) {
      case ProjectStatus.planning:
        return 'Planning';
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.onHold:
        return 'On Hold';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.cancelled:
        return 'Cancelled';
    }
  }
  
  Color get statusColor {
    switch (status) {
      case ProjectStatus.planning:
        return Colors.blue;
      case ProjectStatus.active:
        return Colors.green;
      case ProjectStatus.onHold:
        return Colors.orange;
      case ProjectStatus.completed:
        return Colors.purple;
      case ProjectStatus.cancelled:
        return Colors.red;
    }
  }
}

// Helper widget for displaying project information with fallbacks
class ProjectInfoWidget extends StatelessWidget {
  final Project project;
  
  const ProjectInfoWidget({super.key, required this.project});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          project.displayName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          project.description.isNotEmpty ? project.description : 'No description available',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Client', project.displayClientName),
        _buildInfoRow('Type', project.displayProjectType),
        _buildInfoRow('Status', project.statusDisplay),
        _buildInfoRow('Duration', project.durationText),
        _buildInfoRow('Members', '${project.memberCount}'),
        const SizedBox(height: 16),
        _buildDateSection(),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
  
  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Project Timeline',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildDateRow('Start Date', project.formattedStartDate),
        _buildDateRow('End Date', project.formattedEndDate),
      ],
    );
  }
  
  Widget _buildDateRow(String label, String value) {
    final isNotSet = value == 'Not set';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            children: [
              if (isNotSet) ...[
                const Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: TextStyle(
                  color: isNotSet ? Colors.orange : null,
                  fontStyle: isNotSet ? FontStyle.italic : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
