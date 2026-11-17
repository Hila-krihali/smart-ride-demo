import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/alert.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';

class AlertCard extends StatelessWidget {
  final Alert alert;
  const AlertCard({super.key, required this.alert});

  IconData _getIcon() {
    switch (alert.alertType) {
      case 'delay': return Icons.schedule;
      case 'route_deviation': return Icons.wrong_location;
      case 'long_stop': return Icons.pause_circle;
      case 'parent_report': return Icons.person;
      case 'emergency': return Icons.warning;
      default: return Icons.info;
    }
  }

  Color _getSeverityColor() {
    switch (alert.severity) {
      case 'high': return AppColors.error;
      case 'medium': return AppColors.warning;
      case 'low': return AppColors.statusDropped;
      default: return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _getSeverityColor().withValues(alpha: 0.12),
            child: Icon(_getIcon(), color: _getSeverityColor()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.message, style: GoogleFonts.heebo(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(AppConstants.alertTypeLabels[alert.alertType] ?? alert.alertType, style: GoogleFonts.heebo(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: alert.status == 'open' ? _getSeverityColor() : AppColors.outline, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
