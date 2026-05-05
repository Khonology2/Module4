import 'package:flutter/material.dart';
import '../services/version_service.dart';

class FixedFooterVersionDisplay extends StatelessWidget {
  const FixedFooterVersionDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final versionInfo = VersionService.getVersionDetails();
    final version = versionInfo['version'].toString();
    final tooltip = VersionService.getFormattedVersionInfo();
    String displayVersion =
        version.toLowerCase().startsWith('ver ') ? version : 'Ver $version';
    if (displayVersion.contains('PROD-')) {
      displayVersion = displayVersion.replaceFirst('Ver PROD-', 'Ver ');
      displayVersion = '${displayVersion}_SIT';
    }

    return Positioned(
      bottom: 12,
      left: 14,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Tooltip(
            message: tooltip,
            waitDuration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2A1C),
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xCC101114),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
              displayVersion,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.78),
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.left,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
