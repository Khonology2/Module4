import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'glass_card.dart';

class SprintCard extends StatelessWidget {
  final Map<String, dynamic> sprint;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<String>? onStatusChanged;

  const SprintCard({
    super.key,
    required this.sprint,
    required this.isSelected,
    required this.onTap,
    this.onStatusChanged,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      case 'future':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    
    final status = sprint['state']?.toLowerCase() ?? 'unknown';
    final statusColor = _getStatusColor(status);
    
    final startDate = sprint['startDate'] != null 
        ? DateTime.tryParse(sprint['startDate']) 
        : null;
    final endDate = sprint['endDate'] != null 
        ? DateTime.tryParse(sprint['endDate']) 
        : null;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        color: isSelected 
            ? primaryColor.withAlpha(51)  // 0.2 * 255 ≈ 51
            : surfaceColor.withAlpha(128),  // 0.5 * 255 = 128
        border: Border.all(
          color: isSelected ? primaryColor : onSurfaceColor.withAlpha(26),  // 0.1 * 255 ≈ 26
          width: isSelected ? 2 : 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(51),  // 0.2 * 255 ≈ 51
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withAlpha(128)),  // 0.5 * 255 = 128
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (onStatusChanged != null && status != 'closed')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: surfaceColor.withAlpha(51),  // 0.2 * 255 ≈ 51
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: onSurfaceColor.withAlpha(26)),  // 0.1 * 255 ≈ 26
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: status,
                        icon: const Icon(Icons.arrow_drop_down, size: 16),
                        iconSize: 16,
                        elevation: 0,
                        dropdownColor: surfaceColor,
                        style: TextStyle(
                          color: onSurfaceColor,
                          fontSize: 12,
                        ),
                        onChanged: (String? newValue) {
                          if (newValue != null && newValue != status) {
                            onStatusChanged!(newValue);
                          }
                        },
                        items: <String>['active', 'closed', 'future']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(value),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              sprint['name'] ?? 'Unnamed Sprint',
              style: TextStyle(
                color: onSurfaceColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (startDate != null && endDate != null) ...[
              Text(
                '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                style: TextStyle(
                  color: onSurfaceColor.withAlpha(179),  // 0.7 * 255 ≈ 179
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: _calculateProgress(startDate, endDate),
                backgroundColor: onSurfaceColor.withAlpha(26),  // 0.1 * 255 ≈ 26
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStat(
                  Icons.assignment,
                  '${sprint['issues']?.length ?? 0} Tickets',
                  onSurfaceColor.withAlpha(179),  // 0.7 * 255 ≈ 179
                ),
                const SizedBox(width: 12),
                _buildStat(
                  Icons.check_circle_outline,
                  '${sprint['completedIssues']?.length ?? 0} Done',
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  double _calculateProgress(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 0.0;
    if (now.isAfter(endDate)) return 1.0;
    
    final totalDuration = endDate.difference(startDate).inMilliseconds.toDouble();
    final elapsedDuration = now.difference(startDate).inMilliseconds.toDouble();
    
    return (elapsedDuration / totalDuration).clamp(0.0, 1.0);
  }
}
