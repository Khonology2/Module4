import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/repository_file.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';
import '../theme/flownet_theme.dart';
import '../config/api_config.dart';
import '../config/environment.dart';

// Conditional imports for web PDF viewing
import 'document_preview_widget_stub.dart'
    if (dart.library.html) 'document_preview_widget_web.dart' as web_impl;

class DocumentPreviewWidget extends StatefulWidget {
  final RepositoryFile document;
  final DocumentService documentService;

  const DocumentPreviewWidget({
    super.key,
    required this.document,
    required this.documentService,
  });

  @override
  State<DocumentPreviewWidget> createState() => _DocumentPreviewWidgetState();
}

class _DocumentPreviewWidgetState extends State<DocumentPreviewWidget> {
  bool _isLoading = false;
  String? _previewContent;
  String? _error;
  String? _pdfUrl;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(DocumentPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If document changed, reload preview
    if (oldWidget.document.id != widget.document.id) {
      // Clean up old blob URL
      if (kIsWeb && oldWidget.document.id.isNotEmpty) {
        web_impl.disposePdfBlobUrl(oldWidget.document.id);
      }
      // Reset state for new document
      if (mounted) {
        setState(() {
          _pdfUrl = null;
          _previewContent = null;
          _error = null;
        });
        _loadPreview();
      }
    }
  }

  @override
  void dispose() {
    // Clean up blob URL when widget is disposed
    if (kIsWeb && widget.document.id.isNotEmpty) {
      web_impl.disposePdfBlobUrl(widget.document.id);
    }
    super.dispose();
  }

  Future<void> _loadPreview() async {
    // Track document view
    await widget.documentService.trackDocumentView(widget.document.id);

    setState(() {
      _isLoading = true;
      _error = null;
      _pdfUrl = null; // Reset PDF URL when loading new preview
      _previewContent = null;
    });

    try {
      final type = widget.document.fileType.toLowerCase();

      if (_isTextType(type)) {
        final response = await widget.documentService.getDocumentPreview(widget.document.id);
        if (response.isSuccess) {
          setState(() {
            _previewContent = response.data?['previewContent'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = response.error;
            _isLoading = false;
          });
        }
        return;
      }

      if (kIsWeb) {
        bool loaded = false;

        // First try public URL if available
        final publicUrl = _resolvePublicDocumentUrl();
        if (publicUrl != null) {
          setState(() {
            _pdfUrl = publicUrl;
            _isLoading = false;
          });
          loaded = true;
        }

        // If public URL didn't work, try authenticated bytes
        if (!loaded) {
          final bytes = await _getAuthenticatedDocumentBytes();
          if (bytes != null && bytes.isNotEmpty) {
            web_impl.createBlobUrl(bytes, widget.document.id, _mimeTypeForFileType(type));
            final blobUrl = web_impl.getBlobUrl(widget.document.id);
            if (blobUrl != null) {
              setState(() {
                _pdfUrl = blobUrl;
                _isLoading = false;
              });
              loaded = true;
            }
          }
        }

        if (!loaded) {
          setState(() {
            _error = 'Failed to load document preview';
            _isLoading = false;
          });
        }
        return;
      }

      if (type == 'pdf') {
        await _buildPdfUrl();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load preview: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _buildPdfUrl() async {
    try {
      if (!kIsWeb) {
        final response = await widget.documentService.downloadDocument(widget.document.id);
        if (response.isSuccess) {
          _pdfUrl = response.data?['filePath']?.toString();
        } else {
          _error = response.error ?? 'Failed to prepare PDF preview';
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to prepare PDF preview: $e';
      });
    }
  }

  Future<List<int>?> _getAuthenticatedDocumentBytes() async {
    try {
      final token = AuthService().accessToken;
      if (token == null) {
        return null;
      }

      final endpointsToTry = [
        '/documents/${widget.document.id}/content',
        '/documents/${widget.document.id}/download',
      ];

      for (final endpoint in endpointsToTry) {
        final response = await http.get(
          Uri.parse(ApiConfig.getFullUrl(endpoint)),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  bool _isTextType(String type) {
    const textTypes = ['txt', 'md', 'json', 'xml', 'csv', 'log', 'yaml', 'yml'];
    return textTypes.contains(type);
  }

  bool _isOfficeType(String type) {
    const officeTypes = ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'];
    return officeTypes.contains(type);
  }

  String? _buildOfficeViewerUrlIfPossible() {
    final type = widget.document.fileType.toLowerCase();
    if (!_isOfficeType(type)) return null;
    final publicUrl = _resolvePublicDocumentUrl();
    if (publicUrl == null) return null;
    final src = Uri.encodeComponent(publicUrl);
    return 'https://view.officeapps.live.com/op/embed.aspx?src=$src';
  }

  String _mimeTypeForFileType(String type) {
    switch (type) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
      case 'md':
      case 'log':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'csv':
        return 'text/csv';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }

  bool _canPreview() {
    return true;
  }

  bool _canInlinePreview() => _canPreview();

  Widget _buildPreviewContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(FlownetColors.electricBlue),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: FlownetColors.crimsonRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Preview Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FlownetColors.crimsonRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: FlownetColors.coolGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPreview,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlownetColors.electricBlue,
                foregroundColor: FlownetColors.pureWhite,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_canInlinePreview()) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getFileIcon(),
                size: 64,
                color: FlownetColors.coolGray,
              ),
              const SizedBox(height: 16),
              const Text(
                'Inline preview not available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FlownetColors.coolGray,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This file type is not rendered inside the app. Use Open or Download below.',
                style: TextStyle(
                  fontSize: 14,
                  color: FlownetColors.coolGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
    }

    return _buildPreviewByType();
  }

  Widget _buildPreviewByType() {
    switch (widget.document.fileType.toLowerCase()) {
      case 'pdf':
        return _buildPdfPreview();
      case 'txt':
      case 'md':
      case 'json':
      case 'xml':
      case 'csv':
        return _buildTextPreview();
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
        return _buildOfficePreview();
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return _buildImagePreview();
      default:
        if (kIsWeb && _pdfUrl != null) {
          return _buildWebIFramePreview(_pdfUrl!);
        }
        return _buildUnsupportedPreview();
    }
  }

  Widget _buildPdfPreview() {
    if (kIsWeb) {
      // For web, use iframe to display PDF
      if (_pdfUrl != null) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: FlownetColors.coolGray),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: web_impl.buildWebPdfViewer(_pdfUrl!, widget.document.id),
          ),
        );
      } else {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf,
                size: 64,
                color: FlownetColors.coolGray,
              ),
              SizedBox(height: 16),
              Text(
                'Loading PDF...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FlownetColors.coolGray,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // For mobile/desktop, use PDFView
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: FlownetColors.coolGray),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: widget.document.filePath != null
              ? PDFView(
                  filePath: _pdfUrl ?? widget.document.filePath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: false,
                  pageFling: false,
                  onRender: (pages) {
                    // PDF rendered
                  },
                  onError: (error) {
                    setState(() {
                      _error = 'PDF preview error: $error';
                    });
                  },
                  onPageError: (page, error) {
                    setState(() {
                      _error = 'Page $page error: $error';
                    });
                  },
                )
              : const Center(
                  child: Text('Preparing PDF preview...'),
                ),
        ),
      );
    }
  }

  Widget _buildOfficePreview() {
    if (!kIsWeb) {
      return _buildUnsupportedPreview();
    }
    if (_pdfUrl != null) {
      return _buildWebIFramePreview(_pdfUrl!);
    }
    return const Center(
      child: Text('Loading document...'),
    );
  }

  Widget _buildWebIFramePreview(String url) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: FlownetColors.coolGray),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: web_impl.buildWebPdfViewer(url, widget.document.id),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (kIsWeb && _pdfUrl != null) {
      return _buildWebIFramePreview(_pdfUrl!);
    }

    final imageUrl = _resolveDocumentUrl();
    if (imageUrl == null) {
      return _buildUnsupportedPreview();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: FlownetColors.coolGray),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text(
                'Image preview unavailable. Use Open or Download.',
                style: TextStyle(color: FlownetColors.coolGray),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _resolveDocumentUrl() {
    final filePath = widget.document.filePath;
    if (filePath != null && filePath.trim().isNotEmpty) {
      return Uri.parse(Environment.apiBaseUrl).resolve(filePath).toString();
    }
    return Uri.parse(Environment.apiBaseUrl)
        .resolve('/documents/${widget.document.id}/download')
        .toString();
  }

  String? _resolvePublicDocumentUrl() {
    final filePath = widget.document.filePath;
    if (filePath == null) return null;
    if (!filePath.startsWith('/uploads/')) return null;
    return Uri.parse(Environment.apiBaseUrl).resolve(filePath).toString();
  }

  Widget _buildTextPreview() {
    if (_previewContent == null) {
      return const Center(
        child: Text('No preview content available'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: FlownetColors.coolGray),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _previewContent!,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            color: FlownetColors.pureWhite,
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupportedPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileIcon(),
            size: 64,
            color: FlownetColors.coolGray,
          ),
          const SizedBox(height: 16),
          const Text(
            'Preview not supported in app',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: FlownetColors.coolGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use Open or Download to view this ${widget.document.fileType.toUpperCase()} file.',
            style: const TextStyle(
              fontSize: 14, 
              color: FlownetColors.coolGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  IconData _getFileIcon() {
    switch (widget.document.fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: FlownetColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: FlownetColors.charcoalBlack.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: FlownetColors.coolGray,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getFileIcon(),
                  color: FlownetColors.charcoalBlack,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.document.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: FlownetColors.charcoalBlack).copyWith(
                          color: FlownetColors.charcoalBlack,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.document.fileType.toUpperCase()} • ${widget.document.sizeInMB} MB',
                        style: TextStyle(fontSize: 12, color: FlownetColors.charcoalBlack.withValues(alpha: 0.7)).copyWith(
                          color: FlownetColors.charcoalBlack.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: FlownetColors.charcoalBlack,
                  ),
                ),
              ],
            ),
          ),
          // Preview content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPreviewContent(),
            ),
          ),
          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: FlownetColors.coolGray,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _downloadDocument,
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlownetColors.electricBlue,
                    foregroundColor: FlownetColors.pureWhite,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openDocument,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlownetColors.emeraldGreen,
                    foregroundColor: FlownetColors.pureWhite,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDocument() async {
    try {
      final response = await widget.documentService.downloadDocument(widget.document.id);
      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document downloaded: ${response.data?['fileName']}'),
              backgroundColor: FlownetColors.emeraldGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: ${response.error}'),
              backgroundColor: FlownetColors.crimsonRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: FlownetColors.crimsonRed,
          ),
        );
      }
    }
  }

  Future<void> _openDocument() async {
    try {
      if (kIsWeb) {
        final publicUrl = _resolvePublicDocumentUrl();
        if (publicUrl != null) {
          await launchUrl(
            Uri.parse(publicUrl),
            mode: LaunchMode.platformDefault,
            webOnlyWindowName: '_blank',
          );
          return;
        }

        final existingBlob = web_impl.getBlobUrl(widget.document.id);
        if (existingBlob != null) {
          await launchUrl(
            Uri.parse(existingBlob),
            mode: LaunchMode.platformDefault,
            webOnlyWindowName: '_blank',
          );
          return;
        }

        final bytes = await _getAuthenticatedDocumentBytes();
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Document content is unavailable');
        }

        web_impl.createBlobUrl(bytes, widget.document.id, _mimeTypeForFileType(widget.document.fileType.toLowerCase()));
        final blobUrl = web_impl.getBlobUrl(widget.document.id);
        if (blobUrl == null) {
          throw Exception('Failed to prepare document preview');
        }

        await launchUrl(
          Uri.parse(blobUrl),
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
      } else {
        final response = await widget.documentService.downloadDocument(widget.document.id);
        if (!response.isSuccess) {
          throw Exception(response.error ?? 'Failed to download file for opening');
        }
        final localPath = response.data?['filePath']?.toString();
        if (localPath == null || localPath.isEmpty) {
          throw Exception('Downloaded file path is unavailable');
        }
        final result = await OpenFile.open(localPath);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open file: ${result.message}'),
              backgroundColor: FlownetColors.crimsonRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: FlownetColors.crimsonRed,
          ),
        );
      }
    }
  }
}
