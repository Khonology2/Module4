import 'package:flutter/material.dart';
import '../models/deliverable.dart';

class DeliverableCard extends StatelessWidget {
  final Deliverable deliverable;
  final VoidCallback? onTap;
  final bool compact;
  final bool showArtifactsPreview;

  const DeliverableCard({
    super.key,
    required this.deliverable,
    this.onTap,
    this.compact = false,
    this.showArtifactsPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      deliverable.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  _buildStatusChip(context),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Text(
                  deliverable.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: deliverable.isOverdue ? Colors.red : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    deliverable.isOverdue
                        ? 'Overdue by ${-deliverable.daysUntilDue} days'
                        : 'Due in ${deliverable.daysUntilDue} days',
                    style: TextStyle(
                      color: deliverable.isOverdue ? Colors.red : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: deliverable.isOverdue ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.group_work,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${deliverable.sprintIds.length} sprint${deliverable.sprintIds.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.checklist,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${deliverable.definitionOfDone.length} DoD',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (deliverable.ownerName != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Tooltip(
                        message: deliverable.ownerRole != null 
                            ? 'Role: ${deliverable.ownerRole}' 
                            : 'Owner',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                deliverable.ownerName!,
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (deliverable.approvedAt != null && !compact) ...[
                    if (deliverable.ownerName != null) const SizedBox(width: 8),
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(deliverable.approvedAt!),
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (showArtifactsPreview && deliverable.artifacts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      ...deliverable.artifacts.take(4).map((artifact) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Tooltip(
                          richMessage: WidgetSpan(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            (deliverable.ownerName?.trim().isNotEmpty == true
                                                    ? deliverable.ownerName!.trim()
                                                    : (deliverable.assignedToName?.trim().isNotEmpty == true
                                                        ? deliverable.assignedToName!.trim()
                                                        : 'Unknown'))
                                                .toString(),
                                            style: TextStyle(
                                              color: Colors.blue[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (deliverable.assignedToName != null && deliverable.assignedToName!.isNotEmpty) ...[
                                            Text(
                                              'Assigned to: ${deliverable.assignedToName}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          child: Icon(
                            _getFileIcon(artifact.fileType),
                            size: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                      )),
                      if (deliverable.artifacts.length > 4)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+${deliverable.artifacts.length - 4}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    final type = fileType.toLowerCase();
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('doc') || type.contains('word')) return Icons.description;
    if (type.contains('xls') || type.contains('sheet')) return Icons.table_chart;
    if (type.contains('ppt') || type.contains('presentation')) return Icons.slideshow;
    if (type.contains('img') || type.contains('png') || type.contains('jpg') || type.contains('jpeg')) return Icons.image;
    if (type.contains('zip') || type.contains('rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Widget _buildStatusChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: deliverable.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: deliverable.statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        deliverable.statusDisplayName,
        style: TextStyle(
          color: deliverable.statusColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'today';
    } else if (difference == 1) {
      return 'yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
