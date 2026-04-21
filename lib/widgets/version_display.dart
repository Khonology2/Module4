import 'package:flutter/material.dart';
import '../services/version_service.dart';
import 'package:google_fonts/google_fonts.dart';

class VersionDisplay extends StatelessWidget {
  const VersionDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: VersionService.getVersionDetailsFromAsset(),
        builder: (context, snapshot) {
          final versionInfo = snapshot.data ?? VersionService.getVersionDetails();
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
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}

class VersionBanner extends StatelessWidget {
  const VersionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Return empty container to hide banner completely
    return const SizedBox.shrink();
  }
}
