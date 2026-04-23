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
    final versionInfo = VersionService.getVersionDetails();
    final version = versionInfo['version'].toString();

    // Only show version when sidebar is expanded
    if (isSidebarCollapsed) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        version,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400, // Regular weight
          color: Colors.white.withValues(alpha: 0.65), // ~0.6-0.7 opacity
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
