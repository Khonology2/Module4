import 'package:flutter/material.dart';
import '../services/version_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfessionalVersionDisplay extends StatelessWidget {
  final bool showInSidebar;
  final bool isSidebarCollapsed;

  const ProfessionalVersionDisplay({
    super.key,
    this.showInSidebar = false,
    this.isSidebarCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    // Hide version when sidebar is collapsed
    if (showInSidebar && isSidebarCollapsed) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: showInSidebar 
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: showInSidebar
          ? Colors.white.withAlpha((0.05 * 255).round())
          : Colors.black.withAlpha((0.6 * 255).round()),
        borderRadius: BorderRadius.circular(
          showInSidebar ? 8 : 12,
        ),
        border: showInSidebar
          ? Border.all(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              width: 0.5,
            )
          : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: showInSidebar 
          ? CrossAxisAlignment.start 
          : CrossAxisAlignment.center,
        children: [
          FutureBuilder<Map<String, dynamic>>(
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
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha((0.85 * 255).round()),
                    fontSize: showInSidebar ? 10 : 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Centered version display for landing/login/register screens
class CenteredVersionDisplay extends StatelessWidget {
  const CenteredVersionDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: ProfessionalVersionDisplay(),
      ),
    );
  }
}
