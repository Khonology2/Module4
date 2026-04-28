import 'package:flutter/material.dart';
import '../models/epic.dart';
import '../services/epic_service.dart';
import '../services/sprint_database_service.dart';
import '../theme/flownet_colors.dart';

class EpicDetailScreen extends StatefulWidget {
  final String epicId;

  const EpicDetailScreen({super.key, required this.epicId});

  @override
  State<EpicDetailScreen> createState() => _EpicDetailScreenState();
}

class _EpicDetailScreenState extends State<EpicDetailScreen> {
  final EpicService _epicService = EpicService();
  final SprintDatabaseService _sprintService = SprintDatabaseService();

  Epic? _epic;
  List<Map<String, dynamic>> _availableSprints = [];
  List<String> _linkedSprintIds = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load epic details
      final epicResponse = await _epicService.getEpic(widget.epicId);
      if (epicResponse.isSuccess && epicResponse.data != null) {
        final epicData = epicResponse.data!['epic'];
        if (epicData != null) {
          setState(() {
            _epic = epicData as Epic;
            _linkedSprintIds = List<String>.from(_epic!.sprintIds);
          });
        }
      }

      // Load available sprints
      final sprints = await _sprintService.getSprints();
      setState(() {
        _availableSprints = sprints;
      });
    } catch (e) {
      debugPrint('Error loading epic data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _linkSprint(String sprintId) async {
    setState(() => _isSaving = true);
    try {
      final response = await _epicService.linkSprint(widget.epicId, sprintId);
      if (response.isSuccess) {
        setState(() {
          _linkedSprintIds.add(sprintId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sprint linked successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'Failed to link sprint'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _unlinkSprint(String sprintId) async {
    setState(() => _isSaving = true);
    try {
      final response = await _epicService.unlinkSprint(widget.epicId, sprintId);
      if (response.isSuccess) {
        setState(() {
          _linkedSprintIds.remove(sprintId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sprint unlinked successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showLinkSprintDialog() {
    final unlinkedSprints = _availableSprints
        .where((s) => !_linkedSprintIds.contains(s['id']?.toString()))
        .toList();

    if (unlinkedSprints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All sprints are already linked to this epic'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.cardBackground,
        title: const Text(
          'Link Sprint to Epic',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: unlinkedSprints.length,
            itemBuilder: (context, index) {
              final sprint = unlinkedSprints[index];
              final sprintId = sprint['id']?.toString() ?? '';
              final sprintName = sprint['name']?.toString() ?? 'Unnamed Sprint';
              final status = sprint['status']?.toString() ?? '';

              return ListTile(
                leading: const Icon(Icons.speed, color: FlownetColors.electricBlue),
                title: Text(sprintName, style: const TextStyle(color: Colors.white)),
                subtitle: Text('Status: $status', style: const TextStyle(color: Colors.white70)),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () {
                    Navigator.pop(context);
                    _linkSprint(sprintId);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return FlownetColors.electricBlue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: FlownetColors.charcoalBlack,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Epic Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_epic == null) {
      return Scaffold(
        backgroundColor: FlownetColors.charcoalBlack,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Epic Details'),
        ),
        body: const Center(
          child: Text('Epic not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_epic!.title),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Epic Info Card
            Card(
              color: FlownetColors.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_epic!.status).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _getStatusColor(_epic!.status)),
                          ),
                          child: Text(
                            _epic!.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(_epic!.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_epic!.description != null && _epic!.description!.isNotEmpty) ...[
                      const Text(
                        'Description',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _epic!.description!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Date',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              Text(
                                _formatDate(_epic!.startDate),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Target Date',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              Text(
                                _formatDate(_epic!.targetDate),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Linked Sprints Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Linked Sprints',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showLinkSprintDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Link Sprint'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlownetColors.electricBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This epic spans ${_linkedSprintIds.length} sprint(s)',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),

            if (_linkedSprintIds.isEmpty)
              const Card(
                color: FlownetColors.cardBackground,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.link_off, color: Colors.white38, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'No sprints linked yet',
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Link sprints to track this epic across multiple iterations',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...(_linkedSprintIds.map((sprintId) {
                final sprint = _availableSprints.firstWhere(
                  (s) => s['id']?.toString() == sprintId,
                  orElse: () => {'id': sprintId, 'name': 'Sprint $sprintId'},
                );
                final sprintName = sprint['name']?.toString() ?? 'Unknown Sprint';
                final status = sprint['status']?.toString() ?? '';
                final startDate = sprint['start_date']?.toString() ?? '';
                final endDate = sprint['end_date']?.toString() ?? '';

                return Card(
                  color: FlownetColors.cardBackground,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FlownetColors.electricBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.speed, color: FlownetColors.electricBlue),
                    ),
                    title: Text(sprintName, style: const TextStyle(color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (status.isNotEmpty)
                          Text('Status: $status', style: const TextStyle(color: Colors.white70)),
                        if (startDate.isNotEmpty || endDate.isNotEmpty)
                          Text(
                            '$startDate - $endDate',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.link_off, color: Colors.red),
                      tooltip: 'Unlink Sprint',
                      onPressed: () => _unlinkSprint(sprintId),
                    ),
                  ),
                );
              })),

            const SizedBox(height: 24),

            // Linked Deliverables Section (placeholder)
            const Text(
              'Linked Deliverables',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_epic!.deliverableIds.length} deliverable(s) linked',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),

            if (_epic!.deliverableIds.isEmpty)
              const Card(
                color: FlownetColors.cardBackground,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, color: Colors.white38, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'No deliverables linked yet',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
