import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ride_route.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import 'status_chip.dart';

class RouteCard extends StatelessWidget {
  final RideRoute route;
  final int studentCount;
  final String? escortName;
  final String? driverName;
  final VoidCallback? onTap;

  const RouteCard({super.key, required this.route, required this.studentCount, this.escortName, this.driverName, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(route.direction == 'morning' ? Icons.wb_sunny : Icons.nights_stay, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(route.routeName, style: GoogleFonts.heebo(fontWeight: FontWeight.w700, fontSize: 16))),
                  StatusChip(label: AppConstants.rideStatusLabels[route.status] ?? route.status, status: route.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('$studentCount תלמידים', style: GoogleFonts.heebo(color: AppColors.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(width: 16),
                  if (escortName != null) ...[
                    Icon(Icons.person, size: 16, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(escortName!, style: GoogleFonts.heebo(color: AppColors.onSurfaceVariant, fontSize: 13)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
