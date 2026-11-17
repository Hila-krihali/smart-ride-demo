import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../models/ride_route.dart';
import '../../services/api_service.dart';
import '../../services/mock_data_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/alert_card.dart';
import '../auth/login_screen.dart';
import 'students_management_screen.dart';
import 'routes_management_screen.dart';

class ManagementDashboardScreen extends StatefulWidget {
  final AppUser user;
  const ManagementDashboardScreen({super.key, required this.user});

  @override
  State<ManagementDashboardScreen> createState() => _ManagementDashboardScreenState();
}

class _ManagementDashboardScreenState extends State<ManagementDashboardScreen> {
  final _mockData = MockDataService();
  int _selectedTab = 0;
  late Future<_ManagementData> _managementDataFuture;

  @override
  void initState() {
    super.initState();
    _managementDataFuture = _loadManagementData();
  }

  Future<_ManagementData> _loadManagementData() async {
    try {
      final summary = await ApiService.getManagementDashboard(
        userId: widget.user.id,
        role: widget.user.role,
      );
      final routes = await ApiService.getManagementRoutes(
        userId: widget.user.id,
        role: widget.user.role,
      );
      return _ManagementData(summary: summary, routes: routes);
    } catch (error) {
      debugPrint('ManagementDashboard backend load failed; using mock fallback: $error');
      return _ManagementData(
        summary: {
          'active_rides': _mockData.rides.where((r) => r.status == 'active').length,
          'students': _mockData.students.where((s) => s.isActive).length,
          'alerts': _mockData.alerts.where((a) => a.status == 'open').length,
          'routes': _mockData.routes.length,
        },
        routes: _mockData.routes,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('לוח בקרה - הנהלה'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: () {
                ApiService.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
        body: FutureBuilder<_ManagementData>(
          future: _managementDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data ??
                _ManagementData(summary: const {}, routes: const []);

            return Column(
              children: [
                _buildSummaryCards(data.summary),
                _buildTabBar(),
                Expanded(child: _buildTabContent(data)),
              ],
            );
          },
        ),
        drawer: _buildDrawer(),
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    final activeRides = summary['active_rides'] ?? 0;
    final totalStudents = summary['students'] ?? 0;
    final openAlerts = summary['alerts'] ?? 0;
    final totalRoutes = summary['routes'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _summaryTile('פעילות', '$activeRides', Icons.directions_bus, AppColors.statusBoarded),
          const SizedBox(width: 8),
          _summaryTile('תלמידים', '$totalStudents', Icons.people, AppColors.primary),
          const SizedBox(width: 8),
          _summaryTile('התראות', '$openAlerts', Icons.warning, AppColors.warning),
          const SizedBox(width: 8),
          _summaryTile('קווים', '$totalRoutes', Icons.route, AppColors.statusDropped),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.heebo(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: GoogleFonts.heebo(fontSize: 11, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
      child: Row(
        children: [
          _tabBtn('קווים', 0, Icons.route),
          _tabBtn('התראות', 1, Icons.notifications),
          _tabBtn('דיווחים', 2, Icons.assignment),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int idx, IconData icon) {
    final sel = _selectedTab == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: sel ? Colors.white : AppColors.onSurfaceVariant, size: 20),
              Text(label, style: GoogleFonts.heebo(color: sel ? Colors.white : AppColors.onSurfaceVariant, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(_ManagementData data) {
    switch (_selectedTab) {
      case 0: return _buildRoutesTab(data.routes);
      case 1: return _buildAlertsTab();
      case 2: return _buildReportsTab();
      default: return const SizedBox();
    }
  }

  Widget _buildRoutesTab(List<RideRoute> routes) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: routes.length,
      itemBuilder: (context, i) {
        final route = routes[i];
        final students = _mockData.getStudentsForRoute(route.id);
        final escort = route.escortId != null ? _mockData.getUserById(route.escortId!) : null;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoutesManagementScreen(initialRouteId: route.id))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                    child: Icon(route.direction == 'morning' ? Icons.wb_sunny : Icons.nights_stay, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(route.routeName, style: GoogleFonts.heebo(fontWeight: FontWeight.w700)),
                        Text('${students.length} תלמידים${escort != null ? " | מלווה: ${escort.fullName}" : ""}', style: GoogleFonts.heebo(fontSize: 13, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: route.status == 'active' ? AppColors.statusBoardedBg : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(AppConstants.rideStatusLabels[route.status] ?? route.status, style: GoogleFonts.heebo(fontSize: 12, fontWeight: FontWeight.w700, color: route.status == 'active' ? AppColors.statusBoarded : AppColors.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertsTab() {
    final alerts = _mockData.alerts.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: alerts.length, itemBuilder: (_, i) => AlertCard(alert: alerts[i]));
  }

  Widget _buildReportsTab() {
    final reports = _mockData.parentReports.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (_, i) {
        final r = reports[i];
        final parent = _mockData.getUserById(r.parentId);
        final student = _mockData.getStudentById(r.studentId);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: AppColors.warning.withValues(alpha: 0.15), child: const Icon(Icons.person, color: AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${student?.fullName ?? "?"} - ${AppConstants.reportTypeLabels[r.reportType] ?? r.reportType}', style: GoogleFonts.heebo(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('דיווח מ: ${parent?.fullName ?? "?"}', style: GoogleFonts.heebo(fontSize: 13, color: AppColors.onSurfaceVariant)),
                    if (r.message != null) Text(r.message!, style: GoogleFonts.heebo(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: r.status == 'open' ? AppColors.warning.withValues(alpha: 0.15) : AppColors.statusBoardedBg, borderRadius: BorderRadius.circular(8)),
                child: Text(r.status == 'open' ? 'פתוח' : 'טופל', style: GoogleFonts.heebo(fontSize: 12, fontWeight: FontWeight.w700, color: r.status == 'open' ? AppColors.warning : AppColors.statusBoarded)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(widget.user.fullName, style: GoogleFonts.heebo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('ניהול מערך הסעות', style: GoogleFonts.heebo(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(leading: const Icon(Icons.dashboard), title: const Text('לוח בקרה'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.people), title: const Text('ניהול תלמידים'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => StudentsManagementScreen(userId: widget.user.id, role: widget.user.role))); }),
            ListTile(leading: const Icon(Icons.route), title: const Text('ניהול קווים'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutesManagementScreen())); }),
            const Divider(),
            const ListTile(leading: Icon(Icons.family_restroom), title: Text('ניהול הורים'), subtitle: Text('בקרוב'), enabled: false),
            const ListTile(leading: Icon(Icons.supervisor_account), title: Text('ניהול מלווים'), subtitle: Text('בקרוב'), enabled: false),
            const ListTile(leading: Icon(Icons.drive_eta), title: Text('ניהול נהגים'), subtitle: Text('בקרוב'), enabled: false),
            const ListTile(leading: Icon(Icons.directions_bus), title: Text('ניהול רכבים'), subtitle: Text('בקרוב'), enabled: false),
            const ListTile(leading: Icon(Icons.folder), title: Text('קבצים שימושיים'), subtitle: Text('בקרוב'), enabled: false),
          ],
        ),
      ),
    );
  }
}

class _ManagementData {
  final Map<String, dynamic> summary;
  final List<RideRoute> routes;

  const _ManagementData({
    required this.summary,
    required this.routes,
  });
}
