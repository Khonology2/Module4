import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sprint_metrics.dart';
import '../providers/service_providers.dart';
import '../theme/flownet_theme.dart';
import '../widgets/flownet_logo.dart';

class SprintMetricsScreen extends ConsumerStatefulWidget {
  final String sprintId;
  
  const SprintMetricsScreen({
    super.key,
    required this.sprintId,
  });

  @override
  ConsumerState<SprintMetricsScreen> createState() => _SprintMetricsScreenState();
}

class _SprintMetricsScreenState extends ConsumerState<SprintMetricsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Sprint Metrics Controllers
  final _committedPointsController = TextEditingController();
  final _completedPointsController = TextEditingController();
  final _carriedOverController = TextEditingController();
  final _testPassRateController = TextEditingController();
  final _defectsOpenedController = TextEditingController();
  final _defectsClosedController = TextEditingController();
  final _criticalDefectsController = TextEditingController();
  final _highDefectsController = TextEditingController();
  final _mediumDefectsController = TextEditingController();
  final _lowDefectsController = TextEditingController();
  final _codeReviewCompletionController = TextEditingController();
  final _documentationStatusController = TextEditingController();
  final _risksController = TextEditingController();
  final _mitigationsController = TextEditingController();
  final _scopeChangesController = TextEditingController();
  final _pointsAddedController = TextEditingController();
  final _pointsRemovedController = TextEditingController();
  final _blockersController = TextEditingController();
  final _decisionsController = TextEditingController();
  final _uatNotesController = TextEditingController();
  
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingMetrics();
  }

  Future<void> _loadExistingMetrics() async {
    // Load existing metrics if available
    // This would typically come from an API or local storage
    final backendApi = ref.read(backendApiServiceProvider);
    final response = await backendApi.getSprintMetrics(widget.sprintId);

    if (!mounted) return;

    if (response.isSuccess) {
      final metricsList = backendApi.parseSprintMetricsFromResponse(response);
      if (metricsList.isNotEmpty) {
        final latest = metricsList.first;
        setState(() {
          _committedPointsController.text = latest.committedPoints.toString();
          _completedPointsController.text = latest.completedPoints.toString();
          _carriedOverController.text = latest.carriedOverPoints.toString();
          _testPassRateController.text = latest.testPassRate.toString();
          _defectsOpenedController.text = latest.defectsOpened.toString();
          _defectsClosedController.text = latest.defectsClosed.toString();
          _criticalDefectsController.text = latest.criticalDefects.toString();
          _highDefectsController.text = latest.highDefects.toString();
          _mediumDefectsController.text = latest.mediumDefects.toString();
          _lowDefectsController.text = latest.lowDefects.toString();
          _codeReviewCompletionController.text = latest.codeReviewCompletion.toString();
          _documentationStatusController.text = latest.documentationStatus.toString();
          _risksController.text = latest.risks ?? '';
          _mitigationsController.text = latest.mitigations ?? '';
          _scopeChangesController.text = latest.scopeChanges ?? '';
          _pointsAddedController.text = latest.pointsAddedDuringSprint.toString();
          _pointsRemovedController.text = latest.pointsRemovedDuringSprint.toString();
          _blockersController.text = latest.blockers ?? '';
          _decisionsController.text = latest.decisions ?? '';
          _uatNotesController.text = latest.uatNotes ?? '';
        });
      }
    }
  }

  Future<void> _submitMetrics() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create metrics object (would be saved to API)
      final metrics = SprintMetrics(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sprintId: widget.sprintId,
        committedPoints: int.parse(_committedPointsController.text),
        completedPoints: int.parse(_completedPointsController.text),
        carriedOverPoints: int.parse(_carriedOverController.text),
        testPassRate: double.parse(_testPassRateController.text),
        defectsOpened: int.parse(_defectsOpenedController.text),
        defectsClosed: int.parse(_defectsClosedController.text),
        criticalDefects: int.parse(_criticalDefectsController.text),
        highDefects: int.parse(_highDefectsController.text),
        mediumDefects: int.parse(_mediumDefectsController.text),
        lowDefects: int.parse(_lowDefectsController.text),
        codeReviewCompletion: double.parse(_codeReviewCompletionController.text),
        documentationStatus: double.parse(_documentationStatusController.text),
        risks: _risksController.text.isNotEmpty ? _risksController.text : null,
        mitigations: _mitigationsController.text.isNotEmpty ? _mitigationsController.text : null,
        scopeChanges: _scopeChangesController.text.isNotEmpty ? _scopeChangesController.text : null,
        pointsAddedDuringSprint: int.tryParse(_pointsAddedController.text) ?? 0,
        pointsRemovedDuringSprint: int.tryParse(_pointsRemovedController.text) ?? 0,
        blockers: _blockersController.text.isNotEmpty ? _blockersController.text : null,
        decisions: _decisionsController.text.isNotEmpty ? _decisionsController.text : null,
        uatNotes: _uatNotesController.text.isNotEmpty ? _uatNotesController.text : null,
        recordedAt: DateTime.now(),
        recordedBy: 'Current User', // This would come from auth
      );

final api = ref.read(backendApiServiceProvider);
      final response = await api.createSprintMetrics(widget.sprintId, metrics.toJson());
      if (!response.isSuccess) {
        throw Exception(response.error ?? 'Failed to save sprint metrics');
      }
      
      if (mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sprint metrics saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving metrics: ${response.error ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving metrics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlownetColors.charcoalBlack,
      appBar: AppBar(
        title: const FlownetLogo(),
        backgroundColor: FlownetColors.charcoalBlack,
        foregroundColor: FlownetColors.pureWhite,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Sprint Metrics Capture',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: FlownetColors.pureWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Sprint Performance
              _buildSectionHeader('Sprint Performance'),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _committedPointsController,
                      decoration: const InputDecoration(
                        labelText: 'Committed Points',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _completedPointsController,
                      decoration: const InputDecoration(
                        labelText: 'Completed Points',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.check_circle),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _carriedOverController,
                decoration: const InputDecoration(
                  labelText: 'Carried Over Points',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.forward),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // Quality Metrics
              _buildSectionHeader('Quality Metrics'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _testPassRateController,
                decoration: const InputDecoration(
                  labelText: 'Test Pass Rate (%)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.science),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _defectsOpenedController,
                      decoration: const InputDecoration(
                        labelText: 'Defects Opened',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bug_report),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _defectsClosedController,
                      decoration: const InputDecoration(
                        labelText: 'Defects Closed',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.check),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Defect Severity Breakdown
              Text(
                'Defect Severity Breakdown',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: FlownetColors.pureWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _criticalDefectsController,
                      decoration: const InputDecoration(
                        labelText: 'Critical',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _highDefectsController,
                      decoration: const InputDecoration(
                        labelText: 'High',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _mediumDefectsController,
                      decoration: const InputDecoration(
                        labelText: 'Medium',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lowDefectsController,
                      decoration: const InputDecoration(
                        labelText: 'Low',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Process Metrics
              _buildSectionHeader('Process Metrics'),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codeReviewCompletionController,
                      decoration: const InputDecoration(
                        labelText: 'Code Review Completion (%)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.reviews),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _documentationStatusController,
                      decoration: const InputDecoration(
                        labelText: 'Documentation Status (%)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Notes and Observations
              _buildSectionHeader('Notes and Observations'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _risksController,
                decoration: const InputDecoration(
                  labelText: 'Risks Identified',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _mitigationsController,
                decoration: const InputDecoration(
                  labelText: 'Mitigations Applied',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shield),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _scopeChangesController,
                decoration: const InputDecoration(
                  labelText: 'Scope Changes Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                  hintText: 'Describe any scope changes during the sprint',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Scope Change Metrics
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pointsAddedController,
                      decoration: const InputDecoration(
                        labelText: 'Points Added',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.add_circle, color: Colors.orange),
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pointsRemovedController,
                      decoration: const InputDecoration(
                        labelText: 'Points Removed',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.remove_circle, color: Colors.blue),
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _blockersController,
                decoration: const InputDecoration(
                  labelText: 'Blockers',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.block),
                  hintText: 'Any blockers encountered during the sprint',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _decisionsController,
                decoration: const InputDecoration(
                  labelText: 'Key Decisions',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.gavel),
                  hintText: 'Important decisions made during the sprint',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _uatNotesController,
                decoration: const InputDecoration(
                  labelText: 'UAT Notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitMetrics,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlownetColors.electricBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Sprint Metrics',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: FlownetColors.pureWhite,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void dispose() {
    _committedPointsController.dispose();
    _completedPointsController.dispose();
    _carriedOverController.dispose();
    _testPassRateController.dispose();
    _defectsOpenedController.dispose();
    _defectsClosedController.dispose();
    _criticalDefectsController.dispose();
    _highDefectsController.dispose();
    _mediumDefectsController.dispose();
    _lowDefectsController.dispose();
    _codeReviewCompletionController.dispose();
    _documentationStatusController.dispose();
    _risksController.dispose();
    _mitigationsController.dispose();
    _scopeChangesController.dispose();
    _pointsAddedController.dispose();
    _pointsRemovedController.dispose();
    _blockersController.dispose();
    _decisionsController.dispose();
    _uatNotesController.dispose();
    super.dispose();
  }
}
