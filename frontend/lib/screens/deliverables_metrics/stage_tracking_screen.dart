// ignore_for_file: deprecated_member_use, duplicate_ignore

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../services/deliverable_service.dart';
import '../../models/deliverable.dart';
import '../../widgets/deliverable_card.dart';
import '../../theme/flownet_theme.dart';

class StageTrackingScreen extends StatefulWidget {
  const StageTrackingScreen({super.key});

  @override
  State<StageTrackingScreen> createState() => _StageTrackingScreenState();
}

class _StageTrackingScreenState extends State<StageTrackingScreen> {
  final DeliverableService _deliverableService = DeliverableService();
  bool _isLoading = true;
  bool _isKanbanView = false;
  int _selectedTabIndex = 0;
  List<Deliverable> _deliverables = [];

  List<Deliverable> get _filteredDeliverables {
    if (_selectedTabIndex == 0) return _deliverables;
    final status = _currentTabStatus;
    if (status == null) return _deliverables;
    return _deliverables.where((d) => d.status == status).toList();
  }

  DeliverableStatus? get _currentTabStatus {
    switch (_selectedTabIndex) {
      case 1: return DeliverableStatus.draft;
      case 2: return DeliverableStatus.inProgress;
      case 3: return DeliverableStatus.inReview;
      case 4: return DeliverableStatus.signedOff;
      default: return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final response = await _deliverableService.getDeliverables();
    if (response.isSuccess && response.data != null) {
      final List<Deliverable> deliverables = (response.data['deliverables'] as List)
          .cast<Deliverable>();
      
      if (mounted) {
        setState(() {
          _deliverables = deliverables;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliverable Stage Tracking'),
        actions: [
          IconButton(
            icon: Icon(_isKanbanView ? Icons.list : Icons.view_kanban),
            tooltip: _isKanbanView ? 'Switch to List View' : 'Switch to Kanban View',
            onPressed: () => setState(() => _isKanbanView = !_isKanbanView),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isKanbanView
              ? _buildKanbanView()
              : _buildListView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: FlownetColors.crimsonRed,
        unselectedItemColor: FlownetColors.graphiteGray,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        iconSize: 22,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'All',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note),
            label: 'Draft',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.loop),
            label: 'In Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rate_review),
            label: 'In Review',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Signed Off',
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    final displayList = _filteredDeliverables;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deliverables List (${displayList.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (displayList.isEmpty)
            const Center(child: Text('No deliverables found.'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                return _buildDeliverableCard(displayList[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDeliverableCard(Deliverable deliverable) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          context.push('/deliverable-detail', extra: deliverable).then((_) {
            _loadData(); // Refresh data when returning from detail screen
          });
        },
        title: Text(deliverable.title),
        subtitle: Text('Owner: ${deliverable.ownerName ?? 'Unassigned'}'),
        trailing: GestureDetector(
          onTap: () => _showStatusUpdateDialog(deliverable),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: deliverable.status.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: deliverable.status.color),
            ),
            child: Text(
              deliverable.status.displayName,
              style: TextStyle(
                color: deliverable.status.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKanbanView() {
    final allColumns = [
      DeliverableStatus.draft,
      DeliverableStatus.inProgress,
      DeliverableStatus.inReview,
      DeliverableStatus.signedOff,
    ];

    final columns = _selectedTabIndex == 0 
        ? allColumns 
        : [_currentTabStatus!];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: columns.map((status) {
                  final items = _deliverables.where((d) => d.status == status).toList();
                  return _buildKanbanColumn(status, items);
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKanbanColumn(DeliverableStatus status, List<Deliverable> items) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: status.color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: status.color.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: status.color),
                const SizedBox(width: 8),
                Text(
                  status.displayName,
                  style: TextStyle(fontWeight: FontWeight.bold, color: status.color),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${items.length}', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: DragTarget<Deliverable>(
              onWillAccept: (data) => data != null && data.status != status,
              onAccept: (deliverable) => _updateStatus(deliverable, status),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: candidateData.isNotEmpty 
                        ? status.color.withOpacity(0.05) 
                        : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Draggable<Deliverable>(
                        data: item,
                        feedback: SizedBox(
                          width: 280,
                          child: Opacity(
                            opacity: 0.8,
                            child: Card(
                              child: ListTile(
                                title: Text(item.title),
                                subtitle: Text(item.status.displayName),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _buildKanbanCard(item),
                        ),
                        child: _buildKanbanCard(item),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanCard(Deliverable deliverable) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: DeliverableCard(
        deliverable: deliverable,
        showArtifactsPreview: true,
        onTap: () {
          context.push('/deliverable-detail', extra: deliverable).then((_) {
            _loadData();
          });
        },
      ),
    );
  }

  Future<void> _showStatusUpdateDialog(Deliverable deliverable) async {
    final newStatus = await showDialog<DeliverableStatus>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusOption(context, DeliverableStatus.draft),
              _buildStatusOption(context, DeliverableStatus.inProgress),
              _buildStatusOption(context, DeliverableStatus.inReview),
              _buildStatusOption(context, DeliverableStatus.signedOff),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (newStatus != null && newStatus != deliverable.status) {
      _updateStatus(deliverable, newStatus);
    }
  }

  Widget _buildStatusOption(BuildContext context, DeliverableStatus status) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: status.color, radius: 8),
      title: Text(status.displayName),
      onTap: () => Navigator.pop(context, status),
    );
  }

  Future<void> _updateStatus(Deliverable deliverable, DeliverableStatus newStatus) async {
    setState(() => _isLoading = true);
    
    // Map enum to backend string format
    String statusString;
    switch (newStatus) {
      case DeliverableStatus.draft:
        statusString = 'draft';
        break;
      case DeliverableStatus.inProgress:
        statusString = 'in_progress';
        break;
      case DeliverableStatus.inReview:
        statusString = 'in_review';
        break;
      case DeliverableStatus.signedOff:
        statusString = 'signed_off';
        break;
      default:
        statusString = 'draft';
    }

    final response = await _deliverableService.updateDeliverableStatus(
      deliverable.id,
      statusString,
    );

    if (response.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${newStatus.displayName}')),
        );
        _loadData(); // Refresh list
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: ${response.error}')),
        );
      }
    }
  }
}
