import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/epic.dart';
import '../services/epic_service.dart';
import '../services/sprint_database_service.dart';
import '../theme/flownet_colors.dart';
import '../widgets/background_image.dart';

class EpicManagementScreen extends StatefulWidget {
  const EpicManagementScreen({super.key});

  @override
  State<EpicManagementScreen> createState() => _EpicManagementScreenState();
}

class _EpicManagementScreenState extends State<EpicManagementScreen> {
  final EpicService _epicService = EpicService();
  final SprintDatabaseService _sprintService = SprintDatabaseService();
  
  List<Epic> _epics = [];
  List<Map<String, dynamic>> _availableSprints = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load epics
      final epicsResponse = await _epicService.getEpics(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );
      
      // Load sprints
      final sprints = await _sprintService.getSprints();
      
      if (epicsResponse.isSuccess && epicsResponse.data != null) {
        setState(() {
          _epics = epicsResponse.data!['epics'] as List<Epic>? ?? [];
          _availableSprints = sprints;
        });
      } else {
        setState(() {
          _availableSprints = sprints;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // Alias for backward compatibility
  Future<void> _loadEpics() => _loadData();

  void _showCreateEpicDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? startDate;
    DateTime? targetDate;
    final List<String> selectedSprintIds = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: FlownetColors.cardBackground,
          title: const Text('Create New Epic', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Epic Title *',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: FlownetColors.electricBlue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: FlownetColors.electricBlue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      startDate != null 
                        ? 'Start: ${_formatDate(startDate!)}'
                        : 'Select Start Date',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: Colors.white70),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() => startDate = date);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      targetDate != null 
                        ? 'Target: ${_formatDate(targetDate!)}'
                        : 'Select Target Date',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: Colors.white70),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() => targetDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Link to Sprints (optional)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select sprints this epic will span across',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (_availableSprints.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'No sprints available. You can link sprints later.',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableSprints.length,
                        itemBuilder: (context, index) {
                          final sprint = _availableSprints[index];
                          final sprintId = sprint['id']?.toString() ?? '';
                          final sprintName = sprint['name']?.toString() ?? 'Unnamed';
                          final isSelected = selectedSprintIds.contains(sprintId);
                          
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedSprintIds.add(sprintId);
                                } else {
                                  selectedSprintIds.remove(sprintId);
                                }
                              });
                            },
                            title: Text(sprintName, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              sprint['status']?.toString() ?? '',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            activeColor: FlownetColors.electricBlue,
                            checkColor: Colors.white,
                            dense: true,
                          );
                        },
                      ),
                    ),
                  if (selectedSprintIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${selectedSprintIds.length} sprint(s) selected',
                        style: const TextStyle(color: FlownetColors.electricBlue),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title is required')),
                  );
                  return;
                }
                
                final response = await _epicService.createEpic(
                  title: titleController.text,
                  description: descriptionController.text.isNotEmpty 
                    ? descriptionController.text 
                    : null,
                  startDate: startDate,
                  targetDate: targetDate,
                  sprintIds: selectedSprintIds.isNotEmpty ? selectedSprintIds : null,
                );
                
                if (!context.mounted) return;
                if (response.isSuccess) {
                  Navigator.pop(context);
                  _loadEpics();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Epic created successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response.error ?? 'Failed to create epic')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FlownetColors.electricBlue,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEpicDetails(Epic epic) {
    context.push('/epics/${epic.id}');
  }

  Future<void> _deleteEpic(Epic epic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.cardBackground,
        title: const Text('Delete Epic', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${epic.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _epicService.deleteEpic(epic.id);
      if (response.isSuccess) {
        _loadEpics();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Epic deleted successfully')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
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
    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Epics & Features'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedFilter = value);
              _loadEpics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'draft', child: Text('Draft')),
              const PopupMenuItem(value: 'in_progress', child: Text('In Progress')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
            ],
          ),
        ],
      ),
      body: BackgroundImage(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _epics.isEmpty
                  ? _buildEmptyState()
                  : _buildEpicsList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEpicDialog,
        backgroundColor: FlownetColors.electricBlue,
        icon: const Icon(Icons.add),
        label: const Text('New Epic'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_outlined, size: 80, color: Colors.white30),
          SizedBox(height: 16),
          Text(
            'No Epics Found',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first epic to group deliverables across sprints',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEpicsList() {
    return RefreshIndicator(
      onRefresh: _loadEpics,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _epics.length,
        itemBuilder: (context, index) {
          final epic = _epics[index];
          return _buildEpicCard(epic);
        },
      ),
    );
  }

  Widget _buildEpicCard(Epic epic) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: FlownetColors.cardBackground.withValues(alpha: 0.8),
      child: InkWell(
        onTap: () => _showEpicDetails(epic),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      epic.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(epic.status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(epic.status)),
                    ),
                    child: Text(
                      epic.statusDisplayName,
                      style: TextStyle(
                        color: _getStatusColor(epic.status),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteEpic(epic);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              if (epic.description != null && epic.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  epic.description!,
                  style: const TextStyle(color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMetricChip(Icons.speed, '${epic.totalSprints} Sprints'),
                  const SizedBox(width: 12),
                  _buildMetricChip(Icons.assignment, '${epic.totalDeliverables} Deliverables'),
                ],
              ),
              if (epic.startDate != null || epic.targetDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (epic.startDate != null)
                      Text(
                        'Start: ${_formatDate(epic.startDate!)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    if (epic.startDate != null && epic.targetDate != null)
                      const Text(' • ', style: TextStyle(color: Colors.white54)),
                    if (epic.targetDate != null)
                      Text(
                        'Target: ${_formatDate(epic.targetDate!)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
