// Web-specific implementation using dart:html
// This file is only imported on web via conditional imports
// ignore_for_file: avoid_web_libraries_in_flutter
// ignore_for_file: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

void triggerWebDownloadImpl(List<int> bytes, String fileName) {
  final uint8List = Uint8List.fromList(bytes);
  final blob = html.Blob([uint8List]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..style.display = 'none'
    ..download = fileName;
  
  if (html.document.body != null) {
    html.document.body!.children.add(anchor);
    anchor.click();
    // Wait a bit before removing to ensure download starts
    Future.delayed(const Duration(milliseconds: 100), () {
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    });
  }
}

