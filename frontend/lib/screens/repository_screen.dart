import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../models/repository_file.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';
import '../services/sprint_database_service.dart';
import '../services/realtime_service.dart';
import '../services/deliverable_service.dart';
import '../services/sign_off_report_service.dart';
import '../theme/flownet_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/document_preview_widget.dart';
import '../widgets/audit_history_widget.dart';
import '../widgets/app_modal.dart';

class RepositoryScreen extends StatefulWidget {
  final String? projectKey;
  const RepositoryScreen({super.key, this.projectKey});

  @override
  State<RepositoryScreen> createState() => _RepositoryScreenState();
}

class _RepositoryScreenState extends State<RepositoryScreen> {
  final DocumentService _documentService = DocumentService(AuthService());
  final SprintDatabaseService _sprintService = SprintDatabaseService();
  final DeliverableService _deliverableService = DeliverableService();
  final SignOffReportService _reportService =
      SignOffReportService(AuthService());
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  List<RepositoryFile> _documents = [];
  List<RepositoryFile> _filteredDocuments = [];
  Map<String, String> _reportTitles = {};
  bool _isLoading = false;
  String _selectedFileType = 'all';
  String _searchQuery = '';
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _sprints = [];
  List<dynamic> _deliverables = [];
  String? _selectedProjectId;
  String? _selectedSprintId;
  String? _selectedDeliverableId;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await AuthService().initialize();
      } catch (_) {}
      try {
        final token = AuthService().accessToken;
        if (token != null && token.isNotEmpty) {
          await RealtimeService().initialize(authToken: token);
          RealtimeService().on('document_uploaded', (data) {
            try {
              final doc =
                  RepositoryFile.fromJson(Map<String, dynamic>.from(data));
              setState(() {
                // Remove existing document with same ID to prevent duplicates
                _documents.removeWhere((d) => d.id == doc.id);
                _documents = [doc, ..._documents];
              });
              _filterDocuments();
            } catch (_) {
              _loadDocuments();
            }
          });
          RealtimeService().on('document_deleted', (data) {
            try {
              final id = (data is Map && data['id'] != null)
                  ? data['id'].toString()
                  : null;
              if (id != null) {
                setState(() {
                  _documents.removeWhere((d) => d.id == id);
                  _filteredDocuments.removeWhere((d) => d.id == id);
                });
              } else {
                _loadDocuments();
              }
            } catch (_) {
              _loadDocuments();
            }
          });
        }
      } catch (_) {}
      if (!mounted) return;
      await _loadFilters();
      _loadReports();
      await _loadDocuments();
    });
  }

  Future<void> _loadReports() async {
    try {
      final response = await _reportService.getSignOffReports();
      if (response.isSuccess && response.data != null) {
        final reportsData = response.data is List
            ? response.data as List
            : (response.data!['data'] as List? ?? []);

        final Map<String, String> titles = {};
        for (final json in reportsData) {
          final id = json['id']?.toString();
          if (id == null) continue;

          final contentRaw = json['content'] as Map<String, dynamic>?;
          final title = contentRaw?['reportTitle']?.toString() ??
              json['reportTitle']?.toString() ??
              json['report_title']?.toString() ??
              'Untitled Report';
          titles[id] = title;
        }

        if (mounted) {
          setState(() {
            _reportTitles = titles;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadFilters() async {
    try {
      final projects = await _sprintService.getProjects();
      final sprints = await _sprintService.getSprints();
      final deliverablesResponse = await _deliverableService.getDeliverables();

      setState(() {
        _projects = projects;
        _sprints = sprints;
        if (deliverablesResponse.isSuccess &&
            deliverablesResponse.data != null) {
          _deliverables =
              deliverablesResponse.data!['deliverables'] as List? ?? [];
        }
      });

      if (widget.projectKey != null && widget.projectKey!.isNotEmpty) {
        for (final p in _projects) {
          final key = (p['key'] ?? '').toString();
          if (key == widget.projectKey) {
            _selectedProjectId = p['id']?.toString();
            _selectedSprintId = null;
            break;
          }
        }
      }
    } catch (e) {
      // Silently fail - filters will just be empty
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);

    try {
      final response = await _documentService.getDocuments(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        fileType: _selectedFileType != 'all' ? _selectedFileType : null,
        projectId: _selectedProjectId,
        sprintId: _selectedSprintId,
        deliverableId: _selectedDeliverableId,
        from: _dateFrom?.toIso8601String(),
        to: _dateTo?.toIso8601String(),
      );

      if (response.isSuccess) {
        setState(() {
          _documents = (response.data!['documents'] as List)
              .cast<RepositoryFile>()
              .toList();
          _filteredDocuments = _documents;
        });
        _filterDocuments();
      } else {
        _showErrorSnackBar('Failed to load documents: ${response.error}');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading documents: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        // For web platform, we need to handle the file differently
        if (kIsWeb) {
          // On web, we can't create a File from path, so we'll handle it differently
          _showWebUploadDialog(pickedFile);
        } else {
          final filePath = pickedFile.path!;
          _showUploadDialog(filePath);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting file: $e');
    }
  }

  void _showUploadDialog(String filePath) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: const Text('Upload Document',
            style: TextStyle(color: FlownetColors.pureWhite)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'File: ${filePath.split('/').last}',
                style: const TextStyle(color: FlownetColors.coolGray),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(color: FlownetColors.coolGray),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: FlownetColors.pureWhite),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (optional, comma-separated)',
                  labelStyle: TextStyle(color: FlownetColors.coolGray),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: FlownetColors.pureWhite),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _descriptionController.clear();
              _tagsController.clear();
            },
            child: const Text('Cancel',
                style: TextStyle(color: FlownetColors.coolGray)),
          ),
          ElevatedButton(
            onPressed: () => _performUpload(filePath),
            style: ElevatedButton.styleFrom(
                backgroundColor: FlownetColors.crimsonRed),
            child: const Text('Upload',
                style: TextStyle(color: FlownetColors.pureWhite)),
          ),
        ],
      ),
    );
  }

  Future<void> _performUpload(String filePath) async {
    Navigator.pop(context);

    if (_selectedProjectId == null) {
      if (_projects.length == 1) {
        final onlyId = _projects.first['id']?.toString();
        if (onlyId != null && onlyId.isNotEmpty) {
          _selectedProjectId = onlyId;
        }
      }
    }
    if (_selectedProjectId == null) {
      _showErrorSnackBar('Please select a project before uploading a repository document.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? selectedProjectKey;
      try {
        if (_selectedProjectId != null) {
          final p = _projects.firstWhere(
            (x) => (x['id']?.toString() ?? '') == _selectedProjectId,
            orElse: () => const <String, dynamic>{},
          );
          if (p.isNotEmpty) {
            selectedProjectKey = (p['key'] ?? '').toString();
          }
        }
      } catch (_) {}

      final response = await _documentService.uploadDocument(
        filePath: filePath,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        tags: _tagsController.text.isNotEmpty ? _tagsController.text : null,
        projectId: _selectedProjectId,
        projectKey: selectedProjectKey,
        sprintId: _selectedSprintId,
        deliverableId: _selectedDeliverableId,
      );

      if (response.isSuccess) {
        _showSuccessSnackBar('Document uploaded successfully!');
        _descriptionController.clear();
        _tagsController.clear();
        _loadDocuments();
      } else {
        _showErrorSnackBar('Failed to upload document: ${response.error}');
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading document: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showWebUploadDialog(PlatformFile pickedFile) {
    showAppDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: const Text('Upload Document',
            style: TextStyle(color: FlownetColors.pureWhite)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'File: ${pickedFile.name}',
                style: const TextStyle(color: FlownetColors.pureWhite),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: FlownetColors.pureWhite),
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(color: FlownetColors.coolGray),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: FlownetColors.coolGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: FlownetColors.crimsonRed),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tagsController,
                style: const TextStyle(color: FlownetColors.pureWhite),
                decoration: const InputDecoration(
                  labelText: 'Tags (optional, comma-separated)',
                  labelStyle: TextStyle(color: FlownetColors.coolGray),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: FlownetColors.coolGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: FlownetColors.crimsonRed),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: FlownetColors.coolGray)),
          ),
          ElevatedButton(
            onPressed: () => _performWebUpload(pickedFile),
            style: ElevatedButton.styleFrom(
                backgroundColor: FlownetColors.crimsonRed),
            child: const Text('Upload',
                style: TextStyle(color: FlownetColors.pureWhite)),
          ),
        ],
      ),
    );
  }

  Future<void> _performWebUpload(PlatformFile pickedFile) async {
    Navigator.pop(context);

    if (pickedFile.bytes == null) {
      _showErrorSnackBar('Failed to read file. Please try again.');
      return;
    }

    if (_selectedProjectId == null) {
      if (_projects.length == 1) {
        final onlyId = _projects.first['id']?.toString();
        if (onlyId != null && onlyId.isNotEmpty) {
          _selectedProjectId = onlyId;
        }
      }
    }
    if (_selectedProjectId == null) {
      _showErrorSnackBar('Please select a project before uploading a repository document.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? selectedProjectKey;
      try {
        if (_selectedProjectId != null) {
          final p = _projects.firstWhere(
            (x) => (x['id']?.toString() ?? '') == _selectedProjectId,
            orElse: () => const <String, dynamic>{},
          );
          if (p.isNotEmpty) {
            selectedProjectKey = (p['key'] ?? '').toString();
          }
        }
      } catch (_) {}

      final response = await _documentService.uploadWebDocument(
        fileBytes: pickedFile.bytes!,
        fileName: pickedFile.name,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        tags: _tagsController.text.isNotEmpty ? _tagsController.text : null,
        projectId: _selectedProjectId,
        projectKey: selectedProjectKey,
        sprintId: _selectedSprintId,
        deliverableId: _selectedDeliverableId,
      );

      if (response.isSuccess) {
        _showSuccessSnackBar('Document uploaded successfully!');
        _descriptionController.clear();
        _tagsController.clear();
        _loadDocuments();
      } else {
        _showErrorSnackBar('Failed to upload document: ${response.error}');
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading document: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadDocument(RepositoryFile document) async {
    setState(() => _isLoading = true);

    try {
      final response = await _documentService.downloadDocument(document.id);

      if (response.isSuccess) {
        if (kIsWeb) {
          // For web, the download should trigger automatically
          _showSuccessSnackBar('Document download started!');
        } else {
          final filePath = response.data!['filePath'];
          _showSuccessSnackBar('Document downloaded to: $filePath');
          final uri = Uri.file(filePath);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      } else {
        _showErrorSnackBar('Failed to download document: ${response.error}');
      }
    } catch (e) {
      _showErrorSnackBar('Error downloading document: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDocument(RepositoryFile document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlownetColors.graphiteGray,
        title: const Text('Delete Document',
            style: TextStyle(color: FlownetColors.pureWhite)),
        content: Text(
          'Are you sure you want to delete "${document.name}"?',
          style: const TextStyle(color: FlownetColors.coolGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: FlownetColors.coolGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: FlownetColors.crimsonRed),
            child: const Text('Delete',
                style: TextStyle(color: FlownetColors.pureWhite)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final response = await _documentService.deleteDocument(document.id);

        if (response.isSuccess) {
          // Remove from local list immediately
          setState(() {
            _documents.removeWhere((doc) => doc.id == document.id);
            _filteredDocuments.removeWhere((doc) => doc.id == document.id);
          });
          _showSuccessSnackBar('Document deleted successfully!');
          // Reload to sync with server
          _loadDocuments();
        } else {
          _showErrorSnackBar('Failed to delete document: ${response.error}');
        }
      } catch (e) {
        _showErrorSnackBar('Error deleting document: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _previewDocument(RepositoryFile document) async {
    showAppDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: DocumentPreviewWidget(
          document: document,
          documentService: _documentService,
        ),
      ),
    );
  }

  void _filterDocuments() {
    setState(() {
      _filteredDocuments = _documents.where((doc) {
        final q = _searchQuery.toLowerCase();
        final matchesSearch = q.isEmpty ||
            doc.name.toLowerCase().contains(q) ||
            doc.description.toLowerCase().contains(q) ||
            (doc.tags != null && doc.tags!.toLowerCase().contains(q)) ||
            (doc.uploaderName?.toLowerCase().contains(q) == true) ||
            doc.uploader.toLowerCase().contains(q);

        final matchesFileType = _selectedFileType == 'all' ||
            doc.fileType.toLowerCase() == _selectedFileType.toLowerCase();

        final inDateRange = (_dateFrom == null && _dateTo == null) ||
            ((_dateFrom == null || doc.uploadDate.isAfter(_dateFrom!)) &&
                (_dateTo == null || doc.uploadDate.isBefore(_dateTo!)));

        return matchesSearch && matchesFileType && inDateRange;
      }).toList();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _filterDocuments();
  }

  void _onFileTypeChanged(String? value) {
    setState(() {
      _selectedFileType = value ?? 'all';
    });
    _filterDocuments();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      useBackgroundImage: true,
      centered: false,
      scrollable: false,
      useGlassContainer: false,
      appBar: AppBar(
        title: const Text('Repository'),
        backgroundColor: Colors.transparent,
        foregroundColor: FlownetColors.pureWhite,
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: FlownetColors.graphiteGray,
              border: Border(
                bottom: BorderSide(color: FlownetColors.slate, width: 1),
              ),
            ),
            child: Column(
              children: [
                // First row: Search and file type
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search documents...',
                          hintStyle: TextStyle(color: FlownetColors.coolGray),
                          prefixIcon:
                              Icon(Icons.search, color: FlownetColors.coolGray),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: FlownetColors.charcoalBlack,
                        ),
                        style: const TextStyle(color: FlownetColors.pureWhite),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _selectedFileType,
                      onChanged: _onFileTypeChanged,
                      dropdownColor: FlownetColors.graphiteGray,
                      style: const TextStyle(color: FlownetColors.pureWhite),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All Types')),
                        DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                        DropdownMenuItem(value: 'docx', child: Text('Word')),
                        DropdownMenuItem(value: 'xlsx', child: Text('Excel')),
                        DropdownMenuItem(value: 'txt', child: Text('Text')),
                        DropdownMenuItem(value: 'json', child: Text('JSON')),
                        DropdownMenuItem(value: 'sql', child: Text('SQL')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Second row: Filters
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown<String?>(
                        value: _selectedProjectId,
                        hint: 'All Projects',
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('All Projects')),
                          ..._projects.map(
                            (p) => DropdownMenuItem<String?>(
                              value: p['id']?.toString(),
                              child: Text((p['name'] ?? 'Unknown').toString()),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedProjectId = value;
                            _selectedSprintId = null;
                          });
                          try {
                            final proj = _projects.firstWhere(
                              (p) => p['id']?.toString() == value,
                              orElse: () => {},
                            );
                            final key = proj.isNotEmpty
                                ? (proj['key'] ?? '').toString()
                                : '';
                            if (key.isNotEmpty) {
                              GoRouter.of(context).go('/repository/$key');
                            }
                          } catch (_) {}
                          _loadDocuments();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown<String?>(
                        value: _selectedSprintId,
                        hint: 'All Sprints',
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('All Sprints')),
                          ..._sprints
                              .where((s) =>
                                  _selectedProjectId == null ||
                                  (s['project_id']?.toString() ==
                                      _selectedProjectId))
                              .map(
                                (s) => DropdownMenuItem<String?>(
                                  value: s['id']?.toString(),
                                  child:
                                      Text((s['name'] ?? 'Unknown').toString()),
                                ),
                              ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedSprintId = value);
                          _loadDocuments();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown<String?>(
                        value: _selectedDeliverableId,
                        hint: 'All Deliverables',
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('All Deliverables')),
                          ..._deliverables.map((d) {
                            // Handle both Map and Deliverable object
                            final id = d is Map ? d['id'] : d.id;
                            final title = d is Map ? d['title'] : d.title;
                            return DropdownMenuItem<String?>(
                              value: id?.toString(),
                              child: Text((title ?? 'Unknown').toString()),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedDeliverableId = value);
                          _loadDocuments();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDateRange(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  color: FlownetColors.charcoalBlack,
                                  border:
                                      Border.all(color: FlownetColors.slate),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _dateFrom != null && _dateTo != null
                                      ? '${_formatDateShort(_dateFrom!)} - ${_formatDateShort(_dateTo!)}'
                                      : 'Date Range',
                                  style: TextStyle(
                                    color: _dateFrom != null && _dateTo != null
                                        ? FlownetColors.pureWhite
                                        : FlownetColors.coolGray,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_dateFrom != null || _dateTo != null)
                            IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18, color: FlownetColors.coolGray),
                              onPressed: () {
                                setState(() {
                                  _dateFrom = null;
                                  _dateTo = null;
                                });
                                _loadDocuments();
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Documents list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          FlownetColors.crimsonRed),
                    ),
                  )
                : _filteredDocuments.isEmpty
                    ? const Center(
                        child: Text(
                          'No documents found',
                          style: TextStyle(
                            color: FlownetColors.coolGray,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredDocuments.length,
                        itemBuilder: (context, index) {
                          final document = _filteredDocuments[index];
                          return _buildDocumentCard(document);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadDocument,
        backgroundColor: FlownetColors.crimsonRed,
        child: const Icon(Icons.add, color: FlownetColors.pureWhite),
      ),
    );
  }

  String _getDisplayName(RepositoryFile document) {
    final name = document.name;
    String? reportId;

    // Try to extract ID from various patterns
    // 1. Exact match: ID.pdf
    var match = RegExp(r'^([a-zA-Z0-9-]+)\.pdf$').firstMatch(name);

    // 2. Prefix match: report_ID.pdf or Title_ID.pdf
    match ??= RegExp(r'[._-]([a-zA-Z0-9-]+)\.pdf$').firstMatch(name);

    if (match != null) {
      reportId = match.group(1);
    }

    if (reportId != null && _reportTitles.containsKey(reportId)) {
      return '${_reportTitles[reportId]}.pdf';
    }

    return name;
  }

  Widget _buildDocumentCard(RepositoryFile document) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: FlownetColors.graphiteGray.withValues(alpha: 0.6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getFileTypeColor(document.fileType),
          child: Text(
            document.fileType.toUpperCase().substring(0, 1),
            style: const TextStyle(
              color: FlownetColors.pureWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          _getDisplayName(document),
          style: const TextStyle(
            color: FlownetColors.pureWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uploaded by: ${document.uploaderName ?? document.uploader}',
              style: const TextStyle(color: FlownetColors.coolGray),
            ),
            Text(
              'Size: ${_formatFileSize(document.sizeInMB)} • ${_formatDate(document.uploadDate)}',
              style: const TextStyle(color: FlownetColors.coolGray),
            ),
            if (document.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  document.description,
                  style: const TextStyle(
                    color: FlownetColors.coolGray,
                    fontSize: 12,
                  ),
                ),
              ),
            if (document.tags != null && document.tags!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: document.tags!
                      .split(',')
                      .map(
                        (tag) => Chip(
                          label: Text(tag.trim(),
                              style: const TextStyle(fontSize: 10)),
                          backgroundColor:
                              FlownetColors.electricBlue.withValues(alpha: 0.2),
                          labelStyle: const TextStyle(
                              color: FlownetColors.electricBlue),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility,
                  color: FlownetColors.electricBlue),
              onPressed: () => _previewDocument(document),
              tooltip: 'Preview',
            ),
            IconButton(
              icon: const Icon(Icons.history, color: FlownetColors.coolGray),
              onPressed: () => _showDocumentAuditHistory(document.id),
              tooltip: 'Audit History',
            ),
            IconButton(
              icon:
                  const Icon(Icons.download, color: FlownetColors.electricBlue),
              onPressed: () => _downloadDocument(document),
              tooltip: 'Download',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: FlownetColors.crimsonRed),
              onPressed: () => _deleteDocument(document),
              tooltip: 'Delete',
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getFileTypeColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return FlownetColors.crimsonRed;
      case 'json':
        return FlownetColors.electricBlue;
      case 'sql':
        return FlownetColors.emeraldGreen;
      case 'doc':
      case 'docx':
        return FlownetColors.amberOrange;
      case 'xlsx':
      case 'xls':
        return FlownetColors.emeraldGreen;
      case 'txt':
        return FlownetColors.slate;
      default:
        return FlownetColors.slate;
    }
  }

  String _formatFileSize(double sizeInMB) {
    if (sizeInMB < 1) {
      return '${(sizeInMB * 1024).toStringAsFixed(0)} KB';
    }
    return '${sizeInMB.toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final tz = date.toUtc().add(const Duration(hours: 2));
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(tz.day)}/${two(tz.month)}/${tz.year} ${two(tz.hour)}:${two(tz.minute)}';
  }

  String _formatDateShort(DateTime date) {
    return '${date.day}/${date.month}';
  }

  Widget _buildFilterDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: FlownetColors.coolGray),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: FlownetColors.charcoalBlack,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      isExpanded: true,
      style: const TextStyle(color: FlownetColors.pureWhite, fontSize: 14),
      dropdownColor: FlownetColors.graphiteGray,
      items: items,
      selectedItemBuilder: (context) => items
          .map((item) => Align(
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle.merge(
                  overflow: TextOverflow.ellipsis,
                  child: item.child,
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            primaryColor: FlownetColors.electricBlue,
            colorScheme: const ColorScheme.dark(
              primary: FlownetColors.electricBlue,
              onPrimary: FlownetColors.pureWhite,
              surface: FlownetColors.graphiteGray,
              onSurface: FlownetColors.pureWhite,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
      _loadDocuments();
    }
  }

  void _showDocumentAuditHistory(String documentId) {
    showAppDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: FlownetColors.graphiteGray,
        child: Container(
          width: 600,
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Audit History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: FlownetColors.pureWhite,
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: FlownetColors.pureWhite),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: FlownetColors.slate),
              Expanded(
                child: AuditHistoryWidget(
                  documentId: documentId,
                  documentService: _documentService,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FlownetColors.emeraldGreen,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FlownetColors.crimsonRed,
      ),
    );
  }
}
