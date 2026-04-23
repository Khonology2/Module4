// Web-specific implementation for PDF preview using iframe
// ignore_for_file: avoid_web_libraries_in_flutter
// ignore_for_file: deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// Map to store blob URLs by document ID
final Map<String, String> _pdfBlobUrls = {};

/// Creates a blob URL from PDF bytes and stores it by documentId
void createPdfBlobUrl(List<int> bytes, String documentId) {
  // Clean up any existing blob URL for this document
  final existingUrl = _pdfBlobUrls.remove(documentId);
  if (existingUrl != null) {
    html.Url.revokeObjectUrl(existingUrl);
  }
  
  final uint8List = Uint8List.fromList(bytes);
  final blob = html.Blob([uint8List], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  // Store blob URL with document ID as key
  _pdfBlobUrls[documentId] = url;
}

// Global map to store iframe elements by document ID
final Map<String, html.IFrameElement> _iframeElements = {};

/// Creates an iframe-based PDF viewer widget for web
Widget buildWebPdfViewer(String pdfUrl, String documentId) {
  // Extract blob URL from stored map
  String? blobUrl;
  if (pdfUrl.startsWith('pdf-blob:')) {
    // Find blob URL by document ID
    blobUrl = _pdfBlobUrls[documentId];
  } else {
    blobUrl = pdfUrl;
  }

  if (blobUrl == null) {
    return const Center(
      child: Text('PDF not loaded'),
    );
  }

  // Use a simple approach: create an iframe that displays the PDF
  return _WebPdfIframeViewer(
    pdfUrl: blobUrl,
    documentId: documentId,
  );
}

/// A widget that displays PDF using an iframe
class _WebPdfIframeViewer extends StatefulWidget {
  final String pdfUrl;
  final String documentId;

  const _WebPdfIframeViewer({
    required this.pdfUrl,
    required this.documentId,
  });

  @override
  State<_WebPdfIframeViewer> createState() => _WebPdfIframeViewerState();
}

class _WebPdfIframeViewerState extends State<_WebPdfIframeViewer> {
  bool _isRegistered = false;
  late final String _iframeId;
  static int _iframeCounter = 0;

  @override
  void initState() {
    super.initState();
    // Create unique iframe ID using counter and timestamp
    _iframeId = 'pdf-iframe-${widget.documentId}-${_iframeCounter++}-${DateTime.now().millisecondsSinceEpoch}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _registerPlatformView();
      }
    });
  }

  void _registerPlatformView() {
    if (!_isRegistered && mounted) {
      try {
        // Check if already registered to avoid duplicates
        // Register the platform view factory
        ui_web.platformViewRegistry.registerViewFactory(
          _iframeId,
          (int viewId) {
            final iframe = html.IFrameElement()
              ..id = 'pdf-iframe-element-$viewId'
              ..src = widget.pdfUrl
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%';
            
            _iframeElements[widget.documentId] = iframe;
            return iframe;
          },
        );
        _isRegistered = true;
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        // If registration fails (e.g., already registered), just mark as registered
        _isRegistered = true;
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  @override
  void dispose() {
    final iframe = _iframeElements.remove(widget.documentId);
    iframe?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRegistered) {
      return const Center(child: CircularProgressIndicator());
    }

    // Use HtmlElementView with the registered view type
    // Create a unique key to avoid duplicates
    return SizedBox.expand(
      child: HtmlElementView(
        key: ValueKey('pdf-viewer-${widget.documentId}-$_iframeId'),
        viewType: _iframeId,
      ),
    );
  }
}

/// Clean up blob URLs when done
void disposePdfBlobUrl(String documentId) {
  final url = _pdfBlobUrls.remove(documentId);
  if (url != null) {
    html.Url.revokeObjectUrl(url);
  }
  // Also clean up iframe element
  final iframe = _iframeElements.remove(documentId);
  iframe?.remove();
}

/// Clear all blob URLs (useful when documents are deleted)
void clearAllPdfBlobUrls() {
  for (final url in _pdfBlobUrls.values) {
    html.Url.revokeObjectUrl(url);
  }
  _pdfBlobUrls.clear();
  
  // Clean up all iframe elements
  for (final iframe in _iframeElements.values) {
    iframe.remove();
  }
  _iframeElements.clear();
}

