// Stub implementation for non-web platforms
import 'package:flutter/material.dart';

void createPdfBlobUrl(List<int> bytes, String fileName) {
  throw UnsupportedError('Web PDF blob URL not available on this platform');
}

Widget buildWebPdfViewer(String pdfUrl, String documentId) {
  throw UnsupportedError('Web PDF viewer not available on this platform');
}

void disposePdfBlobUrl(String documentId) {
  // No-op for non-web platforms
}

void clearAllPdfBlobUrls() {
  // No-op for non-web platforms
}

