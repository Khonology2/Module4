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
    final versionInfo = VersionService.getVersionDetails();
    final version = versionInfo['version'].toString();
    final environment = versionInfo['environment'] as String;

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
          // Version number with professional typography
          Text(
            version,
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha((0.85 * 255).round()),
              fontSize: showInSidebar ? 10 : 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          if (showInSidebar) ...[
            const SizedBox(height: 2),
            // Environment indicator for sidebar
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _getEnvironmentColor(environment),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  environment,
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha((0.6 * 255).round()),
                    fontSize: 8,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getEnvironmentColor(String env) {
    switch (env) {
      case 'PROD':
        return const Color(0xFFE53E3E); // Professional red
      case 'UAT':
        return const Color(0xFFED8936); // Professional orange
      case 'SIT':
        return const Color(0xFF3182CE); // Professional blue
      default:
        return const Color(0xFF718096); // Professional gray
    }
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
