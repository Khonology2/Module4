import 'package:flutter/material.dart';

class AssetHelper {
  static const String _githubBaseUrl = 'https://raw.githubusercontent.com/Khonology2/Module4/new/frontend/assets/';
  
  /// Convert asset path to GitHub CDN URL
  static String getAssetUrl(String assetPath) {
    // Remove 'assets/' prefix if present to avoid double path
    if (assetPath.startsWith('assets/')) {
      assetPath = assetPath.substring(7);
    }
    return '$_githubBaseUrl$assetPath';
  }
  
  /// Get Image widget with automatic CDN fallback
  static Widget getImage(
    String assetPath, {
    double? width,
    double? height,
    BoxFit? fit,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    final url = getAssetUrl(assetPath);
    
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder ?? _defaultErrorBuilder,
    );
  }
  
  /// Default error builder with gradient fallback
  static Widget _defaultErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey.shade300,
            Colors.grey.shade400,
          ],
        ),
      ),
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.white54,
        size: 24,
      ),
    );
  }
}
