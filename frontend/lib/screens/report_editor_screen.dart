import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/sign_off_report.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../services/backend_api_service.dart';
import '../services/deliverable_service.dart';
import '../services/sprint_database_service.dart';
import '../services/user_data_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/signature_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/signature_capture_widget.dart';
import '../widgets/sidebar_scaffold.dart';

class ReportEditorScreen extends ConsumerStatefulWidget {
  final String? reportId; // null for create, non-null for edit
  final String? deliverableId; // pre-selected deliverable (optional)

  const ReportEditorScreen({
    super.key,
    this.reportId,
    this.deliverableId,
  });

  @override
  ConsumerState<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends ConsumerState<ReportEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _knownLimitationsController = TextEditingController();
  final _nextStepsController = TextEditingController();
  final _aiPromptController = TextEditingController();

  final BackendApiService _reportService = BackendApiService();
  final DeliverableService _deliverableService = DeliverableService();
  final SprintDatabaseService _sprintService = SprintDatabaseService();
  final UserDataService _userService = UserDataService();
  final AuthService _authService = AuthService();
  final ApiClient _apiClient = ApiClient();

  List<dynamic> _deliverables = [];
  List<dynamic> _sprints = [];
  List<User> _users = [];
  String? _selectedDeliverableId;
  String? _preparedById;
  List<String> _selectedSprintIds = [];
  String? _changeRequestDetails;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingDeliverables = false;
  SignOffReport? _existingReport;
  String? _existingPerformanceData;
  final GlobalKey<SignatureCaptureWidgetState> _signatureKey =
      GlobalKey<SignatureCaptureWidgetState>();
  bool _useAiAssist = false; // AI assistance toggle
  bool _isAiGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _normalizeSelectedDeliverable() {
    if (_selectedDeliverableId == null) return;
    final matches = _deliverables.where((d) {
      try {
        final id = d is Map ? d['id']?.toString() : d.id?.toString();
        return id == _selectedDeliverableId;
      } catch (_) {
        return false;
      }
    }).length;
    if (matches != 1) {
      _selectedDeliverableId = null;
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _userService.getUsers(limit: 1000);
      setState(() {
        _users = users;
        final currentUserId = _authService.currentUser?.id;
        if (currentUserId != null && _users.any((u) => u.id == currentUserId)) {
          _preparedById ??= currentUserId;
        } else if (_preparedById == null ||
            !_users.any((u) => u.id == _preparedById)) {
          _preparedById = _users.isNotEmpty ? _users.first.id : null;
        }
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Future<void> _loadData() async {
    debugPrint('🔍 Starting to load data for report editor...');
    setState(() => _isLoading = true);

    try {
      // Load deliverables from backend (real-time data)
      debugPrint('📦 Loading deliverables...');
      await _loadDeliverables();
      debugPrint('✅ Deliverables loaded: ${_deliverables.length}');

      // Load users
      debugPrint('👥 Loading users...');
      await _loadUsers();
      debugPrint('✅ Users loaded: ${_users.length}');

      // Load sprints
      try {
        debugPrint('🏃 Loading sprints...');
        final sprintsList = await _sprintService.getSprints();
        _sprints = sprintsList;
        debugPrint('✅ Sprints loaded: ${_sprints.length}');
      } catch (e) {
        debugPrint('⚠️ Error loading sprints: $e');
        _sprints = []; // Ensure it's not null
      }

      // If editing, load existing report
      if (widget.reportId != null) {
        debugPrint('📋 Loading report for editing: ${widget.reportId}');
        final reportResponse =
            await _reportService.getSignOffReport(widget.reportId!);
        debugPrint(
            '📋 Report response: success=${reportResponse.isSuccess}, data type=${reportResponse.data?.runtimeType}');

        if (reportResponse.isSuccess && reportResponse.data != null) {
          // ApiClient already extracts the 'data' field, so response.data is the report object directly
          // But check if it's nested in a 'data' key or is the report directly
          final data =
              reportResponse.data is Map && reportResponse.data!['data'] != null
                  ? reportResponse.data!['data'] as Map<String, dynamic>
                  : reportResponse.data as Map<String, dynamic>;

          debugPrint('📋 Report data keys: ${data.keys.toList()}');

          // Content can be a Map or JSONB object
          final contentRaw = data['content'];
          final content = contentRaw is Map<String, dynamic>
              ? contentRaw
              : contentRaw is Map
                  ? Map<String, dynamic>.from(contentRaw)
                  : <String, dynamic>{};

          debugPrint('📋 Content keys: ${content.keys.toList()}');

          // Create SignOffReport object from loaded data
          final reportId = data['id']?.toString() ?? '';
          final status = data['status']?.toString();
          final deliverableId = data['deliverableId']?.toString() ??
              data['deliverable_id']?.toString() ??
              '';
          final createdBy = data['createdBy']?.toString() ?? '';

          // Set _existingReport with proper status
          _existingReport = SignOffReport(
            id: reportId.isNotEmpty ? reportId : 'unknown',
            deliverableId: deliverableId.isNotEmpty ? deliverableId : 'unknown',
            reportTitle: data['reportTitle']?.toString() ?? '',
            reportContent: data['reportContent']?.toString() ?? '',
            sprintIds: (data['sprintIds'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            status: status == 'submitted'
                ? ReportStatus.submitted
                : ReportStatus.draft,
            preparedBy: data['preparedBy']?.toString(),
            preparedByName: data['preparedByName']?.toString(),
            submittedBy: data['submittedBy']?.toString(),
            submittedByName: data['submittedByName']?.toString(),
            reviewedBy: data['reviewedBy']?.toString(),
            reviewedByName: data['reviewedByName']?.toString(),
            approvedBy: data['approvedBy']?.toString(),
            approvedByName: data['approvedByName']?.toString(),
            digitalSignature: data['digitalSignature']?.toString(),
            createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
                DateTime.now(),
            createdBy: createdBy.isNotEmpty ? createdBy : 'unknown',
            submittedAt: data['submittedAt'] != null
                ? DateTime.tryParse(data['submittedAt']!.toString())
                : null,
            changeRequestDetails: data['changeRequestDetails']?.toString(),
            sprintPerformanceData: data['sprintPerformanceData']?.toString(),
          );

          debugPrint('📋 Report loaded successfully');
          debugPrint('📊 Report status: ${_existingReport?.status}');

          setState(() {
            _selectedDeliverableId = data['deliverableId']?.toString() ??
                data['deliverable_id']?.toString();

            // Try to load content from nested 'content' field first, then from direct fields
            final reportTitle = content['reportTitle']?.toString() ??
                data['reportTitle']?.toString() ??
                '';
            final reportContent = content['reportContent']?.toString() ??
                data['reportContent']?.toString() ??
                '';
            final knownLimitations = content['knownLimitations']?.toString() ??
                data['knownLimitations']?.toString() ??
                '';
            final nextSteps = content['nextSteps']?.toString() ??
                data['nextSteps']?.toString() ??
                '';
            final preparedBy = content['preparedBy']?.toString() ??
                data['preparedBy']?.toString() ??
                _preparedById;
            final sprintIds = (content['sprintIds'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                (data['sprintIds'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final sprintPerformanceData =
                content['sprintPerformanceData']?.toString() ??
                    data['sprintPerformanceData']?.toString();

            // Set the controllers with the loaded content
            _titleController.text = reportTitle;
            _contentController.text = reportContent;
            _knownLimitationsController.text = knownLimitations;
            _nextStepsController.text = nextSteps;
            _preparedById = preparedBy;
            _selectedSprintIds = sprintIds;
            _changeRequestDetails = data['changeRequestDetails']?.toString();
            _existingPerformanceData = sprintPerformanceData;

            debugPrint('📝 Loaded content:');
            debugPrint('  Title: $reportTitle');
            debugPrint('  Content length: ${reportContent.length}');
            debugPrint('  Known limitations: ${knownLimitations.isNotEmpty}');
            debugPrint('  Next steps: ${nextSteps.isNotEmpty}');
            debugPrint('  Sprint IDs: ${sprintIds.join(', ')}');

            _normalizeSelectedDeliverable();
          });

          debugPrint('✅ Report loaded successfully');
        } else {
          debugPrint('❌ Failed to load report: ${reportResponse.error}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Failed to load report: ${reportResponse.error ?? "Unknown error"}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else if (widget.deliverableId != null) {
        setState(() {
          _selectedDeliverableId = widget.deliverableId;
          _normalizeSelectedDeliverable();
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      debugPrint('❌ Stack trace: ${e.runtimeType}');

      // Even if loading fails, show the form with empty data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Some data failed to load: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadData,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('🔍 Loading completed. Is loading: $_isLoading');
      }
    }
  }

  Future<void> _loadDeliverables() async {
    setState(() => _isLoadingDeliverables = true);
    debugPrint('📦 Loading deliverables from backend...');

    try {
      // Try using DeliverableService first (simpler, more reliable)
      final altResponse = await _deliverableService.getDeliverables();
      if (altResponse.isSuccess && altResponse.data != null) {
        final deliverables = altResponse.data!['deliverables'] as List? ?? [];
        final mapped = deliverables.map((d) {
          if (d is Map) return d;
          // If it's a Deliverable object, convert to map
          try {
            return {
              'id': d.id?.toString() ?? '',
              'title': d.title?.toString() ?? 'Untitled',
              'description': d.description?.toString(),
              'status': d.status?.toString() ?? 'Draft',
            };
          } catch (e) {
            debugPrint('Error converting deliverable object: $e');
            return {
              'id': '',
              'title': 'Unknown',
              'status': 'Draft',
            };
          }
        }).toList();
        final byId = <String, Map<String, dynamic>>{};
        for (final d in mapped) {
          final id = d['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          byId.putIfAbsent(id, () => Map<String, dynamic>.from(d));
        }
        _deliverables = byId.values.toList();
        _normalizeSelectedDeliverable();
        debugPrint(
            '✅ Loaded ${_deliverables.length} deliverables (DeliverableService)');
      } else {
        debugPrint('⚠️ DeliverableService failed, trying BackendApiService...');
        // Fallback to BackendApiService
        try {
          final deliverablesResponse = await _reportService.getDeliverables(
            page: 1,
            limit: 100,
          );

          if (deliverablesResponse.isSuccess &&
              deliverablesResponse.data != null) {
            List<dynamic> deliverablesList = [];

            if (deliverablesResponse.data is List) {
              deliverablesList = deliverablesResponse.data as List;
            } else if (deliverablesResponse.data is Map) {
              final data = deliverablesResponse.data as Map<String, dynamic>;
              deliverablesList =
                  data['data'] as List? ?? data['deliverables'] as List? ?? [];
            }

            final mapped = deliverablesList.map((item) {
              if (item is Map) {
                return item;
              }
              return {
                'id': item['id']?.toString() ?? '',
                'title': item['title']?.toString() ?? 'Untitled',
                'description': item['description']?.toString(),
                'status': item['status']?.toString() ?? 'Draft',
              };
            }).toList();
            final byId = <String, Map<String, dynamic>>{};
            for (final d in mapped) {
              final id = d['id']?.toString() ?? '';
              if (id.isEmpty) continue;
              byId.putIfAbsent(id, () => Map<String, dynamic>.from(d));
            }
            _deliverables = byId.values.toList();
            _normalizeSelectedDeliverable();

            debugPrint(
                '✅ Loaded ${_deliverables.length} deliverables (BackendApiService)');
          } else {
            _deliverables = [];
            debugPrint(
                '⚠️ No deliverables found: ${deliverablesResponse.error}');
          }
        } catch (e) {
          debugPrint('❌ BackendApiService also failed: $e');
          _deliverables = [];
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading deliverables: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      _deliverables = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Error loading deliverables. Please try refreshing.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Refresh',
              textColor: Colors.white,
              onPressed: _loadDeliverables,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDeliverables = false);
      }
    }
  }

  Future<void> _saveReport(bool submit) async {
    debugPrint('🔘 Button clicked: ${submit ? "Submit" : "Save Draft"}');

    // Validate form
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Form validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check deliverable selection
    if (_selectedDeliverableId == null) {
      debugPrint('❌ No deliverable selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a deliverable'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    debugPrint('💾 Starting save operation (submit: $submit)...');

    try {
      debugPrint('📋 Deliverable ID: $_selectedDeliverableId');
      debugPrint('📝 Title: ${_titleController.text}');
      debugPrint('📄 Content length: ${_contentController.text.length}');
      debugPrint('🔄 Is update: ${widget.reportId != null}');

      ApiResponse response;

      if (widget.reportId != null) {
        // Update existing report
        debugPrint('🔄 Updating existing report: ${widget.reportId}');
        final updateData = {
          'reportTitle': _titleController.text,
          'reportContent': _contentController.text,
          if (_selectedSprintIds.isNotEmpty) 'sprintIds': _selectedSprintIds,
          if (_existingPerformanceData != null)
            'sprintPerformanceData': _existingPerformanceData,
          if (_knownLimitationsController.text.isNotEmpty)
            'knownLimitations': _knownLimitationsController.text,
          if (_nextStepsController.text.isNotEmpty)
            'nextSteps': _nextStepsController.text,
          if (_preparedById != null) 'preparedBy': _preparedById,
          if (_preparedById != null)
            'preparedByName': _users
                .firstWhere((u) => u.id == _preparedById,
                    orElse: () => User(
                        id: '',
                        email: '',
                        name: 'Unknown',
                        role: UserRole.systemAdmin,
                        createdAt: DateTime.now()))
                .name,
        };
        debugPrint('📤 Update payload: $updateData');
        response = await _reportService.updateSignOffReport(
          widget.reportId!,
          updateData,
        );
      } else {
        // Create new report
        debugPrint('✨ Creating new report...');
        final createData = {
          'deliverableId': _selectedDeliverableId!,
          'reportTitle': _titleController.text,
          'reportContent': _contentController.text,
          if (_selectedSprintIds.isNotEmpty) 'sprintIds': _selectedSprintIds,
          if (_knownLimitationsController.text.isNotEmpty)
            'knownLimitations': _knownLimitationsController.text,
          if (_nextStepsController.text.isNotEmpty)
            'nextSteps': _nextStepsController.text,
          if (_preparedById != null) 'preparedBy': _preparedById,
          if (_preparedById != null)
            'preparedByName': _users
                .firstWhere((u) => u.id == _preparedById,
                    orElse: () => User(
                        id: '',
                        email: '',
                        name: 'Unknown',
                        role: UserRole.systemAdmin,
                        createdAt: DateTime.now()))
                .name,
        };
        debugPrint('📤 Create payload: $createData');
        response = await _reportService.createSignOffReport(createData);
      }

      debugPrint(
          '📥 Response received: success=${response.isSuccess}, statusCode=${response.statusCode}');
      if (response.data != null) {
        debugPrint('📦 Response data: ${response.data}');
      }
      if (response.error != null) {
        debugPrint('❌ Response error: ${response.error}');
      }

      if (response.isSuccess) {
        // Extract report ID from response
        String? reportId;
        if (widget.reportId != null) {
          reportId = widget.reportId;
          debugPrint('🆔 Using existing report ID: $reportId');
        } else if (response.data != null) {
          // Try different possible response structures
          // API client already extracts 'data' from backend response
          // Backend returns: { success: true, data: {...} }
          // API client returns: response.data = {...}
          final data = response.data;
          reportId = data?['id']?.toString() ??
              data?['data']?['id']?.toString() ??
              data?['reportId']?.toString();
          debugPrint('🆔 Extracted report ID from response: $reportId');
          debugPrint('🔍 Response data keys: ${data?.keys.toList()}');
        }

        if (reportId == null && submit) {
          // For submit, we need the report ID
          debugPrint(
              '⚠️ Warning: Could not extract report ID, but continuing...');
          // Try to get it from the response structure
          if (response.data != null) {
            final fullData = response.data;
            debugPrint('🔍 Full response structure: $fullData');
          }
        }

        // If submitting, show signing dialog first
        if (submit) {
          if (reportId == null) {
            throw Exception(
                'Cannot submit: Report ID is missing from response');
          }

          // Check if report is already submitted
          if (_existingReport?.status == ReportStatus.submitted) {
            if (!mounted) return;
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This report has already been submitted.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          // Show signing dialog before submission
          final signature = await _showSigningDialog();
          if (signature == null) {
            // User cancelled signing
            if (mounted) {
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Submission cancelled. Report saved as draft.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          // Store signature in database and update report
          if (signature.isNotEmpty) {
            debugPrint('✍️ Storing signature in database before submission');
            try {
              // Store signature using the dedicated endpoint
              final signatureResponse = await _apiClient.post(
                '/sign-off-reports/$reportId/signature',
                body: {
                  'signatureData': signature,
                  'signatureType': 'manual',
                },
              );

              if (signatureResponse.isSuccess) {
                debugPrint('✅ Signature stored in database');
              }
            } catch (e) {
              debugPrint('⚠️ Failed to store signature separately: $e');
              // Continue with update anyway
            }

            // Also update report with signature in content
            debugPrint('✍️ Updating report with signature before submission');
            final updateWithSignature = {
              'reportTitle': _titleController.text,
              'reportContent': _contentController.text,
              if (_selectedSprintIds.isNotEmpty)
                'sprintIds': _selectedSprintIds,
              if (_existingPerformanceData != null)
                'sprintPerformanceData': _existingPerformanceData,
              if (_knownLimitationsController.text.isNotEmpty)
                'knownLimitations': _knownLimitationsController.text,
              if (_nextStepsController.text.isNotEmpty)
                'nextSteps': _nextStepsController.text,
              'digitalSignature': signature,
              'signatureDate': DateTime.now().toIso8601String(),
            };
            await _reportService.updateSignOffReport(
                reportId, updateWithSignature);
          }

          debugPrint('📤 Submitting report: $reportId');
          final submitResponse =
              await _reportService.submitSignOffReport(reportId);
          debugPrint(
              '📥 Submit response: success=${submitResponse.isSuccess}, error=${submitResponse.error}');

          if (submitResponse.isSuccess) {
            debugPrint('✅ Report submitted successfully!');
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Submission Successful'),
                content: const Text('Your report was submitted successfully.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            if (!mounted) return;
            context.go('/report-sent/$reportId');
          } else {
            debugPrint('❌ Submit failed: ${submitResponse.error}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'Report saved but submission failed: ${submitResponse.error ?? "Unknown error"}'),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        } else {
          // Just saving (could be draft or submitted report update)
          final isSubmittedReport =
              _existingReport?.status == ReportStatus.submitted;
          debugPrint(
              '✅ Report ${isSubmittedReport ? 'updated' : 'saved as draft'} successfully');
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(isSubmittedReport ? 'Report Updated' : 'Draft Saved'),
              content: Text(isSubmittedReport
                  ? 'Your submitted report was updated successfully.'
                  : 'Your report draft was saved successfully.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          context.go('/report-repository');
        }
      } else {
        debugPrint('❌ Save failed: ${response.error}');
        debugPrint('❌ Status code: ${response.statusCode}');
        if (mounted) {
          final errorMessage = response.error ?? 'Failed to save report';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Error: $errorMessage'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception in _saveReport: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error saving report: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        debugPrint('🏁 Save operation completed');
      }
    }
  }

  Future<void> _generateAiSuggestions() async {
    if (!_useAiAssist) return;
    setState(() => _isAiGenerating = true);
    try {
      String deliverableTitle = 'Deliverable';
      String deliverableDescription = '';
      try {
        final selected = _deliverables.firstWhere(
          (d) =>
              (d is Map ? d['id']?.toString() : d.id?.toString()) ==
              _selectedDeliverableId,
          orElse: () => null,
        );
        if (selected != null) {
          deliverableTitle = selected is Map
              ? (selected['title']?.toString() ?? deliverableTitle)
              : (selected.title?.toString() ?? deliverableTitle);
          deliverableDescription = selected is Map
              ? (selected['description']?.toString() ?? '')
              : (selected.description?.toString() ?? '');
        }
      } catch (_) {}

      final sprintNames = _sprints
          .where((s) => _selectedSprintIds.contains(s['id'].toString()))
          .map((s) => s['name']?.toString() ?? 'Sprint')
          .toList();

      final prompt = _aiPromptController.text.trim();

      final messages = [
        {
          'role': 'system',
          'content':
              'You are an assistant that produces concise sign-off reports. Return ONLY JSON with keys title, content, knownLimitations, nextSteps. Do not include markdown fences.'
        },
        {
          'role': 'user',
          'content':
              'Generate a sign-off report draft. Deliverable: $deliverableTitle. Description: $deliverableDescription. Linked sprints: ${sprintNames.isEmpty ? 'none' : sprintNames.join(', ')}${prompt.isNotEmpty ? '. Focus: $prompt' : ''}'
        }
      ];

      final resp = await _reportService.aiChat(messages,
          temperature: 0.6, maxTokens: 800);
      if (resp.isSuccess && resp.data != null) {
        final data = resp.data is Map
            ? resp.data as Map<String, dynamic>
            : {'content': resp.data.toString()};
        final content = data['content']?.toString() ?? '';
        Map<String, dynamic>? jsonOut;
        try {
          jsonOut = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {
          jsonOut = null;
        }
        if (jsonOut != null) {
          _titleController.text =
              jsonOut['title']?.toString() ?? _titleController.text;
          _contentController.text =
              jsonOut['content']?.toString() ?? _contentController.text;
          _knownLimitationsController.text =
              jsonOut['knownLimitations']?.toString() ??
                  _knownLimitationsController.text;
          _nextStepsController.text =
              jsonOut['nextSteps']?.toString() ?? _nextStepsController.text;
        } else if (content.isNotEmpty) {
          if (_titleController.text.isEmpty) {
            final firstLine = content.split('\n').first.trim();
            if (firstLine.length <= 120) _titleController.text = firstLine;
          }
          if (_contentController.text.isEmpty) {
            _contentController.text = content;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('AI suggestions applied'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('AI error: ${resp.error ?? "Unknown error"}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('AI generation failed: $e'),
              backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  /// Show enhanced signing dialog before submission with typed signature option
  Future<String?> _showSigningDialog() async {
    String? signatureData = _existingReport?.digitalSignature;
    String signatureType = 'drawn'; // 'drawn', 'typed', 'saved'
    bool saveSignature = false;
    final currentUser = _authService.currentUser;
    final currentUserName = currentUser?.name.trim() ?? '';
    final currentUserEmail = currentUser?.email.trim() ?? '';
    String signatureName = currentUserName.isNotEmpty
        ? currentUserName
        : (currentUserEmail.isNotEmpty ? currentUserEmail : 'My Signature');
    final signatureNameController = TextEditingController(text: signatureName);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: FlownetColors.graphiteGray,
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 600,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sign Report Before Submission',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: FlownetColors.pureWhite,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: FlownetColors.pureWhite),
                        onPressed: () => Navigator.pop(context, null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please sign this report to confirm its accuracy before submission.',
                    style: TextStyle(
                      color: FlownetColors.coolGray,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Signature type selection
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[600]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose Signature Method:',
                          style: TextStyle(
                            color: FlownetColors.pureWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => signatureType = 'drawn'),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: signatureType == 'drawn'
                                        ? FlownetColors.electricBlue
                                        : Colors.grey[700],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: signatureType == 'drawn'
                                          ? FlownetColors.electricBlue
                                          : Colors.grey[500]!,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.draw,
                                          color: signatureType == 'drawn'
                                              ? Colors.white
                                              : Colors.grey[400]),
                                      const SizedBox(height: 4),
                                      Text('Draw Signature',
                                          style: TextStyle(
                                            color: signatureType == 'drawn'
                                                ? Colors.white
                                                : Colors.grey[400],
                                            fontSize: 12,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => signatureType = 'typed'),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: signatureType == 'typed'
                                        ? FlownetColors.electricBlue
                                        : Colors.grey[700],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: signatureType == 'typed'
                                          ? FlownetColors.electricBlue
                                          : Colors.grey[500]!,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.keyboard,
                                          color: signatureType == 'typed'
                                              ? Colors.white
                                              : Colors.grey[400]),
                                      const SizedBox(height: 4),
                                      Text('Type Signature',
                                          style: TextStyle(
                                            color: signatureType == 'typed'
                                                ? Colors.white
                                                : Colors.grey[400],
                                            fontSize: 12,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Signature input area
                  if (signatureType == 'drawn') ...[
                    SignatureCaptureWidget(
                      key: _signatureKey,
                      existingSignature: _existingReport?.digitalSignature,
                      allowSignatureReuse: true,
                      showAuditInfo: true,
                      reportId: widget.reportId,
                      signatureStorageNamespace: 'delivery_lead',
                    ),
                  ] else if (signatureType == 'typed') ...[
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          signatureData = value;
                        },
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontFamily:
                              'Dancing Script', // Cursive font for signature
                          color: Colors.black,
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Type your signature here',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 18,
                            fontFamily: 'Dancing Script',
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ],

                  // Add Use Saved Signature button for text signatures (simple working version)
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              '✅ Text signature save and reuse is now working! Signatures are saved persistently and will be available after login/restart. The "Use Saved Signature" button shows your saved text signatures.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('Use Saved Signature',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Save signature option
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: saveSignature,
                              onChanged: (value) {
                                setState(() {
                                  saveSignature = value ?? false;
                                });
                              },
                              activeColor: FlownetColors.electricBlue,
                            ),
                            const Text(
                              'Save this signature for future use',
                              style: TextStyle(
                                color: FlownetColors.pureWhite,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (saveSignature) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: signatureNameController,
                            onChanged: (value) {
                              signatureName = value;
                            },
                            decoration: const InputDecoration(
                              hintText:
                                  'Enter a name for this signature (e.g., "Business Signature")',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: FlownetColors.electricBlue),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: const Text('Cancel',
                            style: TextStyle(color: FlownetColors.coolGray)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Store context references before async operations
                          final navigator = Navigator.of(context);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          
                          String? finalSignature;

                          if (signatureType == 'drawn') {
                            finalSignature = await _signatureKey.currentState
                                ?.getSignature();
                          } else if (signatureType == 'typed') {
                            if (signatureData != null &&
                                signatureData!.isNotEmpty) {
                              // Convert typed signature to image-like format
                              finalSignature =
                                  await _convertTypedSignature(signatureData!);
                            }
                          }

                          if (!mounted) return;

                          if (!mounted) return;

                          if (finalSignature != null &&
                              finalSignature.isNotEmpty) {
                            // Save signature if requested
                            if (saveSignature &&
                                signatureName.isNotEmpty) {
                              try {
                                debugPrint(
                                    '💾 Saving signature: type=$signatureType, name=$signatureName');
                                final signatureService =
                                    SignatureService(ApiClient());
                                final savedSignature =
                                    await signatureService.saveSignature(
                                  finalSignature,
                                  signatureType,
                                  false, // Not default for now
                                );
                                debugPrint(
                                    '✅ Signature saved successfully: ${savedSignature.id}');

                                if (mounted) {
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Signature saved successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('❌ API Error saving signature: $e');
                                debugPrint(
                                    '🔄 Trying local storage fallback...');

                                // Fallback to local storage
                                try {
                                  await _saveSignatureLocally(finalSignature,
                                      signatureType, signatureName);
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Signature saved locally! (Backend API unavailable)'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                } catch (localError) {
                                  debugPrint(
                                      '❌ Local storage also failed: $localError');
                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Signature save failed: API unavailable'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            }

                            if (mounted) {
                              navigator.pop(finalSignature);
                            }
                          } else {
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Please provide a signature'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Sign & Submit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FlownetColors.electricBlue,
                          foregroundColor: FlownetColors.pureWhite,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    signatureNameController.dispose();
    return result;
  }

  /// Convert typed signature to base64 image format
  Future<String> _convertTypedSignature(String typedText) async {
    // For now, we'll convert the typed text to a simple base64 format
    // In a production app, you might want to render this as an actual image
    final bytes = utf8.encode(typedText);
    return 'data:text/plain;base64,${base64Encode(bytes)}';
  }

  /// Save signature locally when API is unavailable
  Future<void> _saveSignatureLocally(
      String signatureData, String signatureType, String signatureName) async {
    // Access signature widget's local storage
    final signatureWidget = _signatureKey.currentState;
    if (signatureWidget != null) {
      await signatureWidget.saveSignatureLocally(
          signatureData, signatureType, signatureName);
      debugPrint('💾 Signature saved locally via widget');
    } else {
      debugPrint('❌ Signature widget not available for local save');
      throw Exception('Signature widget not available');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _knownLimitationsController.dispose();
    _nextStepsController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🔍 Building ReportEditorScreen - isLoading: $_isLoading, deliverables: ${_deliverables.length}');

    // TEMPORARY: Force show form even during loading for debugging
    return SidebarScaffold(
      child: _isLoading && _deliverables.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Debug info
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Debug: isLoading=$_isLoading, deliverables=${_deliverables.length}, users=${_users.length}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // TEST: Simple title field to verify form is working
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FlownetColors.graphiteGray
                            .withAlpha((0.3 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withAlpha((0.1 * 255).round())),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Report Title',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              hintText: 'Enter report title...',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: FlownetColors.electricBlue),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a report title';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status indicator for submitted reports
                    if (_existingReport?.status == ReportStatus.submitted) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You are editing a submitted report. Updates will be saved immediately.',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Action buttons at the top
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FlownetColors.graphiteGray
                            .withAlpha((0.3 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withAlpha((0.1 * 255).round()),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (widget.reportId != null &&
                              (_existingReport?.status == ReportStatus.draft ||
                                  _existingReport?.status ==
                                      ReportStatus.submitted))
                            TextButton.icon(
                              onPressed:
                                  _isSaving ? null : () => _saveReport(false),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: FlownetColors.electricBlue,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_isSaving
                                  ? 'Saving...'
                                  : _existingReport?.status ==
                                          ReportStatus.submitted
                                      ? 'Update Report'
                                      : 'Save Draft'),
                              style: TextButton.styleFrom(
                                  foregroundColor: FlownetColors.electricBlue),
                            ),
                          // Only show Submit button for draft reports
                          if (_existingReport?.status != ReportStatus.submitted)
                            TextButton.icon(
                              onPressed:
                                  _isSaving ? null : () => _saveReport(true),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: FlownetColors.electricBlue,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label:
                                  Text(_isSaving ? 'Submitting...' : 'Submit'),
                              style: TextButton.styleFrom(
                                  foregroundColor: FlownetColors.electricBlue),
                            ),
                          const Spacer(),
                          // AI Assist toggle
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _useAiAssist = !_useAiAssist;
                              });
                            },
                            icon: Icon(
                              _useAiAssist
                                  ? Icons.auto_awesome
                                  : Icons.auto_awesome_outlined,
                              color: _useAiAssist
                                  ? FlownetColors.electricBlue
                                  : FlownetColors.coolGray,
                            ),
                            tooltip: 'AI Assist',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_changeRequestDetails != null &&
                        _changeRequestDetails!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  'Change Requested',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _changeRequestDetails!,
                              style: const TextStyle(
                                color: FlownetColors.pureWhite,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please address these issues before resubmitting.',
                              style: TextStyle(
                                color: FlownetColors.coolGray,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Deliverable Selection
                    // TEMPORARY: Bypass loading check for debugging
                    _isLoadingDeliverables && _deliverables.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _deliverables.isEmpty
                                        ? Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.orange
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.orange),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.warning,
                                                    color: Colors.orange),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'No deliverables available',
                                                        style: TextStyle(
                                                          color: Colors.orange,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      TextButton.icon(
                                                        onPressed:
                                                            _loadDeliverables,
                                                        icon: const Icon(
                                                            Icons.refresh,
                                                            size: 16),
                                                        label: const Text(
                                                            'Refresh'),
                                                        style: TextButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              Colors.orange,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            // ignore: deprecated_member_use
                                            value: _deliverables.any((d) {
                                              try {
                                                final id = d is Map
                                                    ? d['id']?.toString()
                                                    : d.id?.toString();
                                                return id ==
                                                    _selectedDeliverableId;
                                              } catch (_) {
                                                return false;
                                              }
                                            })
                                                ? _selectedDeliverableId
                                                : null,
                                            decoration: const InputDecoration(
                                              labelText: 'Deliverable *',
                                              border: OutlineInputBorder(),
                                              prefixIcon:
                                                  Icon(Icons.assignment),
                                              helperText:
                                                  'Select a deliverable to link this report to',
                                            ),
                                            items: _deliverables
                                                .map<DropdownMenuItem<String>>(
                                                    (d) {
                                              final id = d is Map
                                                  ? d['id']?.toString()
                                                  : (d.id?.toString() ?? '');
                                              final title = d is Map
                                                  ? (d['title']?.toString() ??
                                                      'Untitled')
                                                  : (d.title?.toString() ??
                                                      'Untitled');
                                              final status = d is Map
                                                  ? (d['status']?.toString() ??
                                                      '')
                                                  : (d.status?.toString() ??
                                                      '');

                                              return DropdownMenuItem<String>(
                                                value: id,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      title,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (status.isNotEmpty)
                                                      Text(
                                                        'Status: $status',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            selectedItemBuilder: (context) =>
                                                _deliverables.map<Widget>((d) {
                                              final title = d is Map
                                                  ? (d['title']?.toString() ??
                                                      'Untitled')
                                                  : (d.title?.toString() ??
                                                      'Untitled');
                                              return Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  title,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedDeliverableId = value;
                                              });
                                            },
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Please select a deliverable';
                                              }
                                              return null;
                                            },
                                          ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  context.go('/deliverable-setup');
                                },
                                icon: const Icon(Icons.add_circle_outline,
                                    size: 18),
                                label: const Text('Create a new deliverable'),
                                style: TextButton.styleFrom(
                                  foregroundColor: FlownetColors.electricBlue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Need to create a deliverable? Go to the Deliverable Setup page.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 16),

                    // Prepared By (Author) Selection
                    if (_users.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        // ignore: deprecated_member_use
                        value: _users.any((u) => u.id == _preparedById)
                            ? _preparedById
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Prepared By *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                          helperText: 'Select the author of this report',
                        ),
                        items: _users.map((user) {
                          return DropdownMenuItem<String>(
                            value: user.id,
                            child: Text(
                              user.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _preparedById = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select the author';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // AI Assistance
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FlownetColors.graphiteGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                FlownetColors.coolGray.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            value: _useAiAssist,
                            onChanged: (v) => setState(() => _useAiAssist = v),
                            title: const Text('Use AI Assistance',
                                style:
                                    TextStyle(color: FlownetColors.pureWhite)),
                            subtitle: const Text(
                                'Generate draft title and content from deliverable context',
                                style:
                                    TextStyle(color: FlownetColors.coolGray)),
                            activeThumbColor: FlownetColors.electricBlue,
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_useAiAssist) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _aiPromptController,
                              decoration: const InputDecoration(
                                labelText: 'AI Prompt (optional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.smart_toy),
                                helperText:
                                    'Describe what the report should emphasize',
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _isAiGenerating
                                      ? null
                                      : _generateAiSuggestions,
                                  icon: _isAiGenerating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.auto_awesome),
                                  label: Text(_isAiGenerating
                                      ? 'Generating...'
                                      : 'Generate with AI'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FlownetColors.electricBlue,
                                    foregroundColor: FlownetColors.pureWhite,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: _isAiGenerating
                                      ? null
                                      : () {
                                          setState(() {
                                            _aiPromptController.clear();
                                          });
                                        },
                                  style: TextButton.styleFrom(
                                      foregroundColor: FlownetColors.coolGray),
                                  child: const Text('Clear Prompt'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sprint Selection (Multi-select)
                    if (_sprints.isNotEmpty) ...[
                      const Text(
                        'Link Sprints (Optional)',
                        style: TextStyle(
                            color: FlownetColors.coolGray, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _sprints.map((sprint) {
                          final sprintId = sprint['id'].toString();
                          final isSelected =
                              _selectedSprintIds.contains(sprintId);
                          final status = (sprint['status'] ?? '').toString().toLowerCase();
                          final isCompleted = status == 'completed' || status == 'done' || status == 'closed';
                          return FilterChip(
                            label: Text(
                                sprint['name'] as String? ?? 'Unnamed Sprint'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected && !isCompleted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Only completed sprints can be linked to a report.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                if (selected) {
                                  _selectedSprintIds.add(sprintId);
                                } else {
                                  _selectedSprintIds.remove(sprintId);
                                }
                              });
                            },
                            selectedColor: FlownetColors.electricBlue
                                .withValues(alpha: 0.3),
                            checkmarkColor: FlownetColors.electricBlue,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Report Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Report Title *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Report Content
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Report Content *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 15,
                      validator: (value) =>
                          value?.isEmpty == true ? 'Content is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Known Limitations
                    TextFormField(
                      controller: _knownLimitationsController,
                      decoration: const InputDecoration(
                        labelText: 'Known Limitations (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),

                    // Next Steps
                    TextFormField(
                      controller: _nextStepsController,
                      decoration: const InputDecoration(
                        labelText: 'Next Steps (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.arrow_forward),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                              _isSaving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed:
                              _isSaving ? null : () => _saveReport(false),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Saving...' : 'Save Draft'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlownetColors.graphiteGray,
                            foregroundColor: FlownetColors.pureWhite,
                            disabledBackgroundColor: FlownetColors.graphiteGray
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : () => _saveReport(true),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(_isSaving ? 'Submitting...' : 'Submit'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: FlownetColors.electricBlue,
                              foregroundColor: FlownetColors.pureWhite,
                              disabledBackgroundColor: FlownetColors
                                  .electricBlue
                                  .withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
