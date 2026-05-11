import 'package:flutter/material.dart';
import '../../services/backend_api_service.dart';
import '../../services/realtime_service.dart';
import '../../services/user_data_service.dart';

class AuditTrailOverviewScreen extends StatefulWidget {
  const AuditTrailOverviewScreen({super.key});

  @override
  State<AuditTrailOverviewScreen> createState() => _AuditTrailOverviewScreenState();
}

class _AuditTrailOverviewScreenState extends State<AuditTrailOverviewScreen> {
  final BackendApiService _backend = BackendApiService();
  final RealtimeService _realtimeService = RealtimeService();
  final UserDataService _userDataService = UserDataService();
  List<Map<String, dynamic>> _logs = [];
  final Map<String, String> _userNameById = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    Future.microtask(() => _realtimeService.initialize());
    _realtimeService.offAll('audit_log_created');
    _realtimeService.on('audit_log_created', _handleAuditLogCreated);
  }

  @override
  void dispose() {
    _realtimeService.offAll('audit_log_created');
    super.dispose();
  }

  String _extractUserId(Map<String, dynamic> log) {
    final uid = log['user_id']?.toString() ?? log['userId']?.toString();
    if (uid != null && uid.isNotEmpty) return uid;
    final userObj = log['user'];
    if (userObj is Map) {
      final id = userObj['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return '';
  }

  String _extractActorLabel(Map<String, dynamic> log) {
    final direct = (log['actor_name'] ??
            log['actorName'] ??
            log['user_name'] ??
            log['userName'] ??
            log['user_email'] ??
            log['userEmail'])
        ?.toString();
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();

    final userObj = log['user'];
    if (userObj is Map) {
      final first = userObj['first_name']?.toString() ?? userObj['firstName']?.toString() ?? '';
      final last = userObj['last_name']?.toString() ?? userObj['lastName']?.toString() ?? '';
      final email = userObj['email']?.toString() ?? '';
      final name = ('$first $last').trim();
      if (name.isNotEmpty) return name;
      if (email.isNotEmpty) return email;
    }

    final userId = _extractUserId(log);
    final cached = userId.isNotEmpty ? _userNameById[userId] : null;
    if (cached != null && cached.isNotEmpty) return cached;
    return 'System';
  }

  Future<void> _hydrateUserNames(Iterable<Map<String, dynamic>> logs) async {
    final ids = logs
        .map(_extractUserId)
        .where((id) => id.isNotEmpty && !_userNameById.containsKey(id))
        .toSet()
        .toList();
    if (ids.isEmpty) return;

    await Future.wait(ids.map((id) async {
      final user = await _userDataService.getUserById(id);
      final name = user?.name.trim() ?? '';
      if (name.isEmpty) return;
      _userNameById[id] = name;
    }));

    if (mounted) setState(() {});
  }

  void _handleAuditLogCreated(dynamic data) {
    try {
      if (data is! Map) return;
      final log = Map<String, dynamic>.from(data);
      final id = log['id']?.toString() ?? '';
      if (id.isNotEmpty && _logs.any((e) => (e['id']?.toString() ?? '') == id)) {
        return;
      }
      setState(() {
        _logs = [log, ..._logs];
      });
      _hydrateUserNames([log]);
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        _backend.getRealAuditLogs(skip: 0, limit: 200, entityType: 'deliverable'),
        _backend.getRealAuditLogs(skip: 0, limit: 200, entityType: 'signoff'),
      ]);
      final collected = <Map<String, dynamic>>[];
      for (final resp in responses) {
        if (!resp.isSuccess || resp.data == null) continue;
        final raw = resp.data;
        final List<dynamic> items = raw is Map
            ? (raw['audit_logs'] ?? raw['items'] ?? raw['logs'] ?? raw['data'] ?? [])
            : (raw is List ? raw : []);
        collected.addAll(
          items.whereType<Map>().map((e) => e.cast<String, dynamic>()),
        );
      }
      final deduped = <String, Map<String, dynamic>>{};
      for (final log in collected) {
        final id = (log['id'] ?? '').toString();
        deduped[id.isEmpty ? '${log['action']}-${log['created_at']}' : id] = log;
      }
      final allLogs = deduped.values.toList()
        ..sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));

      if (allLogs.isNotEmpty) {
        setState(() {
          _logs = allLogs;
        });
        _hydrateUserNames(allLogs);
      } else {
        setState(() {
          _logs = [];
          _error = 'Failed to load audit logs';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load audit logs';
        _logs = [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliverable Audit Trail'),
        actions: [
          IconButton(onPressed: _loadLogs, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _logs.isEmpty
                  ? const Center(child: Text('No audit logs available'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final action = (log['action'] ?? log['event'] ?? log['type'] ?? 'Log').toString();
                        final actor = _extractActorLabel(log);
                        final createdAt = log['created_at']?.toString() ?? '';
                        final entityType = log['entity_type'] ?? log['resource_type'] ?? '';
                        final entityName = (log['entity_name'] ?? '').toString();
                        final entityId = (log['entity_id'] ?? '').toString();
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Icon(_getActionIcon(action), color: _getActionColor(action)),
                            title: Text('$action ${entityType.toString().isNotEmpty ? "on $entityType" : ""}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('By: $actor'),
                                if (entityName.isNotEmpty)
                                  Text('Target: $entityName'),
                                if (entityType.toString().isNotEmpty || entityId.isNotEmpty)
                                  Text(
                                    'Entity: ${entityType.toString().isEmpty ? 'unknown' : entityType}${entityId.isNotEmpty ? ' • $entityId' : ''}',
                                  ),
                                if (createdAt.isNotEmpty) Text(createdAt),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  IconData _getActionIcon(String action) {
    action = action.toLowerCase();
    if (action.contains('create')) return Icons.add_circle;
    if (action.contains('update') || action.contains('edit')) return Icons.edit;
    if (action.contains('delete')) return Icons.delete;
    return Icons.history;
  }

  Color _getActionColor(String action) {
    action = action.toLowerCase();
    if (action.contains('create')) return Colors.green;
    if (action.contains('update') || action.contains('edit')) return Colors.blue;
    if (action.contains('delete')) return Colors.red;
    return Colors.grey;
  }
}
