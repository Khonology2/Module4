import 'package:flutter/material.dart';
import '../models/audit_log_entry.dart';

class AuditLogList extends StatelessWidget {
  final List<AuditLogEntry> logs;

  const AuditLogList({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No history available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogItem(context, log);
      },
    );
  }

  Widget _buildLogItem(BuildContext context, AuditLogEntry log) {
    final iconData = _getIconForAction(log.action);
    final color = _getColorForAction(log.action);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          radius: 16,
          child: Icon(iconData, size: 16, color: color),
        ),
        title: Text(
          _formatAction(log.action),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'by ${log.userEmail ?? 'System'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            Text(
              _formatDate(log.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        children: [
          if (log.changedFields != null && log.changedFields!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text(
                    'Changes:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...log.changedFields!.map((field) => _buildChangeDetail(field, log)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChangeDetail(String field, AuditLogEntry log) {
    String oldValue = 'null';
    String newValue = 'null';

    if (log.oldValues != null && log.oldValues!.containsKey(field)) {
      oldValue = log.oldValues![field]?.toString() ?? 'null';
    }
    if (log.newValues != null && log.newValues!.containsKey(field)) {
      newValue = log.newValues![field]?.toString() ?? 'null';
    }

    // Skip technical fields that are not user-friendly
    if (['updated_at', 'created_at', 'id', 'uuid'].contains(field)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$field: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              '$oldValue → $newValue',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForAction(String action) {
    switch (action.toLowerCase()) {
      case 'create':
        return Icons.add;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'approve':
        return Icons.check_circle;
      case 'reject':
        return Icons.cancel;
      default:
        return Icons.history;
    }
  }

  Color _getColorForAction(String action) {
    switch (action.toLowerCase()) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      case 'approve':
        return Colors.teal;
      case 'reject':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatAction(String action) {
    return action[0].toUpperCase() + action.substring(1).toLowerCase();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
