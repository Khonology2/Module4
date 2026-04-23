import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/audit_log_entry.dart';

class AuditLogDetailScreen extends StatelessWidget {
  final AuditLogEntry logEntry;

  const AuditLogDetailScreen({super.key, required this.logEntry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(context),
            const SizedBox(height: 16),
            _buildChangesCard(context),
            const SizedBox(height: 16),
            _buildRawDataCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  // ignore: deprecated_member_use
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(_getActionIcon(logEntry.action), color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatAction(logEntry.action),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Category: ${logEntry.actionCategory ?? 'General'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('User', logEntry.userEmail ?? logEntry.userId ?? 'Unknown'),
            if (logEntry.userRole != null) _buildInfoRow('Role', logEntry.userRole!),
            _buildInfoRow('Date', DateFormat('MMMM d, yyyy').format(logEntry.createdAt)),
            _buildInfoRow('Time', DateFormat('HH:mm:ss').format(logEntry.createdAt)),
            if (logEntry.entityId != null) _buildInfoRow('Entity ID', logEntry.entityId!),
            if (logEntry.entityType != null) _buildInfoRow('Entity Type', logEntry.entityType!),
          ],
        ),
      ),
    );
  }

  Widget _buildChangesCard(BuildContext context) {
    if (logEntry.oldValues == null && logEntry.newValues == null) {
      return const SizedBox.shrink();
    }

    final changedFields = logEntry.changedFields ?? [];
    if (changedFields.isEmpty && logEntry.oldValues == null && logEntry.newValues == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No specific changes recorded.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Changes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Colors.black12),
                  children: [
                    Padding(padding: EdgeInsets.all(8.0), child: Text('Field', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8.0), child: Text('Old Value', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(8.0), child: Text('New Value', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                ...changedFields.map((field) {
                  final oldVal = logEntry.oldValues?[field]?.toString() ?? '-';
                  final newVal = logEntry.newValues?[field]?.toString() ?? '-';
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(8.0), child: Text(field)),
                      Padding(padding: const EdgeInsets.all(8.0), child: Text(oldVal)),
                      Padding(padding: const EdgeInsets.all(8.0), child: Text(newVal)),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawDataCard(BuildContext context) {
    return ExpansionTile(
      title: const Text('Raw Data'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logEntry.oldValues != null) ...[
                const Text('Old Values:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(logEntry.oldValues.toString()),
                const SizedBox(height: 8),
              ],
              if (logEntry.newValues != null) ...[
                const Text('New Values:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(logEntry.newValues.toString()),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatAction(String action) {
    return action.replaceAll('_', ' ').toUpperCase();
  }

  IconData _getActionIcon(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('create')) return Icons.add_circle_outline;
    if (lower.contains('update')) return Icons.edit;
    if (lower.contains('delete')) return Icons.delete_outline;
    if (lower.contains('status')) return Icons.swap_horiz;
    return Icons.info_outline;
  }
}
