import 'package:flutter/material.dart';
import '../models/approval_request.dart';

class DeliverableApprovalCard extends StatelessWidget {
  final ApprovalRequest approval;
  final Function(String) onApprove;
  final Function(String) onReject;

  const DeliverableApprovalCard({
    super.key,
    required this.approval,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approval.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(approval.description),
            if (approval.evidenceLinks?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                'Evidence:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Column(
                children: approval.evidenceLinks!
                    .map((link) => Text(link))
                    .toList(),
              ),
            ],
            if (approval.isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onReject(approval.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onApprove(approval.id),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
