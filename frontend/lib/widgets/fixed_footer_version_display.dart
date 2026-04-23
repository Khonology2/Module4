import 'package:flutter/material.dart';
import '../services/version_service.dart';

class FixedFooterVersionDisplay extends StatelessWidget {
  const FixedFooterVersionDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final versionInfo = VersionService.getVersionDetails();
    final version = versionInfo['version'].toString();
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: Center(
            child: Text(
              version,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400, // Regular weight
                color: Colors.white.withValues(alpha: 0.65), // ~0.65 opacity
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
