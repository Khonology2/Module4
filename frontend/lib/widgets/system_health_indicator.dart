import 'package:flutter/material.dart';
import '../models/system_metrics.dart';

class SystemHealthIndicator extends StatelessWidget {
  final SystemHealthStatus status;
  final double size;
  final bool showLabel;

  const SystemHealthIndicator({
    super.key,
    required this.status,
    this.size = 32.0,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;

    switch (status) {
      case SystemHealthStatus.healthy:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Healthy';
        break;
      case SystemHealthStatus.degraded:
        color = Colors.orange;
        icon = Icons.warning;
        label = 'Degraded';
        break;
      case SystemHealthStatus.critical:
        color = Colors.red;
        icon = Icons.error;
        label = 'Critical';
        break;
      case SystemHealthStatus.unknown:
      color = Colors.grey;
        icon = Icons.help;
        label = 'Unknown';
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.0),
          ),
          child: Icon(
            icon,
            size: size * 0.6,
            color: color,
          ),
        ),
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}