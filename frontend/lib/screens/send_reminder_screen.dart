import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:khono/models/user.dart';
import 'package:khono/services/backend_api_service.dart';
import 'package:khono/theme/flownet_theme.dart';
import 'dart:convert';

class SendReminderScreen extends StatefulWidget {
  final String? initialReportId;

  const SendReminderScreen({
    super.key,
    this.initialReportId,
  });

  @override
  State<SendReminderScreen> createState() => _SendReminderScreenState();
}

class _SendReminderScreenState extends State<SendReminderScreen> {
  final BackendApiService _backendService = BackendApiService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _reports = [];
  List<User> _users = [];

  String? _selectedReportId;
  User? _selectedUser;

  @override
  void initState() {
    super.initState();
    _selectedReportId = widget.initialReportId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load reports and users in parallel
      final results = await Future.wait([
        _backendService.getSignOffReports(page: 1, limit: 100),
        _backendService.getUsers(page: 1, limit: 100),
      ]);

      final reportsResp = results[0];
      final usersResp = results[1];

      // Process Reports
      List<Map<String, dynamic>> loadedReports = [];
      if (reportsResp.isSuccess && reportsResp.data != null) {
        final raw = reportsResp.data;
        List<dynamic> items = const [];
        if (raw is List) {
          items = raw;
        } else if (raw is Map) {
          final d = raw['data'];
          if (d is List) {
            items = d;
          } else if (d is Map) {
            final inner = d['reports'] ?? d['items'] ?? d['data'];
            if (inner is List) {
              items = inner;
            }
          } else {
            final r = raw['reports'];
            if (r is List) {
              items = r;
            } else if (r is Map) {
              final inner = r['items'] ?? r['data'];
              if (inner is List) items = inner;
            } else {
              final i = raw['items'];
              if (i is List) items = i;
            }
          }
        }
        
        loadedReports = items
          .whereType<Map>()
          .map((e) {
            final m = e.cast<String, dynamic>();
            // Try to extract title from content if needed
            final c = m['content'];
            if (c is String) {
              try {
                final decoded = jsonDecode(c);
                if (decoded is Map) m['content'] = Map<String, dynamic>.from(decoded);
              } catch (_) {}
            }
            return m;
          })
          .toList();
      }

      // Process Users
      List<User> loadedUsers = [];
      if (usersResp.isSuccess && usersResp.data != null) {
        final raw = usersResp.data;
        List<dynamic> items = [];
        if (raw is Map) {
           items = raw['users'] ?? raw['data'] ?? raw['items'] ?? [];
        } else if (raw is List) {
           items = raw;
        }
        
        loadedUsers = items
            .map((e) {
              try {
                // Ensure we have a valid map
                final data = e is Map<String, dynamic> ? e : (e as Map).cast<String, dynamic>();
                // Patch name if missing but other fields exist
                if (data['name'] == null || data['name'].toString().isEmpty) {
                   data['name'] = data['fullName'] ?? data['full_name'] ?? data['username'] ?? data['email']?.toString().split('@').first ?? '';
                }
                return User.fromJson(data);
              } catch (_) {
                return null;
              }
            })
            .whereType<User>()
            .toList();
      }

      if (mounted) {
        setState(() {
          _reports = loadedReports;
          _users = loadedUsers;
          
          // Set initial report if passed and valid
          if (_selectedReportId != null && !_reports.any((r) => r['id'].toString() == _selectedReportId)) {
            _selectedReportId = null;
          }
          // Default to first report if none selected and available
          if (_selectedReportId == null && _reports.isNotEmpty) {
            _selectedReportId = _reports.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendReminder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReportId == null || _selectedUser == null) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      // The backend currently expects a role. 
      // We will send the selected user's role.
      // Ideally, the backend should support sending to a specific user ID.
      // For now, we use the role as per the existing backend implementation,
      // but the UI allowed selecting a specific user which improves UX.
      
      final role = _selectedUser!.role.name; 
      // Note: UserRole enum name matches backend expectation (e.g. 'client_reviewer')
      
      final response = await _backendService.sendReminderForReport(
        _selectedReportId!,
        role,
        recipientId: _selectedUser!.id,
      );

      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder sent successfully!'),
              backgroundColor: FlownetColors.electricBlue,
            ),
          );
          context.pop(); // Go back to dashboard
        } else {
          setState(() {
            _errorMessage = response.error ?? 'Failed to send reminder';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _getReportTitle(Map<String, dynamic> report) {
    final title = report['reportTitle'] ?? 
            report['report_title'] ?? 
            report['name'] ??
            report['reportName'] ??
            (report['content'] is Map ? (report['content']['reportTitle'] ?? report['content']['title']) : null) ?? 
            report['title'] ?? 
            'Untitled Report';
    return title.toString();
  }

  String _formatUserName(User user) {
    String name = user.name;
    if (name.isEmpty) {
      name = user.email;
    }
    
    // If name looks like an email, strip domain
    if (name.contains('@')) {
      name = name.split('@').first;
    }
    
    // Replace common separators with spaces
    name = name.replaceAll('.', ' ').replaceAll('_', ' ').replaceAll('-', ' ');
    
    // Capitalize each word
    if (name.isNotEmpty) {
      name = name.split(' ').where((w) => w.isNotEmpty).map((word) {
        if (word.length > 1) {
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }
        return word.toUpperCase();
      }).join(' ');
    }
    
    return name.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Reminder For Report'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    
                    const Text(
                      'Select Report',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedReportId),
                      initialValue: _selectedReportId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Choose a report...',
                      ),
                      items: _reports.map((r) {
                        final title = _getReportTitle(r);
                        final id = r['id']?.toString() ?? '';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            '$title (ID: $id)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedReportId = value);
                      },
                      validator: (value) => value == null ? 'Please select a report' : null,
                      isExpanded: true,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Select Recipient',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<User>(
                      key: ValueKey(_selectedUser),
                      initialValue: _selectedUser,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Choose a recipient...',
                      ),
                      items: _users.isEmpty 
                          ? null 
                          : _users.map((u) {
                              final displayName = _formatUserName(u);
                              return DropdownMenuItem<User>(
                                value: u,
                                child: Text(displayName),
                              );
                            }).toList(),
                      disabledHint: const Text('No users found'),
                      onChanged: (value) {
                        setState(() => _selectedUser = value);
                      },
                      validator: (value) => value == null ? 'Please select a recipient' : null,
                      isExpanded: true,
                    ),

                    const SizedBox(height: 48),
                    
                    ElevatedButton(
                      onPressed: _isSending ? null : _sendReminder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: FlownetColors.electricBlue,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Send Reminder',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
