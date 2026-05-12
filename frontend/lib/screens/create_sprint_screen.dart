import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/sprint_database_service.dart';
import '../services/auth_service.dart';
import '../theme/flownet_theme.dart';

class CreateSprintScreen extends StatefulWidget {
  final String? projectId;
  final String? projectName;
  final Map<String, dynamic>? sprint;

  const CreateSprintScreen({
    super.key,
    this.projectId,
    this.projectName,
    this.sprint,
  });

  @override
  State<CreateSprintScreen> createState() => _CreateSprintScreenState();
}

class _CreateSprintScreenState extends State<CreateSprintScreen> {
  static const Color _brandRed = Color(0xFFD70E0E);

  final SprintDatabaseService _sprintService = SprintDatabaseService();

  final _formKey = GlobalKey<FormState>();
  
  bool get _isEditing => widget.sprint != null;
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _plannedPointsController = TextEditingController();
  
  // Project selection
  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;
  bool _isLoadingProjects = false;
  String? _selectedProjectId;
  final TextEditingController _committedPointsController = TextEditingController();
  final TextEditingController _completedPointsController = TextEditingController();
  final TextEditingController _carriedOverPointsController = TextEditingController();
  final TextEditingController _addedDuringSprintController = TextEditingController();
  final TextEditingController _removedDuringSprintController = TextEditingController();
  final TextEditingController _testPassRateController = TextEditingController();
  final TextEditingController _codeCoverageController = TextEditingController();
  final TextEditingController _escapedDefectsController = TextEditingController();
  final TextEditingController _defectsOpenedController = TextEditingController();
  final TextEditingController _defectsClosedController = TextEditingController();
  final TextEditingController _defectSeverityMixController = TextEditingController();
  final TextEditingController _codeReviewCompletionController = TextEditingController();
  final TextEditingController _documentationStatusController = TextEditingController();
  final TextEditingController _uatNotesController = TextEditingController();
  final TextEditingController _uatPassRateController = TextEditingController();
  final TextEditingController _risksIdentifiedController = TextEditingController();
  final TextEditingController _risksController = TextEditingController();
  final TextEditingController _risksMitigatedController = TextEditingController();
  final TextEditingController _blockersController = TextEditingController();
  final TextEditingController _decisionsController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _projectStartDate;
  DateTime? _projectEndDate;
  bool _hasActiveSprint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCanOpen();
    });
    _fetchProjectDates();
    _checkActiveSprints();
    _loadProjects(); // Load projects for dropdown
    if (_isEditing) {
      _fillSprintData();
    }
  }

  Future<void> _ensureCanOpen() async {
    final auth = AuthService();
    if (auth.hasPermission('create_sprint')) return;
    if (!_isEditing) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Delivery Leads, System Admins, or Project Owners can create sprints.')),
      );
      if (context.canPop()) context.pop(false);
      return;
    }

    final currentUserId = auth.currentUser?.id.toString();
    if (currentUserId == null || currentUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to edit this sprint.')),
      );
      if (context.canPop()) context.pop(false);
      return;
    }

    final sprintProjectId = (widget.projectId ??
            widget.sprint?['project_id']?.toString() ??
            widget.sprint?['projectId']?.toString())
        ?.toString();
    if (sprintProjectId == null || sprintProjectId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing project context for sprint.')),
      );
      if (context.canPop()) context.pop(false);
      return;
    }

    try {
      final projects = await _sprintService.getProjects();
      final project = projects.firstWhere(
        (p) => p['id']?.toString() == sprintProjectId || p['key']?.toString() == sprintProjectId,
        orElse: () => <String, dynamic>{},
      );
      final ownerId = (project['owner_id'] ?? project['ownerId'])?.toString() ??
          (project['owner'] is Map ? project['owner']['id']?.toString() : null);
      final isOwner = ownerId != null && ownerId.isNotEmpty && ownerId == currentUserId;
      if (!isOwner) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only the Project Owner can edit sprint details.')),
        );
        if (context.canPop()) context.pop(false);
        return;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to verify sprint permissions.')),
      );
      if (context.canPop()) context.pop(false);
      return;
    }
  }

  Future<void> _loadProjects() async {
    if (widget.projectId != null) return; // Don't load if project is pre-selected

    setState(() {
      _isLoadingProjects = true;
    });

    try {
      final projects = await _sprintService.getProjects();
      
      if (mounted) {
        setState(() {
          _projects = projects;
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
        });
      }
    }
  }

  String _getOwnerDisplayName(Map<String, dynamic> project) {
    // Debug the entire project structure
    debugPrint('🔍 Full project data: $project');
    
    // Try different possible owner field names and formats
    final ownerName = project['owner_name'];
    final ownerId = project['owner_id'];
    
    debugPrint('🔍 Owner name value: $ownerName');
    debugPrint('🔍 Owner name type: ${ownerName.runtimeType}');
    debugPrint('🔍 Owner ID: $ownerId');
    
    if (ownerName != null) {
      if (ownerName is String) {
        debugPrint('🔍 Owner name is string: $ownerName');
        return ownerName.isNotEmpty ? ownerName : 'Not assigned';
      } else if (ownerName is Map) {
        debugPrint('🔍 Owner name is map: ${ownerName.keys.toList()}');
        // If owner_name is an object, try to extract name from it
        final name = ownerName['name']?.toString() ?? 
                     ownerName['first_name']?.toString() ?? 
                     ownerName['email']?.toString() ?? 
                     'Unknown Owner';
        debugPrint('🔍 Extracted owner name: $name');
        return name;
      } else {
        debugPrint('🔍 Owner name is other type: ${ownerName.toString()}');
        return ownerName.toString();
      }
    }
    
    // Fallback to owner_id or default message
    if (ownerId != null) {
      return 'Owner ID: ${ownerId.toString().substring(0, 8)}...';
    }
    
    return 'Not assigned';
  }

  Future<void> _checkActiveSprints() async {
    if (widget.projectId == null || _isEditing) return;

    try {
      final sprints = await _sprintService.getSprints(projectId: widget.projectId);
      final hasActive = sprints.any((s) {
        final status = (s['status'] ?? '').toString().toLowerCase();
        return status != 'completed' && status != 'done';
      });
      
      if (mounted) {
        setState(() {
          _hasActiveSprint = hasActive;
        });
      }
    } catch (e) {
      debugPrint('Error checking active sprints: $e');
    }
  }

  void _fillSprintData() {
    final sprint = widget.sprint!;
    _nameController.text = sprint['name']?.toString() ?? '';
    _descriptionController.text = sprint['description']?.toString() ?? '';
    _plannedPointsController.text = sprint['planned_points']?.toString() ?? '0';
    _committedPointsController.text = sprint['committed_points']?.toString() ?? '';
    _completedPointsController.text = sprint['completed_points']?.toString() ?? '';
    _carriedOverPointsController.text = sprint['carried_over_points']?.toString() ?? '';
    _testPassRateController.text = sprint['test_pass_rate']?.toString() ?? '';
    _codeCoverageController.text = sprint['code_coverage']?.toString() ?? '';
    _escapedDefectsController.text = sprint['escaped_defects']?.toString() ?? '';
    _defectsOpenedController.text = sprint['defects_opened']?.toString() ?? '';
    _defectsClosedController.text = sprint['defects_closed']?.toString() ?? '';
    _codeReviewCompletionController.text = sprint['code_review_completion']?.toString() ?? '';
    _documentationStatusController.text = sprint['documentation_status']?.toString() ?? '';
    _uatNotesController.text = sprint['uat_notes']?.toString() ?? '';
    _uatPassRateController.text = sprint['uat_pass_rate']?.toString() ?? '';
    _risksIdentifiedController.text = sprint['risks_identified']?.toString() ?? '';
    _risksController.text = sprint['risks']?.toString() ?? '';
    _risksMitigatedController.text = sprint['risks_mitigated']?.toString() ?? '';
    _blockersController.text = sprint['blockers']?.toString() ?? '';
    _decisionsController.text = sprint['decisions']?.toString() ?? '';

    if (sprint['defect_severity_mix'] != null) {
      _defectSeverityMixController.text = jsonEncode(sprint['defect_severity_mix']);
    }

    if (sprint['start_date'] != null) {
      _startDate = DateTime.tryParse(sprint['start_date'].toString());
    } else if (sprint['startDate'] != null) {
      _startDate = DateTime.tryParse(sprint['startDate'].toString());
    }

    if (sprint['end_date'] != null) {
      _endDate = DateTime.tryParse(sprint['end_date'].toString());
    } else if (sprint['endDate'] != null) {
      _endDate = DateTime.tryParse(sprint['endDate'].toString());
    }
  }

  Future<void> _fetchProjectDates() async {
    if (widget.projectId == null) return;

    setState(() {
    });

    try {
      final projects = await _sprintService.getProjects();
      final project = projects.firstWhere(
        (p) => p['id']?.toString() == widget.projectId || p['key']?.toString() == widget.projectId,
        orElse: () => <String, dynamic>{},
      );

      if (project.isNotEmpty) {
        setState(() {
          if (project['start_date'] != null) {
            _projectStartDate = DateTime.parse(project['start_date'].toString());
          } else if (project['startDate'] != null) {
            _projectStartDate = DateTime.parse(project['startDate'].toString());
          }

          if (project['end_date'] != null) {
            _projectEndDate = DateTime.parse(project['end_date'].toString());
          } else if (project['endDate'] != null) {
            _projectEndDate = DateTime.parse(project['endDate'].toString());
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching project dates: $e');
    } finally {
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? _projectStartDate ?? DateTime.now(),
      firstDate: _projectStartDate ?? DateTime(2020),
      lastDate: _projectEndDate ?? DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? _projectEndDate ?? DateTime.now(),
      firstDate: _startDate ?? _projectStartDate ?? DateTime(2020),
      lastDate: _projectEndDate ?? DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _saveSprint() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check for active sprints if creating a new one
    if (!_isEditing && _hasActiveSprint) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot create a new sprint until all existing sprints in this project are completed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }

    // Date range validation against project dates
    if (_projectStartDate != null && _startDate!.isBefore(_projectStartDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sprint start date cannot be before project start date (${_projectStartDate!.day}/${_projectStartDate!.month}/${_projectStartDate!.year})'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_projectEndDate != null && _endDate!.isAfter(_projectEndDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sprint end date cannot be after project end date (${_projectEndDate!.day}/${_projectEndDate!.month}/${_projectEndDate!.year})'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Parse JSON for severity mix
      Map<String, dynamic>? severityMix;
      if (_defectSeverityMixController.text.isNotEmpty) {
        try {
          severityMix = jsonDecode(_defectSeverityMixController.text) as Map<String, dynamic>;
        } catch (_) {
          // If not valid JSON, we could try to parse simple key:value format or just ignore
          // For now, let's just ignore if it fails
        }
      }

      // Use selected project ID if no projectId was passed
      final projectIdToUse = _selectedProjectId ?? widget.projectId;
      
      if (projectIdToUse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a project')),
        );
        return;
      }

      final plannedPoints = int.tryParse(_plannedPointsController.text) ?? 0;
      final committedPoints = int.tryParse(_committedPointsController.text);
      final completedPoints = int.tryParse(_completedPointsController.text);
      final carriedOverPoints = int.tryParse(_carriedOverPointsController.text);
      final addedDuringSprint = int.tryParse(_addedDuringSprintController.text);
      final removedDuringSprint = int.tryParse(_removedDuringSprintController.text);

      if (_isEditing) {
        final rawId = widget.sprint?['id']?.toString() ?? widget.sprint?['sprint_id']?.toString();
        final sid = int.tryParse(rawId ?? '');
        if (sid == null) {
          throw Exception('Missing sprint id');
        }
        final ok = await _sprintService.updateSprint(
          sprintId: sid,
          name: _nameController.text,
          description: _descriptionController.text,
          startDate: _startDate,
          endDate: _endDate,
          projectId: projectIdToUse,
          plannedPoints: plannedPoints,
          committedPoints: committedPoints,
          completedPoints: completedPoints,
          carriedOverPoints: carriedOverPoints,
          addedDuringSprint: addedDuringSprint,
          removedDuringSprint: removedDuringSprint,
          testPassRate: double.tryParse(_testPassRateController.text),
          codeCoverage: int.tryParse(_codeCoverageController.text),
          escapedDefects: int.tryParse(_escapedDefectsController.text),
          defectsOpened: int.tryParse(_defectsOpenedController.text),
          defectsClosed: int.tryParse(_defectsClosedController.text),
          defectSeverityMix: severityMix,
          codeReviewCompletion: int.tryParse(_codeReviewCompletionController.text),
          documentationStatus: _documentationStatusController.text.isNotEmpty ? _documentationStatusController.text : null,
          uatNotes: _uatNotesController.text.isNotEmpty ? _uatNotesController.text : null,
          uatPassRate: int.tryParse(_uatPassRateController.text),
          risksIdentified: int.tryParse(_risksIdentifiedController.text),
          risks: _risksController.text.isNotEmpty ? _risksController.text : null,
          risksMitigated: int.tryParse(_risksMitigatedController.text),
          blockers: _blockersController.text.isNotEmpty ? _blockersController.text : null,
          decisions: _decisionsController.text.isNotEmpty ? _decisionsController.text : null,
        );
        if (ok == null) {
          throw Exception('Failed to update sprint');
        }
      } else {
        await _sprintService.createSprint(
          name: _nameController.text,
          description: _descriptionController.text,
          startDate: _startDate!,
          endDate: _endDate!,
          projectId: projectIdToUse,
          plannedPoints: plannedPoints,
          committedPoints: committedPoints,
          completedPoints: completedPoints,
          carriedOverPoints: carriedOverPoints,
          testPassRate: double.tryParse(_testPassRateController.text),
          codeCoverage: int.tryParse(_codeCoverageController.text),
          escapedDefects: int.tryParse(_escapedDefectsController.text),
          defectsOpened: int.tryParse(_defectsOpenedController.text),
          defectsClosed: int.tryParse(_defectsClosedController.text),
          defectSeverityMix: severityMix,
          codeReviewCompletion: int.tryParse(_codeReviewCompletionController.text),
          documentationStatus: _documentationStatusController.text.isNotEmpty ? _documentationStatusController.text : null,
          uatNotes: _uatNotesController.text.isNotEmpty ? _uatNotesController.text : null,
          uatPassRate: int.tryParse(_uatPassRateController.text),
          risksIdentified: int.tryParse(_risksIdentifiedController.text),
          risks: _risksController.text.isNotEmpty ? _risksController.text : null,
          risksMitigated: int.tryParse(_risksMitigatedController.text),
          blockers: _blockersController.text.isNotEmpty ? _blockersController.text : null,
          decisions: _decisionsController.text.isNotEmpty ? _decisionsController.text : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Sprint updated successfully!' : 'Sprint created successfully!')),
        );
        context.pop(true);
      }
    } catch (e) {
      debugPrint('Error saving sprint: $e');
      if (mounted) {
        final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Error creating sprint';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.isEmpty ? 'Error creating sprint' : (msg.length > 150 ? '${msg.substring(0, 150)}...' : msg)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _plannedPointsController.dispose();
    _committedPointsController.dispose();
    _completedPointsController.dispose();
    _carriedOverPointsController.dispose();
    _addedDuringSprintController.dispose();
    _removedDuringSprintController.dispose();
    _testPassRateController.dispose();
    _codeCoverageController.dispose();
    _escapedDefectsController.dispose();
    _defectsOpenedController.dispose();
    _defectsClosedController.dispose();
    _defectSeverityMixController.dispose();
    _codeReviewCompletionController.dispose();
    _documentationStatusController.dispose();
    _uatNotesController.dispose();
    _uatPassRateController.dispose();
    _risksIdentifiedController.dispose();
    _risksController.dispose();
    _risksMitigatedController.dispose();
    _blockersController.dispose();
    _decisionsController.dispose();
    super.dispose();
  }

  Widget _buildNumberField(TextEditingController controller, String label, {bool isDouble = false}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: isDouble),
    );
  }

  /// Matches project form field geometry so inputs line up on the background.
  ThemeData _alignedFieldTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyMedium: const TextStyle(fontSize: 13, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3F4146),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brandRed, width: 1.4),
        ),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: _brandRed,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 14,
        ),
        prefixIconColor: _brandRed,
        suffixIconColor: Colors.white70,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: Colors.white.withValues(alpha: 0.75),
        collapsedIconColor: Colors.white.withValues(alpha: 0.75),
        textColor: Colors.white,
        collapsedTextColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🟢 CreateSprintScreen.build() called - projectId: ${widget.projectId}, projectName: ${widget.projectName}');
    return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/sprint-console');
              }
            },
          ),
          title: Text(
            _isEditing
                ? 'Edit Sprint - ${_nameController.text}'
                : (widget.projectName == null
                    ? 'Create Sprint'
                    : 'Create Sprint - ${widget.projectName}'),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: FlownetColors.pureWhite,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: FlownetColors.pureWhite,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Theme(
                data: _alignedFieldTheme(context),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
              // Project selection dropdown (only show if no project was pre-selected)
              if (widget.projectId == null) ...[
                _isLoadingProjects
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(color: _brandRed),
                        ),
                      )
                    : DropdownButtonFormField<Map<String, dynamic>>(
                        // ignore: deprecated_member_use
                        value: _selectedProject,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF3F4146),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Project *',
                          hintText: 'Select a project',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                        items: _projects.map((project) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: project,
                            child: Text(
                              project['name']?.toString() ?? 'Unnamed Project',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (Map<String, dynamic>? project) {
                          setState(() {
                            _selectedProject = project;
                            _selectedProjectId = project?['id']?.toString();
                            // Debug project data structure
                            debugPrint('🔍 Selected project data: ${project?.keys.toList()}');
                            debugPrint('🔍 Owner name field: ${project?['owner_name']}');
                            debugPrint('🔍 Owner name type: ${project?['owner_name'].runtimeType}');
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a project';
                          }
                          return null;
                        },
                      ),
                const SizedBox(height: 16),
                
                // Show project owner when project is selected
                if (_selectedProject != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Project Owner: ${_getOwnerDisplayName(_selectedProject!)}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ] else if (widget.projectName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Project: ${widget.projectName}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Sprint Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timeline_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a sprint name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectStartDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          _startDate != null
                              ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                              : 'Select start date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _startDate != null
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectEndDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                        child: Text(
                          _endDate != null
                              ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                              : 'Select end date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _endDate != null
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plannedPointsController,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  labelText: 'Planned Points',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.analytics_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),

              ExpansionTile(
                title: const Text(
                  'Outcomes',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildNumberField(_committedPointsController, 'Committed Pts')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildNumberField(_completedPointsController, 'Completed Pts')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildNumberField(_carriedOverPointsController, 'Carried Over Points'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildNumberField(_defectsOpenedController, 'Defects Opened')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildNumberField(_defectsClosedController, 'Defects Closed')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildNumberField(_testPassRateController, 'Pass Rate %', isDouble: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildNumberField(_codeCoverageController, 'Coverage %')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _uatNotesController,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'UAT Notes',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              ExpansionTile(
                title: const Text(
                  'Quality Signals',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildNumberField(_escapedDefectsController, 'Escaped Defects'),
                        const SizedBox(height: 16),
                        _buildNumberField(_codeReviewCompletionController, 'Code Review Completion %'),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _documentationStatusController,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Documentation Status',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                         _buildNumberField(_uatPassRateController, 'UAT Pass Rate %'),
                      ],
                    ),
                  ),
                ],
              ),

              ExpansionTile(
                title: const Text(
                  'Notes & Risks',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                         TextFormField(
                          controller: _risksController,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Risks (Free-text)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _blockersController,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Blockers',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _decisionsController,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Decisions',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!_isEditing && _hasActiveSprint) ? null : _saveSprint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (!_isEditing && _hasActiveSprint) ? Colors.grey : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _isEditing ? 'Save Changes' : 'Create Sprint',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  }
}
