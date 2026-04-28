import 'package:flutter/material.dart';
import 'glass_card.dart';

class ProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const ProjectCard({
    super.key,
    required this.project,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final String? startDateStr = project['start_date']?.toString();
    final String? endDateStr = project['end_date']?.toString();
    final String statusStr = project['status']?.toString() ?? '';

    String formatDate(String? value) {
      if (value == null || value.isEmpty) return '';
      try {
        final date = DateTime.parse(value);
        return '${date.day}/${date.month}/${date.year}';
      } catch (_) {
        return value;
      }
    }

    bool isOverdue() {
      if (endDateStr == null || endDateStr.isEmpty) return false;
      if (statusStr.toLowerCase() == 'completed' || statusStr.toLowerCase() == 'cancelled') {
        return false;
      }
      try {
        final end = DateTime.parse(endDateStr);
        return DateTime.now().isAfter(end);
      } catch (_) {
        return false;
      }
    }
    
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        color: isSelected 
            ? primaryColor.withAlpha(51)  // 0.2 * 255 ≈ 51
            : surfaceColor.withAlpha(128),  // 0.5 * 255 = 128
        border: Border.all(
          color: isSelected
              ? primaryColor
              : (isOverdue() ? Colors.redAccent : onSurfaceColor.withAlpha(26)),  // 0.1 * 255 ≈ 26
          width: isSelected ? 2 : 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project['name'] ?? 'Unknown',
                        style: TextStyle(
                          color: onSurfaceColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isOverdue())
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Overdue',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: Icon(Icons.edit, size: 16, color: onSurfaceColor.withAlpha(150)),
                    onPressed: onEdit,
                    tooltip: 'Edit Project',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              project['key'] ?? '',
              style: TextStyle(
                color: onSurfaceColor.withAlpha(179),  // 0.7 * 255 ≈ 179
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              project['project_type'] ?? 'software',
              style: TextStyle(
                color: primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (startDateStr != null || endDateStr != null)
              Expanded(
                child: Text(
                  '${formatDate(startDateStr).isNotEmpty ? formatDate(startDateStr) : 'No start date'}'
                  ' - '
                  '${formatDate(endDateStr).isNotEmpty ? formatDate(endDateStr) : 'No end date'}',
                  style: TextStyle(
                    color: onSurfaceColor.withAlpha(179),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
