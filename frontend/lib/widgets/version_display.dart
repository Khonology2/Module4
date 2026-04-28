import 'package:flutter/material.dart';
import '../services/version_service.dart';
import 'package:google_fonts/google_fonts.dart';

class VersionDisplay extends StatelessWidget {
  const VersionDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final versionInfo = VersionService.getVersionDetails();
    final environment = versionInfo['environment'] as String;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Version number
          Text(
            versionInfo['version'].toString(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          // Environment indicator with color
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: _getEnvironmentColor(environment),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          // Environment name
          Text(
            environment,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEnvironmentColor(String env) {
    switch (env) {
      case 'PROD':
        return Colors.red;
      case 'UAT':
        return Colors.orange;
      case 'SIT':
        return Colors.blue;
      default:
        return Colors.grey;
    }
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
