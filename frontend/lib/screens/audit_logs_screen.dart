import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/realtime_service.dart';
import '../services/user_data_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
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
      final log = Map<String, dynamic>.from(data as Map);
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
      final resp = await _backend.getRealAuditLogs(skip: 0, limit: 200);
      if (resp.isSuccess && resp.data != null) {
        final raw = resp.data;
        final List<dynamic> items = raw is Map
            ? (raw['audit_logs'] ?? raw['items'] ?? raw['logs'] ?? raw['data'] ?? [])
            : (raw is List ? raw : []);
        setState(() {
          _logs = items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        });
        _hydrateUserNames(_logs);
      } else {
        setState(() {
          _logs = [];
          _error = resp.error ?? 'Failed to load audit logs';
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
        title: const Text('Audit Logs'),
        actions: [
          IconButton(onPressed: _loadLogs, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null
              ? Center(child: Text(_error!))
              : (_logs.isEmpty
                  ? const Center(child: Text('No audit logs available'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final action = (log['action'] ?? log['event'] ?? log['type'] ?? 'Log').toString();
                        final actor = _extractActorLabel(log);
                        final createdAt = log['created_at']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.receipt_long, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('$action • $actor')),
                                ],
                              ),
                              if (createdAt.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(createdAt, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ],
                          ),
                        );
                      },
                    ))),
    );
  }
}

