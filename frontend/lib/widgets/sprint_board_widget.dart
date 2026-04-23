import 'package:flutter/material.dart';
import '../services/jira_service.dart';
import '../theme/flownet_theme.dart';

class SprintBoardWidget extends StatefulWidget {
  final String sprintId;
  final String sprintName;
  final List<JiraIssue> deliverables;
  final Function(JiraIssue deliverable, String newStatus)? onDeliverableStatusChanged;

  const SprintBoardWidget({
    super.key,
    required this.sprintId,
    required this.sprintName,
    required this.deliverables,
    this.onDeliverableStatusChanged,
  });

  @override
  State<SprintBoardWidget> createState() => _SprintBoardWidgetState();
}

class _SprintBoardWidgetState extends State<SprintBoardWidget> {
  
  // Group deliverables by status
  Map<String, List<JiraIssue>> get _groupedDeliverables {
    final Map<String, List<JiraIssue>> grouped = {};
    
    for (final deliverable in widget.deliverables) {
      // Map various status variations to standard columns
      String status = deliverable.status ?? 'Unknown';
      
      // Debug logging for status mapping
      debugPrint('🎫 Processing deliverable: ${deliverable.summary} with status: "$status"');
      
      // Map status variations to standard columns
      switch (status.toLowerCase()) {
        case 'todo':
        case 'to-do':
        case 'tod o':
        case 'to do':
          status = 'To Do';
          debugPrint('✅ Mapped "$status" to "To Do" for deliverable: ${deliverable.summary}');
          break;
        case 'inprogress':
        case 'in-progress':
        case 'in progress':
          status = 'In Progress';
          debugPrint('✅ Mapped "$status" to "In Progress" for deliverable: ${deliverable.summary}');
          break;
        case 'inreview':
        case 'in-review':
        case 'in review':
          status = 'In Review';
          debugPrint('✅ Mapped "$status" to "In Review" for deliverable: ${deliverable.summary}');
          break;
        case 'done':
        case 'complete':
        case 'completed':
          status = 'Done';
          debugPrint('✅ Mapped "$status" to "Done" for deliverable: ${deliverable.summary}');
          break;
        default:
          // Fallback: put unknown statuses in "To Do" column
          status = 'To Do';
          debugPrint('⚠️ Unknown status "$status", mapping to "To Do" for deliverable: ${deliverable.summary}');
          break;
      }
      
      grouped.putIfAbsent(status, () => []).add(deliverable);
    }
    
    debugPrint('📊 Final grouping: ${grouped.keys.map((k) => '$k: ${grouped[k]!.length}').join(', ')}');
    return grouped;
  }

  // Define column order and colors
  List<Map<String, dynamic>> get _columns {
    return [
      {
        'status': 'To Do',
        'color': Colors.grey,
        'icon': Icons.assignment_outlined,
      },
      {
        'status': 'In Progress',
        'color': Colors.orange,
        'icon': Icons.play_arrow,
      },
      {
        'status': 'In Review',
        'color': Colors.blue,
        'icon': Icons.visibility,
      },
      {
        'status': 'Done',
        'color': Colors.green,
        'icon': Icons.check_circle,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    // Force state update when deliverables change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.deliverables.isNotEmpty) {
        setState(() {});
        debugPrint('🔄 Forced board update with ${widget.deliverables.length} deliverables');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sprint Title and Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sprintName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: FlownetColors.pureWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.deliverables.isNotEmpty)
                    Text(
                      '${widget.deliverables.length} deliverables',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FlownetColors.pureWhite.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              _buildSprintStats(),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Kanban Board - responsive columns, no horizontal scroll
        LayoutBuilder(
          builder: (context, constraints) {
            // 4 columns with 16px spacing between them
            const double spacing = 16;
            final double totalSpacing = spacing * (_columns.length - 1);
            final double columnWidth =
                (constraints.maxWidth - totalSpacing).clamp(220.0, double.infinity) /
                    _columns.length;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < _columns.length; i++)
                  Padding(
                    padding: EdgeInsets.only(right: i == _columns.length - 1 ? 0 : spacing),
                    child: SizedBox(
                      width: columnWidth,
                      child: _buildColumn(_columns[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSprintStats() {
    final totalDeliverables = widget.deliverables.length;
    final completedDeliverables = widget.deliverables.where((d) => d.status == 'Done').length;
    final progress = totalDeliverables > 0 ? (completedDeliverables / totalDeliverables) * 100 : 0.0;

    return Row(
      children: [
        _buildStatItem('Progress', '${progress.toStringAsFixed(1)}%'),
        const SizedBox(width: 16),
        _buildStatItem('Completed', '$completedDeliverables/$totalDeliverables'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: FlownetColors.electricBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: FlownetColors.pureWhite.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildColumn(Map<String, dynamic> column) {
    final status = column['status'] as String;
    final color = column['color'] as Color;
    final icon = column['icon'] as IconData;
    final deliverables = _groupedDeliverables[status] ?? [];

    return Container(
      margin: const EdgeInsets.only(right: 0),
      child: DragTarget<JiraIssue>(
        onAcceptWithDetails: (details) {
          final deliverable = details.data;
          if (widget.onDeliverableStatusChanged != null) {
            widget.onDeliverableStatusChanged!(deliverable, status);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: candidateData.isNotEmpty
                  ? Border.all(color: color, width: 2)
                  : null,
            ),
            child: SizedBox(
              height: 600, // Fixed height to prevent unbounded constraints
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          // Column Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${deliverables.length}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Deliverables List
          Expanded(
            child: deliverables.isEmpty
                ? _buildEmptyColumn(status)
                : ListView.builder(
                    itemCount: deliverables.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildDeliverableCard(deliverables[index]),
                      );
                    },
                  ),
          ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyColumn(String status) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlownetColors.charcoalBlack.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FlownetColors.pureWhite.withValues(alpha: 0.1),
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              color: FlownetColors.pureWhite.withValues(alpha: 0.3),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No $status deliverables',
              style: TextStyle(
                color: FlownetColors.pureWhite.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverableCard(JiraIssue deliverable) {
    return Draggable<JiraIssue>(
      data: deliverable,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlownetColors.charcoalBlack,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: FlownetColors.electricBlue,
              width: 2,
            ),
          ),
          child: Text(
            deliverable.summary,
            style: const TextStyle(
              color: FlownetColors.pureWhite,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      childWhenDragging: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlownetColors.charcoalBlack.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: FlownetColors.pureWhite.withValues(alpha: 0.1),
          ),
        ),
        child: const Center(
          child: Text(
            'Moving...',
            style: TextStyle(
              color: FlownetColors.pureWhite,
              fontSize: 12,
            ),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlownetColors.charcoalBlack.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: FlownetColors.pureWhite.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Deliverable Key and Type
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: FlownetColors.electricBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  deliverable.key,
                  style: const TextStyle(
                    color: FlownetColors.electricBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (deliverable.issueType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    deliverable.issueType!,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Deliverable Summary
          Text(
            deliverable.summary,
            style: const TextStyle(
              color: FlownetColors.pureWhite,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Deliverable Details
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (deliverable.priority != null)
                _buildPriorityChip(deliverable.priority!),
              if (deliverable.assignee != null)
                _buildAssigneeChip(deliverable.assignee!),
            ],
          ),

          if (deliverable.labels != null && deliverable.labels!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: deliverable.labels!.take(3).map((label) => _buildLabelChip(label)).toList(),
            ),
          ],
        ],
      ),
    ),
    );
  }

  Widget _buildAssigneeChip(String assignee) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: FlownetColors.pureWhite.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: FlownetColors.pureWhite.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline,
            color: FlownetColors.pureWhite,
            size: 14,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              assignee,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: FlownetColors.pureWhite.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color priorityColor;
    switch (priority.toLowerCase()) {
      case 'high':
      case 'critical':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      case 'low':
        priorityColor = Colors.green;
        break;
      default:
        priorityColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: priorityColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: priorityColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLabelChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: FlownetColors.electricBlue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: FlownetColors.electricBlue,
          fontSize: 10,
        ),
      ),
    );
  }
}
