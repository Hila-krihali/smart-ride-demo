import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/student.dart';
import '../../utils/app_colors.dart';

class ParentRideTrackingScreen extends StatefulWidget {
  final AppUser user;
  final Student student;

  const ParentRideTrackingScreen({
    super.key,
    required this.user,
    required this.student,
  });

  @override
  State<ParentRideTrackingScreen> createState() =>
      _ParentRideTrackingScreenState();
}

class _ParentRideTrackingScreenState extends State<ParentRideTrackingScreen> {
  /*
  Future<void> _loadRouteData() async {
    try {
      final assignments = await ApiService.getRouteStudentAssignments(
        routeId: widget.student.schoolId,
      );

      final int routeId = assignments.isNotEmpty ? assignments.first.routeId : 0;

      debugPrint("DEBUG: Attempting to fetch route for routeId: $routeId");

      final optimizedRoute = await ApiService.getOptimizedRoute(
        userId: widget.user.id,
        role: widget.user.role,
        routeId: routeId,
      );

      debugPrint("DEBUG: API Response: $optimizedRoute");

      final geometry = optimizedRoute['geometry'];

      if (mounted) {
        setState(() {
          _remainingStudents = assignments
              .where((a) => a.effectiveStatus == 'waiting')
              .toList();

          if (geometry is List && geometry.isNotEmpty) {
            debugPrint("DEBUG: Geometry found! Drawing real route.");
            _routePoints = geometry.map<LatLng>((point) {
              final lon = (point as List)[0] as num;
              final lat = point[1] as num;
              return LatLng(lat.toDouble(), lon.toDouble());
            }).toList();
          } else {
            debugPrint(
              "DEBUG: No geometry found in API response, falling back to straight lines.",
            );
            _routePoints = _remainingStudents
                .map((a) => LatLng(a.student.latitude, a.student.longitude))
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint("CRITICAL ERROR in _loadRouteData: $e");
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text('מעקב הסעה - ${widget.student.firstName}')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.route,
                        color: AppColors.primary,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'COMING SOON',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.heebo(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'מעקב ההסעה נמצא כרגע בפיתוח ויהיה זמין בקרוב.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.heebo(
                        fontSize: 16,
                        height: 1.45,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('חזור'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
