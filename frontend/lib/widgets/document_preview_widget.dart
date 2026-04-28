import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import '../models/repository_file.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';
import '../theme/flownet_theme.dart';
import '../config/api_config.dart';

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
    if (!_canPreview()) return;

    // Track document view
    await widget.documentService.trackDocumentView(widget.document.id);

    setState(() {
      _isLoading = true;
      _error = null;
      _pdfUrl = null; // Reset PDF URL when loading new preview
    });

    try {
      final response = await widget.documentService.getDocumentPreview(widget.document.id);
      if (response.isSuccess) {
        // For web PDFs, fetch and prepare for preview
        if (kIsWeb && widget.document.fileType.toLowerCase() == 'pdf') {
          await _buildPdfUrl(response.data);
        }
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
    } catch (e) {
      setState(() {
        _error = 'Failed to load preview: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _buildPdfUrl(Map<String, dynamic>? data) async {
    try {
      // For web, we need to fetch the PDF and create a blob URL
      // This ensures authentication works properly
      if (kIsWeb) {
        await _fetchPdfForPreview();
      } else {
        // For mobile/desktop, use file path
        final downloadUrl = data?['downloadUrl'] ?? 
            ApiConfig.getFullUrl('/documents/${widget.document.id}/download');
        _pdfUrl = downloadUrl;
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to prepare PDF preview: $e';
      });
    }
  }

  Future<void> _fetchPdfForPreview() async {
    try {
      // Fetch PDF bytes with authentication
      final response = await widget.documentService.downloadDocument(widget.document.id);
      if (response.isSuccess && response.data != null) {
        // For web, create blob URL from the downloaded bytes
        final bytes = await _getPdfBytes();
        if (bytes != null && kIsWeb) {
          web_impl.createPdfBlobUrl(bytes, widget.document.id);
          // Store a reference URL for the iframe
          _pdfUrl = 'pdf-blob:${widget.document.id}';
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch PDF: $e';
      });
    }
  }

  Future<List<int>?> _getPdfBytes() async {
    try {
      final token = AuthService().accessToken;
      if (token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.getFullUrl('/documents/${widget.document.id}/download')),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  bool _canPreview() {
    final supportedTypes = ['pdf', 'txt', 'md', 'json', 'xml', 'csv'];
    return supportedTypes.contains(widget.document.fileType.toLowerCase());
  }

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

    if (!_canPreview()) {
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
                'Preview not available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FlownetColors.coolGray,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This file type cannot be previewed',
                style: TextStyle(
                  fontSize: 14,
                  color: FlownetColors.coolGray,
                ),
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
      default:
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
                  filePath: widget.document.filePath!,
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
                  child: Text('File path not available'),
                ),
        ),
      );
    }
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
          Text(
            'Preview not supported',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FlownetColors.charcoalBlack).copyWith(
              color: FlownetColors.coolGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This file type cannot be previewed',
            style: const TextStyle(fontSize: 14, color: FlownetColors.coolGray).copyWith(
              color: FlownetColors.coolGray,
            ),
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
        // For web, trigger download which will open in browser
        await _downloadDocument();
      } else {
        // For mobile/desktop, try to open with system default app
        if (widget.document.filePath != null) {
          final result = await OpenFile.open(widget.document.filePath!);
          if (result.type != ResultType.done) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cannot open file: ${result.message}'),
                  backgroundColor: FlownetColors.crimsonRed,
                ),
              );
            }
          }
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
