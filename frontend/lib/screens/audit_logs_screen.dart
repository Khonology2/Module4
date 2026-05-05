import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final BackendApiService _backend = BackendApiService();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
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
                        final actor = (log['actor'] ?? log['user'] ?? '').toString();
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
                                  Expanded(child: Text(actor.isNotEmpty ? '$action • $actor' : action)),
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

