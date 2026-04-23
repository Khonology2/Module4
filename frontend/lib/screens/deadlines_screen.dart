import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/flownet_theme.dart';
import '../services/api_service.dart';
import '../models/deliverable.dart';

class DeadlinesScreen extends ConsumerStatefulWidget {
  const DeadlinesScreen({super.key});

  @override
  ConsumerState<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends ConsumerState<DeadlinesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Deliverable> _deliverables = [];
  bool _isLoading = false;
  String? _error;
  String _filter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDeliverables();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDeliverables() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await ApiService.getDeliverables();
      _deliverables
        ..clear()
        ..addAll(items.map((m) => Deliverable.fromJson(m)).toList());
    } catch (e) {
      _error = 'Failed to load deliverables';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Deliverable> get _visibleDeliverables {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final q = _searchQuery.trim().toLowerCase();
    final List<Deliverable> list = _deliverables.where((d) {
      final matchesSearch = q.isEmpty ||
          d.title.toLowerCase().contains(q) ||
          d.description.toLowerCase().contains(q);
      final due = DateTime(d.dueDate.year, d.dueDate.month, d.dueDate.day);
      final diffDays = due.difference(todayStart).inDays;
      bool matchesFilter;
      switch (_filter) {
        case 'overdue':
          matchesFilter = d.isOverdue;
          break;
        case 'today':
          matchesFilter = diffDays == 0;
          break;
        case 'upcoming':
          matchesFilter = diffDays > 0;
          break;
        case 'completed':
          matchesFilter = d.status == DeliverableStatus.approved;
          break;
        default:
          matchesFilter = true;
      }
      return matchesSearch && matchesFilter;
    }).toList();

    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = value;
        });
      },
      backgroundColor: FlownetColors.slate,
      selectedColor: FlownetColors.electricBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey,
      ),
    );
  }

  String _formatDue(DateTime d) {
    final now = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 0) return '${-diff}d overdue';
    return 'In $diff days';
  }

  Widget _buildDeliverableTile(Deliverable d) {
    final dueText = _formatDue(d.dueDate);
    final statusColor = d.statusColor;
    final isOverdue = d.isOverdue;
    return Card(
      child: ListTile(
        title: Text(d.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(d.statusDisplayName),
                  // ignore: deprecated_member_use
                  backgroundColor: statusColor.withOpacity(0.15),
                  labelStyle: TextStyle(color: statusColor),
                  side: BorderSide(color: statusColor),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(dueText),
                  backgroundColor:
                      // ignore: deprecated_member_use
                      (isOverdue ? Colors.red : Colors.orange).withOpacity(0.1),
                  labelStyle:
                      TextStyle(color: isOverdue ? Colors.red : Colors.orange),
                  side:
                      BorderSide(color: isOverdue ? Colors.red : Colors.orange),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  List<Widget> _buildGroupedSections(List<Deliverable> list) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final overdue = list.where((d) => d.isOverdue).toList();
    final today = list
        .where((d) =>
            DateTime(d.dueDate.year, d.dueDate.month, d.dueDate.day)
                .difference(todayStart)
                .inDays == 0,)
        .toList();
    final upcoming = list
        .where((d) =>
            DateTime(d.dueDate.year, d.dueDate.month, d.dueDate.day)
                .difference(todayStart)
                .inDays > 0,)
        .toList();

    final sections = [
      {'label': 'Overdue', 'items': overdue, 'color': Colors.red},
      {'label': 'Today', 'items': today, 'color': Colors.orange},
      {'label': 'Upcoming', 'items': upcoming, 'color': Colors.green},
    ];

    final children = <Widget>[];
    for (final s in sections) {
      final secItems = (s['items'] as List<Deliverable>);
      if (secItems.isEmpty) continue;
      children.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              s['label'] as String,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: FlownetColors.pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: (s['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s['color'] as Color),
              ),
              child: Text(
                secItems.length.toString(),
                style: TextStyle(
                    color: s['color'] as Color, fontWeight: FontWeight.bold,),
              ),
            ),
          ],
        ),
      );
      children.add(const SizedBox(height: 8));
      for (final d in secItems) {
        children.add(_buildDeliverableTile(d));
        children.add(const SizedBox(height: 8));
      }
      children.add(const SizedBox(height: 12));
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleDeliverables;
    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      appBar: AppBar(
        title: const Text('All Deadlines'),
        backgroundColor: FlownetColors.graphiteGray,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeliverables,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDeliverables,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search deliverables...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('overdue', 'Overdue'),
                  const SizedBox(width: 8),
                  _buildFilterChip('today', 'Today'),
                  const SizedBox(width: 8),
                  _buildFilterChip('upcoming', 'Upcoming'),
                  const SizedBox(width: 8),
                  _buildFilterChip('completed', 'Completed'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : (_filter == 'all'
                          ? ListView(
                              padding: const EdgeInsets.all(16),
                              children: _buildGroupedSections(visible),
                            )
                          : visible.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No deadlines found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: visible.length,
                                  itemBuilder: (context, index) {
                                    return _buildDeliverableTile(
                                        visible[index],);
                                  },
                                )),
            ),
          ],
        ),
      ),
    );
  }
}