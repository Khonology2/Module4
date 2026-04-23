import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';

class SystemHealthScreen extends StatefulWidget {
  const SystemHealthScreen({super.key});

  @override
  State<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

class _SystemHealthScreenState extends State<SystemHealthScreen> {
  final BackendApiService _backend = BackendApiService();
  Map<String, dynamic> _health = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  Future<void> _loadHealth() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await _backend.getSystemHealth();
      if (resp.isSuccess && resp.data != null) {
        final raw = resp.data;
        Map<String, dynamic> map;
        if (raw is Map<String, dynamic>) {
          map = raw;
        } else if (raw is Map) {
          map = Map<String, dynamic>.from(raw);
        } else {
          map = {};
        }
        setState(() {
          _health = map;
        });
      } else {
        setState(() {
          _error = resp.error ?? 'Failed to load system health';
          _health = {};
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load system health';
        _health = {};
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('healthy') || s.contains('ok') || s.contains('up')) return Colors.green;
    if (s.contains('warn') || s.contains('degrade')) return Colors.orange;
    if (s.contains('critical') || s.contains('down') || s.contains('error') || s.contains('fail')) return Colors.red;
    return Colors.grey;
  }

  String _labelForKey(String key) {
    final s = key.replaceAll('_', ' ').replaceAll('-', ' ');
    return s.isEmpty ? 'Metric' : s[0].toUpperCase() + s.substring(1);
  }

  dynamic _valueForEntry(dynamic value) {
    if (value is Map) {
      return value['status'] ?? value['value'] ?? value['state'] ?? value;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Health'),
        actions: [
          IconButton(onPressed: _loadHealth, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null
                ? Center(child: Text(_error!))
                : (_health.isEmpty
                    ? const Center(child: Text('No health data available'))
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final entry in _health.entries)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, color: _statusColor(_valueForEntry(entry.value).toString()), size: 12),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_labelForKey(entry.key), style: Theme.of(context).textTheme.bodyMedium),
                                        Text(_valueForEntry(entry.value).toString(), style: Theme.of(context).textTheme.titleMedium),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ))),
      ),
    );
  }
}

