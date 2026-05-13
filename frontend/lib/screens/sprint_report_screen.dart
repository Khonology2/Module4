import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/backend_api_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../theme/flownet_theme.dart';

class SprintReportScreen extends StatefulWidget {
  final String sprintId;
  final String? sprintName;

  const SprintReportScreen({
    super.key,
    required this.sprintId,
    this.sprintName,
  });

  @override
  State<SprintReportScreen> createState() => _SprintReportScreenState();
}

class _SprintReportScreenState extends State<SprintReportScreen> {
  final _backend = BackendApiService();
  final _realtime = RealtimeService();

  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  String _statusFilter = '';
  String _ownerFilter = '';
  DateTime? _dueFrom;
  DateTime? _dueTo;

  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _setupRealtime();
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _realtime.offAll('deliverable_created');
    _realtime.offAll('deliverable_updated');
    _realtime.offAll('deliverable_deleted');
    _realtime.offAll('sprint_updated');
    super.dispose();
  }

  void _setupRealtime() async {
    try {
      await _realtime.initialize();
    } catch (_) {}

    void scheduleRefresh() {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
        _load(silent: true);
      });
    }

    _realtime.on('deliverable_created', (_) => scheduleRefresh());
    _realtime.on('deliverable_updated', (_) => scheduleRefresh());
    _realtime.on('deliverable_deleted', (_) => scheduleRefresh());
    _realtime.on('sprint_updated', (_) => scheduleRefresh());
  }

  Future<void> _load({bool silent = false}) async {
    if (_loading) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      _loading = true;
      _error = null;
    }

    try {
      final resp = await _backend.getSprintReport(
        widget.sprintId,
        statusCategory: _statusFilter.isEmpty ? null : _statusFilter,
        ownerId: _ownerFilter.isEmpty ? null : _ownerFilter,
        dueFrom: _dueFrom,
        dueTo: _dueTo,
      );
      if (!mounted) return;
      if (resp.isSuccess && resp.data != null) {
        final raw = resp.data;
        final data = raw is Map && raw['data'] is Map
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
        setState(() {
          _report = data;
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = resp.error ?? 'Failed to load sprint report';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _deliverables() {
    final list = _report?['deliverables'];
    if (list is List) {
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Map<String, dynamic> _summary() {
    final s = _report?['summary'];
    if (s is Map) return Map<String, dynamic>.from(s);
    return {};
  }

  Map<String, dynamic> _sprint() {
    final s = _report?['sprint'];
    if (s is Map) return Map<String, dynamic>.from(s);
    return {};
  }

  List<Map<String, dynamic>> _teamMembers() {
    final team = _report?['team'];
    if (team is Map && team['members'] is List) {
      return (team['members'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Color _healthColor(String health) {
    switch (health) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '${d.year}-$mm-$dd';
    } catch (_) {
      return iso;
    }
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final sprint = _sprint();
    final summary = _summary();
    final deliverables = _deliverables();
    final team = _teamMembers();
    final sprintTitle = widget.sprintName ?? sprint['name']?.toString() ?? 'Sprint Report';
    final health = summary['health']?.toString() ?? 'good';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(sprintTitle),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: (_report != null && (AuthService().currentUser?.isDeliveryLead ?? false))
          ? FloatingActionButton.extended(
              onPressed: () => _showPublishDialog(context, sprintTitle),
              icon: const Icon(Icons.assignment_turned_in),
              label: const Text('Sign Off & Publish'),
              backgroundColor: FlownetColors.electricBlue,
              foregroundColor: Colors.white,
            )
          : null,
      body: _loading && _report == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _report == null
              ? Center(child: Text('Failed to load report: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeaderCard(sprint, summary, health, team),
                      const SizedBox(height: 16),
                      _buildFilters(team),
                      const SizedBox(height: 16),
                      _buildSummaryGrid(summary),
                      const SizedBox(height: 24),
                      Text(
                        'Deliverables',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildDeliverablesTable(context, deliverables),
                      const SizedBox(height: 24),
                      _buildInsights(summary, deliverables),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> sprint, Map<String, dynamic> summary, String health, List<Map<String, dynamic>> team) {
    final start = _fmtDate(sprint['startDate']?.toString());
    final end = _fmtDate(sprint['endDate']?.toString());
    final status = sprint['status']?.toString() ?? '-';
    final progress = _asInt(summary['sprintProgressPercent']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlownetColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sprint['name']?.toString() ?? 'Sprint',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _healthColor(health).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _healthColor(health).withValues(alpha: 0.4)),
                ),
                child: Text(
                  health.toUpperCase(),
                  style: TextStyle(color: _healthColor(health), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Duration: $start → $end',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            'Status: $status',
            style: const TextStyle(color: Colors.white70),
          ),
          if (team.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Team: ${team.map((m) => (m['name'] ?? m['email'] ?? '').toString()).where((s) => s.trim().isNotEmpty).take(6).join(', ')}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (progress.clamp(0, 100)) / 100.0,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(FlownetColors.electricBlue),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sprint Progress: $progress%',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<Map<String, dynamic>> team) {
    final owners = team
        .map((m) => {'id': m['id']?.toString() ?? '', 'label': (m['name'] ?? m['email'] ?? '').toString()})
        .where((m) => (m['id'] ?? '').toString().isNotEmpty && (m['label'] ?? '').toString().isNotEmpty)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        
        if (isSmall) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('status:$_statusFilter'),
                initialValue: _statusFilter.isEmpty ? '' : _statusFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'not_started', child: Text('Not Started')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                  DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v ?? '');
                  _load();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('owner:$_ownerFilter'),
                initialValue: _ownerFilter.isEmpty ? '' : _ownerFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Owner',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All')),
                  ...owners.map(
                    (o) => DropdownMenuItem(
                      value: o['id']!,
                      child: Text(o['label']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _ownerFilter = v ?? '');
                  _load();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueFrom ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setState(() => _dueFrom = DateTime(picked.year, picked.month, picked.day));
                        _load();
                      },
                      child: Text(_dueFrom == null ? 'Due From' : _fmtDate(_dueFrom!.toIso8601String())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueTo ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setState(() => _dueTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                        _load();
                      },
                      child: Text(_dueTo == null ? 'Due To' : _fmtDate(_dueTo!.toIso8601String())),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('status:$_statusFilter'),
                initialValue: _statusFilter.isEmpty ? '' : _statusFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'not_started', child: Text('Not Started')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                  DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                ],
                onChanged: (v) {
                  setState(() => _statusFilter = v ?? '');
                  _load();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('owner:$_ownerFilter'),
                initialValue: _ownerFilter.isEmpty ? '' : _ownerFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Owner',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All')),
                  ...owners.map(
                    (o) => DropdownMenuItem(
                      value: o['id']!,
                      child: Text(o['label']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _ownerFilter = v ?? '');
                  _load();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueFrom ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  setState(() => _dueFrom = DateTime(picked.year, picked.month, picked.day));
                  _load();
                },
                child: Text(_dueFrom == null ? 'Due From' : _fmtDate(_dueFrom!.toIso8601String())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueTo ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  setState(() => _dueTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                  _load();
                },
                child: Text(_dueTo == null ? 'Due To' : _fmtDate(_dueTo!.toIso8601String())),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryGrid(Map<String, dynamic> summary) {
    final items = [
      {'label': 'Total', 'value': _asInt(summary['totalDeliverables'])},
      {'label': 'Completed', 'value': _asInt(summary['completedDeliverables'])},
      {'label': 'In Progress', 'value': _asInt(summary['inProgressDeliverables'])},
      {'label': 'Not Started', 'value': _asInt(summary['notStartedDeliverables'])},
      {'label': 'Overdue', 'value': _asInt(summary['overdueDeliverables'])},
      {'label': 'Blocked', 'value': _asInt(summary['blockedDeliverables'])},
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 900 ? 3 : 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((i) {
            return SizedBox(
              width: (c.maxWidth - (12 * (cols - 1))) / cols,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FlownetColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i['label']!.toString(), style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text(
                      i['value']!.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDeliverablesTable(BuildContext context, List<Map<String, dynamic>> deliverables) {
    if (deliverables.isEmpty) {
      return const Text('No deliverables found for this sprint.');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Deliverable')),
          DataColumn(label: Text('Owner')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Progress')),
          DataColumn(label: Text('Due Date')),
          DataColumn(label: Text('Completion')),
        ],
        rows: deliverables.map((d) {
          final progress = _asInt(d['progressPercent']);
          final isOverdue = d['isOverdue'] == true;
          final name = d['name']?.toString() ?? d['id']?.toString() ?? '';
          return DataRow(
            cells: [
              DataCell(
                Text(name),
              ),
              DataCell(Text(d['ownerName']?.toString() ?? '-')),
              DataCell(Text(d['status']?.toString() ?? '-')),
              DataCell(Text('$progress%')),
              DataCell(Text(_fmtDate(d['dueDate']?.toString()), style: TextStyle(color: isOverdue ? Colors.red : null))),
              DataCell(Text(_fmtDate(d['completionDate']?.toString()))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInsights(Map<String, dynamic> summary, List<Map<String, dynamic>> deliverables) {
    final completionRate = _asInt(summary['completionRatePercent']);
    final overdue = _asInt(summary['overdueDeliverables']);
    final blocked = _asInt(summary['blockedDeliverables']);
    final health = summary['health']?.toString() ?? 'good';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlownetColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sprint Insights',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text('Completion Rate: $completionRate%', style: const TextStyle(color: Colors.white70)),
          Text('Delayed Deliverables: $overdue', style: const TextStyle(color: Colors.white70)),
          Text('Blocked Deliverables: $blocked', style: const TextStyle(color: Colors.white70)),
          Text('Overall Sprint Health: ${health.toUpperCase()}', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  void _showPublishDialog(BuildContext context, String sprintTitle) {
    showDialog(
      context: context,
      builder: (context) {
        bool isPublishing = false;
        final noteController = TextEditingController();
        final signatureController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Sign Off & Publish Report'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This will generate a final PDF report including sprint metrics, deliverables, team information, and sign-off signatures.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Sign-off Note (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      controller: noteController,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Signature (Type your full name)',
                        border: OutlineInputBorder(),
                      ),
                      controller: signatureController,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isPublishing ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isPublishing
                      ? null
                      : () async {
                          setLocalState(() => isPublishing = true);
                          try {
                            Future<Map<String, dynamic>> loadSprint() async {
                              final sprintResp = await _backend.getSprint(widget.sprintId);
                              final raw = sprintResp.isSuccess ? sprintResp.data : null;
                              if (raw is Map && raw['data'] is Map) {
                                return Map<String, dynamic>.from(raw['data'] as Map);
                              }
                              if (raw is Map) return Map<String, dynamic>.from(raw);
                              return <String, dynamic>{};
                            }

                            Future<List<Map<String, dynamic>>> loadSprintMetrics() async {
                              final resp = await _backend.getSprintMetrics(widget.sprintId);
                              if (!resp.isSuccess || resp.data == null) return <Map<String, dynamic>>[];
                              final raw = resp.data;
                              final dynamic extracted = raw is Map ? (raw['data'] ?? raw['metrics'] ?? raw['items'] ?? raw) : raw;
                              final List<dynamic> items = extracted is List
                                  ? extracted
                                  : (extracted is Map ? <dynamic>[extracted] : const <dynamic>[]);
                              return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                            }

                            bool isSprintCompleted(Map<String, dynamic> sprintMap) {
                              final statusRaw = (sprintMap['status'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'[\s_-]+'), '');
                              return statusRaw == 'completed' || statusRaw == 'complete' || statusRaw == 'done' || statusRaw == 'closed';
                            }

                            bool hasRequiredMetrics(Map<String, dynamic> sprintMap) {
                              final testPassRate = sprintMap['test_pass_rate'] ?? sprintMap['testPassRate'];
                              final defectsOpened = sprintMap['defects_opened'] ?? sprintMap['defectsOpened'];
                              final defectsClosed = sprintMap['defects_closed'] ?? sprintMap['defectsClosed'];
                              final codeReview = sprintMap['code_review_completion'] ?? sprintMap['codeReviewCompletion'];
                              final documentation = sprintMap['documentation_status'] ?? sprintMap['documentationStatus'];
                              return testPassRate != null &&
                                  defectsOpened != null &&
                                  defectsClosed != null &&
                                  codeReview != null &&
                                  documentation != null;
                            }

                            bool hasRequiredMetricsInSavedMetrics(List<Map<String, dynamic>> metricsList) {
                              dynamic pick(Map<String, dynamic> m, List<String> keys) {
                                for (final k in keys) {
                                  if (m.containsKey(k) && m[k] != null) return m[k];
                                }
                                return null;
                              }

                              bool isPresent(dynamic v) {
                                if (v == null) return false;
                                if (v is String) return v.trim().isNotEmpty;
                                return true;
                              }

                              for (final m in metricsList) {
                                final testPassRate = pick(m, const ['test_pass_rate', 'testPassRate']);
                                final defectsOpened = pick(m, const ['defects_opened', 'defectsOpened']);
                                final defectsClosed = pick(m, const ['defects_closed', 'defectsClosed']);
                                final codeReview = pick(m, const ['code_review_completion', 'codeReviewCompletion']);
                                final documentation = pick(m, const ['documentation_status', 'documentationStatus']);
                                if (isPresent(testPassRate) &&
                                    isPresent(defectsOpened) &&
                                    isPresent(defectsClosed) &&
                                    isPresent(codeReview) &&
                                    isPresent(documentation)) {
                                  return true;
                                }
                              }
                              return false;
                            }

                            Future<bool> metricsAreReady() async {
                              final sprintMap = await loadSprint();
                              if (sprintMap.isEmpty) {
                                throw Exception('Failed to load sprint details. Please refresh and try again.');
                              }
                              if (!isSprintCompleted(sprintMap)) {
                                throw Exception('Complete the sprint before publishing a sprint sign-off report.');
                              }

                              if (hasRequiredMetrics(sprintMap)) return true;

                              final metricsList = await loadSprintMetrics();
                              return hasRequiredMetricsInSavedMetrics(metricsList);
                            }

                            Future<void> ensureMetricsReady() async {
                              if (await metricsAreReady()) return;

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sprint metrics are required before publishing. Please complete the sprint metrics form.'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              await context.push('/sprint-metrics/${widget.sprintId}');
                              if (!context.mounted) return;

                              for (var i = 0; i < 2; i++) {
                                if (await metricsAreReady()) return;
                                await Future<void>.delayed(const Duration(milliseconds: 400));
                              }
                              throw Exception('Sprint metrics must be completed before publishing.');
                            }

                            await ensureMetricsReady();

                            final sig = signatureController.text.trim();
                            if (sig.isEmpty) {
                              setLocalState(() => isPublishing = false);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Signature is required before publishing to the client.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            ApiResponse? createResp;
                            for (var attempt = 0; attempt < 2; attempt++) {
                              createResp = await _backend.createSprintReportFromSprint(
                                widget.sprintId,
                                note: noteController.text.trim(),
                              );
                              if (!context.mounted) return;
                              if (createResp.isSuccess && createResp.data != null) break;

                              final err = (createResp.error ?? '').toString();
                              final errLower = err.toLowerCase();
                              final isMetricsError =
                                  errLower.contains('sprint metrics must be completed') ||
                                  errLower.contains('metrics must be completed before creating a sprint sign-off report') ||
                                  errLower.contains('sprint metrics are required') ||
                                  errLower.contains('complete sprint metrics');
                              if (isMetricsError && attempt == 0) {
                                setLocalState(() => isPublishing = false);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sprint metrics are incomplete. Please update and save them, then publish again.'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                                await context.push('/sprint-metrics/${widget.sprintId}');
                                if (!context.mounted) return;
                                setLocalState(() => isPublishing = true);
                                await ensureMetricsReady();
                                continue;
                              }
                              throw Exception(err.isNotEmpty ? err : 'Failed to create report');
                            }

                            if (createResp == null || !createResp.isSuccess || createResp.data == null) {
                              throw Exception(createResp?.error ?? 'Failed to create report');
                            }
                            final reportId = (createResp.data['id'] ?? createResp.data['reportId'] ?? '').toString();
                            if (reportId.isEmpty) throw Exception('Invalid report id');

                            final sigResp = await _backend.addReportSignature(
                              reportId,
                              signatureData: sig,
                              signatureType: 'typed',
                            );
                            if (!sigResp.isSuccess) {
                              throw Exception(sigResp.error ?? 'Failed to attach signature');
                            }

                            final submitResp = await _backend.submitReport(reportId);
                            if (!submitResp.isSuccess) {
                              throw Exception(submitResp.error ?? 'Failed to submit report');
                            }
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Report "$sprintTitle" submitted to client'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            try {
                              context.go('/report-repository');
                            } catch (_) {}
                          } catch (e) {
                            if (!context.mounted) return;
                            setLocalState(() => isPublishing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlownetColors.electricBlue,
                    foregroundColor: FlownetColors.pureWhite,
                  ),
                  child: isPublishing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Publish'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
