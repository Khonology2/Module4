import 'package:flutter/material.dart';
import '../services/version_service.dart';
import 'package:google_fonts/google_fonts.dart';

class SidebarVersionDisplay extends StatelessWidget {
  final bool isSidebarCollapsed;

  const SidebarVersionDisplay({
    super.key,
    this.isSidebarCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Only show version when sidebar is expanded
    if (isSidebarCollapsed) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: VersionService.getVersionDetailsFromAsset(),
      builder: (context, snapshot) {
        final versionInfo = snapshot.data ?? VersionService.getVersionDetails();
        final version = versionInfo['version'].toString();
        final tooltip = VersionService.getLatestCommitTooltip(versionInfo);
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
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
              child: Text(
                version,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w400,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.58)
                      : const Color(0xFF5A5A5A),
                  letterSpacing: 0.15,
                ),
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
}
