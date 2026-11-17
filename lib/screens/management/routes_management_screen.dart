import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mock_data_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';

class RoutesManagementScreen extends StatefulWidget {
  final int? initialRouteId;
  const RoutesManagementScreen({super.key, this.initialRouteId});

  @override
  State<RoutesManagementScreen> createState() => _RoutesManagementScreenState();
}

class _RoutesManagementScreenState extends State<RoutesManagementScreen> {
  final _mockData = MockDataService();
  int? _selectedRouteId;

  @override
  void initState() { super.initState(); _selectedRouteId = widget.initialRouteId; }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('ניהול קווים'),
          leading: _selectedRouteId != null
              ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedRouteId = null))
              : null,
        ),
        body: _selectedRouteId != null ? _buildDetail() : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mockData.routes.length,
      itemBuilder: (_, i) {
        final route = _mockData.routes[i];
        final students = _mockData.getStudentsForRoute(route.id);
        final escort = route.escortId != null ? _mockData.getUserById(route.escortId!) : null;
        final driver = route.driverId != null ? _mockData.getUserById(route.driverId!) : null;
        final vehicle = route.vehicleId != null ? _mockData.getVehicleById(route.vehicleId!) : null;
        final school = _mockData.getSchoolById(route.schoolId);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _selectedRouteId = route.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(route.direction == 'morning' ? Icons.wb_sunny : Icons.nights_stay, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(route.routeName, style: GoogleFonts.heebo(fontSize: 16, fontWeight: FontWeight.w700))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: route.status == 'active' ? AppColors.statusBoardedBg : AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                        child: Text(AppConstants.rideStatusLabels[route.status] ?? route.status, style: GoogleFonts.heebo(fontSize: 12, fontWeight: FontWeight.w700, color: route.status == 'active' ? AppColors.statusBoarded : AppColors.onSurfaceVariant)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    children: [
                      _chip(Icons.school, school?.name ?? ''),
                      _chip(Icons.people, '${students.length} תלמידים'),
                      if (escort != null) _chip(Icons.person, escort.fullName),
                      if (driver != null) _chip(Icons.drive_eta, driver.fullName),
                      if (vehicle != null) _chip(Icons.directions_bus, vehicle.vehicleNumber),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetail() {
    final route = _mockData.routes.firstWhere((r) => r.id == _selectedRouteId);
    final students = _mockData.getStudentsForRoute(route.id);
    final escort = route.escortId != null ? _mockData.getUserById(route.escortId!) : null;
    final driver = route.driverId != null ? _mockData.getUserById(route.driverId!) : null;
    final vehicle = route.vehicleId != null ? _mockData.getVehicleById(route.vehicleId!) : null;
    final school = _mockData.getSchoolById(route.schoolId);

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(route.routeName, style: GoogleFonts.heebo(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16, runSpacing: 8,
                children: [
                  _chip(Icons.school, school?.name ?? ''),
                  if (escort != null) _chip(Icons.person, 'מלווה: ${escort.fullName}'),
                  if (driver != null) _chip(Icons.drive_eta, 'נהג: ${driver.fullName}'),
                  if (vehicle != null) _chip(Icons.directions_bus, '${vehicle.vehicleNumber} (${vehicle.seatsCount} מקומות)'),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('תלמידים בקו (${students.length})', style: GoogleFonts.heebo(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: students.length,
            itemBuilder: (_, i) {
              final s = students[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.08), child: Text(s.firstName[0], style: GoogleFonts.heebo(color: AppColors.primary, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.fullName, style: GoogleFonts.heebo(fontWeight: FontWeight.w700)),
                          Text(s.address, style: GoogleFonts.heebo(fontSize: 13, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (s.mobilityStatus != null && s.mobilityStatus != 'רגיל')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(s.mobilityStatus!, style: GoogleFonts.heebo(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.heebo(fontSize: 12, color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}
