import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final String status;
  const StatusChip({super.key, required this.label, required this.status});

  Color _getColor() {
    switch (status) {
      case 'active':
      case 'picked_up': return AppColors.statusBoarded;
      case 'waiting':
      case 'planned': return AppColors.statusDropped;
      case 'absent':
      case 'cancelled': return AppColors.statusAbsent;
      case 'delayed': return AppColors.warning;
      case 'dropped_off':
      case 'completed': return AppColors.primary;
      default: return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor(), width: 1),
      ),
      child: Text(label, style: GoogleFonts.heebo(color: _getColor(), fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
