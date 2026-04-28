import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/role_guard.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final BackendApiService _backend = BackendApiService();
  bool _maintenanceEnabled = false;
  final TextEditingController _maintenanceMessageController = TextEditingController();
  bool _loading = false;
  List<dynamic> _backups = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    try {
      final resp = await _backend.listBackups();
      if (resp.isSuccess && resp.data != null) {
        final raw = resp.data;
        List<dynamic> items;
        if (raw is List) {
          items = raw;
        } else if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          final v = m['backups'] ?? m['data'] ?? m['items'] ?? [];
          items = v is List ? v : [];
        } else {
          items = const [];
        }
        setState(() {
          _backups = items;
          _error = null;
        });
      } else {
        setState(() {
          _backups = const [];
          _error = resp.error ?? 'Failed to load backups';
        });
      }
    } catch (_) {
      setState(() {
        _backups = const [];
        _error = 'Failed to load backups';
      });
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? FlownetColors.crimsonRed : FlownetColors.emeraldGreen,
      ),
    );
  }

  Future<void> _toggleMaintenance(bool enabled) async {
    setState(() => _loading = true);
    try {
      final resp = await _backend.toggleMaintenanceMode(enabled, message: _maintenanceMessageController.text.trim().isEmpty ? null : _maintenanceMessageController.text.trim());
      if (resp.isSuccess) {
        setState(() => _maintenanceEnabled = enabled);
        _showSnack(enabled ? 'Maintenance mode enabled' : 'Maintenance mode disabled');
      } else {
        _showSnack(resp.error ?? 'Failed to toggle maintenance', error: true);
      }
    } catch (e) {
      _showSnack('Error toggling maintenance: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearCache() async {
    setState(() => _loading = true);
    try {
      final resp = await _backend.clearCache();
      if (resp.isSuccess) {
        _showSnack('Cache cleared');
      } else {
        _showSnack(resp.error ?? 'Failed to clear cache', error: true);
      }
    } catch (e) {
      _showSnack('Error clearing cache: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _optimizeDatabase() async {
    setState(() => _loading = true);
    try {
      final resp = await _backend.optimizeDatabase();
      if (resp.isSuccess) {
        _showSnack('Database optimized');
      } else {
        _showSnack(resp.error ?? 'Failed to optimize database', error: true);
      }
    } catch (e) {
      _showSnack('Error optimizing database: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runDiagnostics() async {
    setState(() => _loading = true);
    try {
      final resp = await _backend.runDiagnostics();
      if (resp.isSuccess) {
        _showSnack('Diagnostics completed');
      } else {
        _showSnack(resp.error ?? 'Diagnostics failed', error: true);
      }
    } catch (e) {
      _showSnack('Error running diagnostics: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _loading = true);
    try {
      final resp = await _backend.createBackup();
      if (resp.isSuccess) {
        _showSnack('Backup created');
        await _loadBackups();
      } else {
        _showSnack(resp.error ?? 'Failed to create backup', error: true);
      }
    } catch (e) {
      _showSnack('Error creating backup: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreBackup(dynamic backup) async {
    setState(() => _loading = true);
    try {
      final resp = await _backend.restoreBackup();
      if (resp.isSuccess) {
        _showSnack('Backup restored');
      } else {
        _showSnack(resp.error ?? 'Failed to restore backup', error: true);
      }
    } catch (e) {
      _showSnack('Error restoring backup: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleBuilder(
      allowedRoles: const ['systemAdmin'],
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          actions: [
            IconButton(
              onPressed: _loadBackups,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Maintenance Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Switch(
                            value: _maintenanceEnabled,
                            onChanged: _loading ? null : (v) => _toggleMaintenance(v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _maintenanceMessageController,
                        decoration: const InputDecoration(
                          labelText: 'Maintenance Message',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('System Operations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _clearCache,
                            icon: const Icon(Icons.delete_sweep),
                            label: const Text('Clear Cache'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _optimizeDatabase,
                            icon: const Icon(Icons.storage),
                            label: const Text('Optimize Database'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _runDiagnostics,
                            icon: const Icon(Icons.health_and_safety),
                            label: const Text('Run Diagnostics'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Backups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _createBackup,
                            icon: const Icon(Icons.backup),
                            label: const Text('Create Backup'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_error != null)
                        Text(_error!, style: const TextStyle(color: FlownetColors.crimsonRed)),
                      if (_backups.isEmpty && _error == null)
                        const Text('No backups available', style: TextStyle(color: FlownetColors.coolGray)),
                      if (_backups.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _backups.length,
                          itemBuilder: (context, index) {
                            final b = _backups[index];
                            final map = b is Map<String, dynamic> ? b : (b is Map ? Map<String, dynamic>.from(b) : <String, dynamic>{});
                            final name = (map['name'] ?? map['key'] ?? 'Backup').toString();
                            final createdAt = (map['created_at'] ?? map['createdAt'] ?? '').toString();
                            return ListTile(
                              title: Text(name),
                              subtitle: Text(createdAt),
                              trailing: OutlinedButton.icon(
                                onPressed: _loading ? null : () => _restoreBackup(map),
                                icon: const Icon(Icons.restore),
                                label: const Text('Restore'),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      fallback: Scaffold(
        appBar: AppBar(title: const Text('Admin Panel')),
        body: const Center(child: Text('Access restricted')),
      ),
    );
  }
}
