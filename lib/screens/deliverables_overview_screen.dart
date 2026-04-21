// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/date_utils.dart' as app_date_utils;
import 'package:khono/models/deliverable.dart';
import 'package:khono/screens/audit_log_detail_screen.dart';
import 'package:khono/services/backend_api_service.dart';
import 'package:khono/services/auth_service.dart';
import 'package:khono/services/deliverable_service.dart';
import 'package:khono/services/realtime_service.dart';
import 'package:khono/config/environment.dart';
import 'package:khono/widgets/deliverable_card.dart';
import 'package:khono/theme/flownet_theme.dart';

class DeliverablesOverviewScreen extends StatefulWidget {
  const DeliverablesOverviewScreen({super.key});

  @override
  State<DeliverablesOverviewScreen> createState() =>
      _DeliverablesOverviewScreenState();
}

class _DeliverablesOverviewScreenState
    extends State<DeliverablesOverviewScreen> {
  final _backendService = BackendApiService();
  final _authService = AuthService();
  final DeliverableService _deliverableService = DeliverableService();
  RealtimeService? _realtime;
  List<Deliverable> _deliverables = [];
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'All';
  String _searchQuery = '';
  bool _isKanbanView = false;
  int _currentNavIndex = 0;
  bool _isDragging = false;
  final bool _hasRealTimeConnection = false;
  final Set<String> _expandedIds = {};
  final Set<String> _expandedAuditLogIds = {};
  final Set<String> _uploadingIds = {};

  Future<List<int>?> _platformFileBytes(PlatformFile f) async {
    final bytes = f.bytes;
    if (bytes != null && bytes.isNotEmpty) return bytes;
    final stream = f.readStream;
    if (stream == null) return null;
    final out = <int>[];
    await for (final chunk in stream) {
      out.addAll(chunk);
    }
    return out;
  }

  void _onNavTapped(int index) {
    setState(() {
      _currentNavIndex = index;
      switch (index) {
        case 0:
          _filterStatus = 'All';
          break;
        case 1:
          _filterStatus = 'Draft';
          break;
        case 2:
          _filterStatus = 'In Progress';
          break;
        case 3:
          _filterStatus = 'In Review';
          break;
        case 4:
          _filterStatus = 'Signed Off';
          break;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDeliverables();
    _initRealtime();
  }

  Future<void> _initRealtime() async {
    try {
      final token = _authService.accessToken;
      if (token == null || token.isEmpty) return;
      _realtime = RealtimeService();
      await _realtime!.initialize(authToken: token);
      _realtime!.on('deliverable_created', (_) => _loadDeliverables());
      _realtime!.on('deliverable_updated', (_) => _loadDeliverables());
    } catch (_) {}
  }

  Future<void> _loadDeliverables() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _backendService.getDeliverables(limit: 100);

      if (response.isSuccess && response.data != null) {
        final dynamic raw = response.data;
        final List<dynamic> items = (raw is Map)
            ? (raw['data'] ?? raw['deliverables'] ?? raw['items'] ?? [])
            : (raw is List ? raw : []);

        final List<Deliverable> parsedDeliverables = [];

        for (final item in items) {
          try {
            if (item is Map<String, dynamic>) {
              final safeMap = Map<String, dynamic>.from(item);
              if (!safeMap.containsKey('title')) {
                safeMap['title'] = safeMap['name'] ??
                    safeMap['deliverableName'] ??
                    'Untitled Deliverable';
              }

              // Map backend field names to frontend expectations
              if (safeMap.containsKey('created_by_name')) {
                safeMap['ownerName'] = safeMap['created_by_name'];
                safeMap['ownerId'] =
                    safeMap['created_by']; // Map ownerName to ownerId
              }
              if (safeMap.containsKey('assigned_to_name')) {
                safeMap['assignedToName'] = safeMap['assigned_to_name'];
                safeMap['assignedTo'] =
                    safeMap['assigned_to']; // Map assignedToName to assignedTo
              }

              parsedDeliverables.add(Deliverable.fromJson(safeMap));
            }
          } catch (e) {
            debugPrint('Error parsing deliverable: $e');
          }
        }

        // Apply RBAC filtering
        var filteredList = parsedDeliverables;
        // Only filter for basic team members - admins, leads, and stakeholders can see all
        if (_authService.isTeamMember &&
            !_authService.isDeliveryLead &&
            !_authService.isSystemAdmin &&
            !_authService.isStakeholder) {
          final userId = _authService.currentUser?.id;
          if (userId != null) {
            filteredList = parsedDeliverables
                .where((d) => d.ownerId == userId || d.createdBy == userId)
                .toList();
          }
        }

        setState(() {
          _deliverables = filteredList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to load deliverables';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateDeliverableStatus(
      Deliverable deliverable, DeliverableStatus newStatus) async {
    // Optimistic update
    final oldStatus = deliverable.status;

    // RBAC: Team Members cannot move to/from Signed Off
    if (_authService.isTeamMember &&
        !_authService.isDeliveryLead &&
        !_authService.isSystemAdmin) {
      if (newStatus == DeliverableStatus.signedOff) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Only Delivery Leads can sign off deliverables.'),
              backgroundColor: Colors.red),
        );
        return;
      }
      if (oldStatus == DeliverableStatus.signedOff) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Only Delivery Leads can reopen signed off deliverables.'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    // Check validation rules
    if ((newStatus == DeliverableStatus.inProgress ||
            newStatus == DeliverableStatus.inReview ||
            newStatus == DeliverableStatus.signedOff) &&
        deliverable.ownerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cannot move to this status without an assigned owner. Please edit the deliverable first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Don't update if status hasn't changed
    if (oldStatus == newStatus) return;

    try {
      // Map enum to backend string
      String statusStr;
      switch (newStatus) {
        case DeliverableStatus.draft:
          statusStr = 'draft';
          break;
        case DeliverableStatus.inProgress:
          statusStr = 'in_progress';
          break;
        case DeliverableStatus.inReview:
          statusStr = 'in_review';
          break;
        case DeliverableStatus.signedOff:
          statusStr = 'signed_off';
          break;
        case DeliverableStatus.changeRequested:
          statusStr = 'change_requested';
          break;
        case DeliverableStatus.rejected:
          statusStr = 'rejected';
          break;
        default:
          statusStr = 'draft';
      }

      final response = await _backendService.updateDeliverableStatus(
          deliverable.id, statusStr);

      if (response.isSuccess) {
        // Refresh list to ensure consistency
        _loadDeliverables();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved to ${newStatus.displayName}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: ${response.error}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  List<Deliverable> get _filteredDeliverables {
    return _deliverables.where((d) {
      final matchesStatus = _filterStatus == 'All' ||
          d.statusDisplayName.toLowerCase() == _filterStatus.toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          d.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (d.ownerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  Widget _buildKanbanBoard() {
    final kanbanDeliverables = _deliverables.where((d) {
      final matchesSearch = _searchQuery.isEmpty ||
          d.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (d.ownerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
      return matchesSearch;
    }).toList();

    List<DeliverableStatus> columns = [
      DeliverableStatus.draft,
      DeliverableStatus.inProgress,
      DeliverableStatus.inReview,
      DeliverableStatus.signedOff,
    ];

    // Filter columns if a specific status is selected via BottomNavigationBar
    if (_filterStatus != 'All') {
      columns = columns.where((s) => s.displayName == _filterStatus).toList();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.map((status) {
          final items = kanbanDeliverables
              .where(
                (d) =>
                    d.status == status ||
                    (status == DeliverableStatus.inReview &&
                        d.status == DeliverableStatus.submitted) ||
                    (status == DeliverableStatus.signedOff &&
                        d.status == DeliverableStatus.approved),
              )
              .toList();

          return _buildKanbanColumn(status, items);
        }).toList(),
      ),
    );
  }

  Widget _buildKanbanColumn(DeliverableStatus status, List<Deliverable> items) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: status.color.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(color: status.color.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 6,
                  backgroundColor: status.color,
                ),
                const SizedBox(width: 8),
                Text(
                  status.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: status.color,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Drop Target Area
          Expanded(
            child: DragTarget<Deliverable>(
              onWillAccept: (data) => data != null && data.status != status,
              onAccept: (deliverable) {
                _updateDeliverableStatus(deliverable, status);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? status.color.withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: items.map((deliverable) {
                      return Draggable<Deliverable>(
                        data: deliverable,
                        feedback: SizedBox(
                          width: 280,
                          child: Opacity(
                            opacity: 0.8,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(deliverable.title),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DeliverableCard(
                              deliverable: deliverable,
                              onTap: () {}, // Disable tap while dragging
                              compact: true,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DeliverableCard(
                            deliverable: deliverable,
                            showArtifactsPreview: true,
                            onTap: () {
                              context.push('/deliverable-detail',
                                  extra: deliverable);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _authService.canCreateDeliverable();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliverables'),
        actions: [
          if (_hasRealTimeConnection)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi, size: 16, color: Colors.green[800]),
                  const SizedBox(width: 4),
                  const Text(
                    'Live Sync',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeliverables,
          ),
          IconButton(
            icon: Icon(_isKanbanView ? Icons.list : Icons.view_kanban),
            onPressed: () {
              setState(() {
                _isKanbanView = !_isKanbanView;
              });
            },
            tooltip: _isKanbanView ? 'List View' : 'Kanban View',
          ),
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/deliverable-setup'),
              tooltip: 'Create Deliverable',
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'All',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_document),
            label: 'Draft',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.loop),
            label: 'In Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rate_review),
            label: 'In Review',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Signed Off',
          ),
        ],
        currentIndex: _currentNavIndex,
        selectedItemColor: FlownetColors.crimsonRed,
        unselectedItemColor: FlownetColors.graphiteGray,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        iconSize: 22,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onNavTapped,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search deliverables...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDeliverables,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _isKanbanView
                        ? _buildKanbanBoard()
                        : _filteredDeliverables.isEmpty
                            ? const Center(child: Text('No deliverables found'))
                            : RefreshIndicator(
                                onRefresh: _loadDeliverables,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredDeliverables.length,
                                  itemBuilder: (context, index) {
                                    final deliverable =
                                        _filteredDeliverables[index];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          DeliverableCard(
                                            deliverable: deliverable,
                                            onTap: () {
                                              context.push(
                                                  '/deliverable-detail',
                                                  extra: deliverable);
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          _buildArtifactsPanel(deliverable),
                                          const SizedBox(height: 8),
                                          _buildAuditLogPanel(deliverable),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactsPanel(Deliverable deliverable) {
    final isExpanded = _expandedIds.contains(deliverable.id);
    final isUploading = _uploadingIds.contains(deliverable.id);
    return Card(
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        title: Row(
          children: [
            const Icon(Icons.attach_file, size: 20),
            const SizedBox(width: 8),
            Text('Artifacts (${deliverable.artifacts.length})'),
            const Spacer(),
            ElevatedButton.icon(
              onPressed:
                  isUploading ? null : () => _uploadArtifactFor(deliverable),
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: Text(isUploading ? 'Uploading...' : 'Upload'),
            ),
          ],
        ),
        onExpansionChanged: (expanded) async {
          setState(() {
            if (expanded) {
              _expandedIds.add(deliverable.id);
            } else {
              _expandedIds.remove(deliverable.id);
            }
          });
          if (expanded) {
            await _refreshDeliverable(deliverable.id);
          }
        },
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropTarget(
              onDragDone: (detail) =>
                  _handleDroppedFilesFor(deliverable, detail.files),
              onDragEntered: (detail) => setState(() => _isDragging = true),
              onDragExited: (detail) => setState(() => _isDragging = false),
              child: Container(
                constraints: const BoxConstraints(minHeight: 100),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isDragging
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                    width: _isDragging ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _isDragging
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : null,
                ),
                child: deliverable.artifacts.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                              'No artifacts yet. Drag & drop files here or click Upload.'),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: deliverable.artifacts.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final artifact = deliverable.artifacts[index];
                          return ListTile(
                            leading: Icon(_getFileIcon(artifact.fileType)),
                            title: Text(artifact.originalName),
                            subtitle: Text(
                              'Uploaded by ${artifact.uploaderName ?? artifact.uploadedBy} on ${app_date_utils.DateUtils.formatDateTime(artifact.createdAt)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _downloadArtifact(artifact),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteArtifactFor(
                                      deliverable.id, artifact.id),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _refreshDeliverable(String deliverableId) async {
    final response = await _deliverableService.getDeliverable(deliverableId);
    if (response.isSuccess && response.data != null) {
      final d = response.data['deliverable'] as Deliverable;
      final i = _deliverables.indexWhere((e) => e.id == deliverableId);
      if (i != -1) {
        setState(() {
          _deliverables[i] = d;
        });
      }
    }
  }

  Future<void> _uploadArtifactFor(Deliverable deliverable) async {
    try {
      final res = await FilePicker.platform
          .pickFiles(withData: true, withReadStream: true);
      if (res != null && res.files.isNotEmpty) {
        setState(() => _uploadingIds.add(deliverable.id));
        final file = res.files.single;
        final bytes = await _platformFileBytes(file);
        final response = await _deliverableService.uploadArtifact(
          deliverableId: deliverable.id,
          filePath: kIsWeb ? '' : (file.path ?? ''),
          fileName: file.name,
          fileBytes: bytes,
        );
        setState(() => _uploadingIds.remove(deliverable.id));
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Artifact uploaded successfully')),
          );
          await _refreshDeliverable(deliverable.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Upload failed: ${response.error}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _uploadingIds.remove(deliverable.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error uploading file: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleDroppedFilesFor(
      Deliverable deliverable, List<XFile> files) async {
    if (files.isEmpty) return;
    setState(() => _uploadingIds.add(deliverable.id));
    int successCount = 0;
    final List<String> errors = [];
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final response = await _deliverableService.uploadArtifact(
          deliverableId: deliverable.id,
          filePath: kIsWeb ? '' : file.path,
          fileName: file.name,
          fileBytes: bytes,
        );
        if (response.isSuccess) {
          successCount++;
        } else {
          errors.add('${file.name}: ${response.error}');
        }
      } catch (e) {
        errors.add('${file.name}: $e');
      }
    }
    if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded $successCount artifacts')),
      );
      await _refreshDeliverable(deliverable.id);
    }
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Errors: ${errors.take(3).join(", ")}'),
            backgroundColor: Colors.red),
      );
    }
    setState(() => _uploadingIds.remove(deliverable.id));
  }

  Future<void> _deleteArtifactFor(
      String deliverableId, String artifactId) async {
    final response =
        await _deliverableService.deleteArtifact(deliverableId, artifactId);
    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artifact deleted successfully')),
      );
      await _refreshDeliverable(deliverableId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Delete failed: ${response.error}'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadArtifact(DeliverableArtifact artifact) async {
    try {
      String url = artifact.url;
      if (!url.startsWith('http')) {
        final baseUrl = Environment.apiBaseUrl.replaceAll('/api/v1', '');
        url = '$baseUrl/uploads/$url';
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not launch $url'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error launching URL: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  IconData _getFileIcon(String fileType) {
    final type = fileType.toLowerCase();
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('doc') || type.contains('word')) return Icons.description;
    if (type.contains('xls') || type.contains('sheet')) {
      return Icons.table_chart;
    }
    if (type.contains('ppt') || type.contains('presentation')) {
      return Icons.slideshow;
    }
    if (type.contains('img') ||
        type.contains('png') ||
        type.contains('jpg') ||
        type.contains('jpeg')) {
      return Icons.image;
    }
    if (type.contains('zip') || type.contains('rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Widget _buildAuditLogPanel(Deliverable deliverable) {
    final isExpanded = _expandedAuditLogIds.contains(deliverable.id);
    final logs = List<AuditLogEntry>.from(deliverable.auditLogs)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Card(
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        title: Row(
          children: [
            const Icon(Icons.history, size: 20),
            const SizedBox(width: 8),
            Text('Audit Trail (${logs.length})'),
          ],
        ),
        onExpansionChanged: (expanded) async {
          setState(() {
            if (expanded) {
              _expandedAuditLogIds.add(deliverable.id);
            } else {
              _expandedAuditLogIds.remove(deliverable.id);
            }
          });
          if (expanded) {
            await _refreshDeliverable(deliverable.id);
          }
        },
        children: [
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No history available.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = logs[index];
                return ListTile(
                  dense: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AuditLogDetailScreen(logEntry: log),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey[200],
                    child: Icon(_getAuditIcon(log.action),
                        size: 14, color: Colors.grey[700]),
                  ),
                  title: Text(
                    log.action.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'by ${log.userEmail ?? 'System'}'),
                            if (log.userRole != null)
                              TextSpan(
                                  text: ' (${log.userRole})',
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic)),
                            TextSpan(
                                text:
                                    ' • ${app_date_utils.DateUtils.formatDateTime(log.createdAt)}'),
                          ],
                        ),
                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                      ),
                      if ((log.oldValues != null &&
                              log.oldValues!.isNotEmpty) ||
                          (log.newValues != null &&
                              log.newValues!.isNotEmpty)) ...[
                        const SizedBox(height: 4),
                        _buildChangeDetails(log),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      size: 16, color: Colors.grey),
                );
              },
            ),
        ],
      ),
    );
  }

  IconData _getAuditIcon(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('create')) return Icons.add_circle_outline;
    if (lower.contains('update')) return Icons.edit;
    if (lower.contains('delete')) return Icons.delete_outline;
    if (lower.contains('status')) return Icons.swap_horiz;
    return Icons.info_outline;
  }

  Widget _buildChangeDetails(AuditLogEntry log) {
    if (log.changedFields != null && log.changedFields!.isNotEmpty) {
      return Text(
        'Changed: ${log.changedFields!.join(", ")}',
        style: TextStyle(
            fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
      );
    }
    return const SizedBox.shrink();
  }
}
