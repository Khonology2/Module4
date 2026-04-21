import 'package:flutter/material.dart';
import '../services/version_service.dart';

class FixedFooterVersionDisplay extends StatelessWidget {
  const FixedFooterVersionDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 12,
      left: 14,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: FutureBuilder<Map<String, dynamic>>(
            future: VersionService.getVersionDetailsFromAsset(forceRefresh: true),
            builder: (context, snapshot) {
              final versionInfo =
                  snapshot.data ?? VersionService.getVersionDetails();
              final version = versionInfo['version'].toString();
              final tooltip = VersionService.getLatestCommitTooltip(versionInfo);
              return Tooltip(
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
                child: Text(
                  version,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.72),
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.left,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
