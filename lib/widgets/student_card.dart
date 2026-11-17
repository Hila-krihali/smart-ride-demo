import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import 'status_chip.dart';

class StudentCard extends StatelessWidget {
  final Student student;
  final Attendance? attendance;
  final String? parentName;
  final String? parentPhone;
  final VoidCallback? onStatusTap;

  const StudentCard({super.key, required this.student, this.attendance, this.parentName, this.parentPhone, this.onStatusTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
      child: InkWell(
        onTap: onStatusTap,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              child: Text(student.firstName[0], style: GoogleFonts.heebo(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.fullName, style: GoogleFonts.heebo(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(student.address, style: GoogleFonts.heebo(color: AppColors.onSurfaceVariant, fontSize: 13)),
                  if (student.mobilityStatus != null && student.mobilityStatus != 'רגיל')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        Icon(Icons.accessible, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(student.mobilityStatus!, style: GoogleFonts.heebo(fontSize: 12, color: AppColors.warning)),
                      ]),
                    ),
                  if (student.notes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(student.notes!, style: GoogleFonts.heebo(fontSize: 12, color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
            if (attendance != null)
              StatusChip(label: AppConstants.attendanceStatusLabels[attendance!.status] ?? attendance!.status, status: attendance!.status),
          ],
        ),
      ),
    );
  }
}
