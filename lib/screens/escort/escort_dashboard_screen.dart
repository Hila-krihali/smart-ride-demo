import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../models/ride.dart';
import '../../models/ride_route.dart';
import '../../models/route_student.dart';
import '../../services/api_service.dart';
import '../../services/mock_data_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../auth/login_screen.dart';

class EscortDashboardScreen extends StatefulWidget {
  final AppUser user;

  const EscortDashboardScreen({super.key, required this.user});

  @override
  State<EscortDashboardScreen> createState() => _EscortDashboardScreenState();
}

class _EscortDashboardScreenState extends State<EscortDashboardScreen> {
  final _mockData = MockDataService();

  Timer? _pollingTimer;

  _EscortData _data = _EscortData.empty();
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    _loadInitialData();

    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshSilently(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<_EscortData> _loadData() async {
    try {
      final routes = await ApiService.getRoutesForEscort(
        escortId: widget.user.id,
      );

      final route = routes.isEmpty ? null : routes.first;

      final ride = route == null
          ? null
          : await ApiService.getActiveRideForRoute(routeId: route.id);

      final students = route == null
          ? <RouteStudentInfo>[]
          : await ApiService.getRouteStudentAssignments(routeId: route.id);

      return _EscortData(route: route, ride: ride, students: students);
    } catch (error) {
      debugPrint(
        'EscortDashboard backend load failed; using mock fallback: $error',
      );

      final route = _mockData.getRouteForEscort(widget.user.id);
      final ride = route == null
          ? null
          : _mockData.getActiveRideForRoute(route.id);

      final routeId = route?.id;

      final students = routeId == null
          ? <RouteStudentInfo>[]
          : _mockData.getStudentsForRoute(routeId).map((student) {
              final attendance = ride == null
                  ? null
                  : _mockData.getAttendanceForStudent(ride.id, student.id);

              return RouteStudentInfo(
                id: student.id,
                routeId: routeId,
                studentId: student.id,
                effectiveStatus: attendance?.status ?? 'waiting',
                attendanceStatus: attendance?.status,
                rideStudentStatus: attendance?.status,
                student: student,
              );
            }).toList();

      return _EscortData(
        route: route,
        ride: ride == null
            ? null
            : Ride(
                id: ride.id,
                routeId: ride.routeId,
                rideDate: ride.rideDate,
                status: ride.status,
              ),
        students: students,
      );
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isInitialLoading = true;
      _loadError = null;
    });

    try {
      final loaded = await _loadData();

      if (!mounted) {
        return;
      }

      setState(() {
        _data = loaded;
        _isInitialLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error.toString();
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
      _loadError = null;
    });

    try {
      final loaded = await _loadData();

      if (!mounted) {
        return;
      }

      setState(() {
        _data = loaded;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error.toString();
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshSilently() async {
    if (!mounted || _isInitialLoading || _isRefreshing) {
      return;
    }

    try {
      final loaded = await _loadData();

      if (!mounted) {
        return;
      }

      if (_hasVisualChange(loaded)) {
        setState(() {
          _data = loaded;
        });
      }
    } catch (error) {
      debugPrint('EscortDashboard silent refresh failed: $error');
    }
  }

  bool _hasVisualChange(_EscortData newData) {
    if (_data.route?.id != newData.route?.id) {
      return true;
    }

    if (_data.ride?.id != newData.ride?.id) {
      return true;
    }

    if (_data.students.length != newData.students.length) {
      return true;
    }

    final oldByStudentId = {
      for (final item in _data.students) item.studentId: item,
    };

    for (final newItem in newData.students) {
      final oldItem = oldByStudentId[newItem.studentId];

      if (oldItem == null) {
        return true;
      }

      if (_statusOf(oldItem) != _statusOf(newItem)) {
        return true;
      }

      if (oldItem.attendanceStatus != newItem.attendanceStatus) {
        return true;
      }

      if (oldItem.rideStudentStatus != newItem.rideStudentStatus) {
        return true;
      }

      if (oldItem.student.pictureUrl != newItem.student.pictureUrl) {
        return true;
      }
    }

    return false;
  }

  String _statusOf(RouteStudentInfo row) {
    return row.effectiveStatus.isEmpty ? 'waiting' : row.effectiveStatus;
  }

  bool _isPassengerExpectedToday(RouteStudentInfo row) {
    final status = _statusOf(row);

    return status != 'reported_absent' && status != 'absent';
  }

  bool _isPickedUpOrDropped(RouteStudentInfo row) {
    final status = _statusOf(row);

    return status == 'picked_up' || status == 'dropped_off';
  }
Future<void> _updateStatus(
    RouteStudentInfo row,
    String status,
  ) async {
    final ride = _data.ride;

    if (ride == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('אין נסיעה פעילה לעדכון')));
      return;
    }

    // --- הנה הדיבאג החשוב: ---
    debugPrint("מלווה מנסה לשלוח לשרת: סטטוס $status עבור תלמיד ${row.student.id}");
    
    try {
      final updated = await ApiService.updateAttendanceStatus(
        userId: widget.user.id,
        role: widget.user.role,
        rideId: ride.id,
        studentId: row.student.id,
        status: status,
      );
      
      // הדפסה גם על התגובה מהשרת
      debugPrint("תשובת שרת למלווה: $updated");

      final updatedStatus = (updated['status'] ?? status).toString();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('הסטטוס עודכן ל־$updatedStatus')));

      await _refresh();
    } catch (error) {
      debugPrint('EscortDashboard attendance update failed: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('עדכון הסטטוס נכשל: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final expectedStudents = _data.students
        .where(_isPassengerExpectedToday)
        .toList();

    final pickedUpOrDropped = expectedStudents
        .where(_isPickedUpOrDropped)
        .length;

    final totalExpected = expectedStudents.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(' ${_data.route?.routeName ?? ""}'),
          actions: [
            IconButton(
              tooltip: 'רענון',
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
            IconButton(
              tooltip: 'התנתקות',
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
        body: Column(
          children: [
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _loadError!,
                  style: GoogleFonts.heebo(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      expectedStudents.isNotEmpty
                          ? expectedStudents.first.student.address
                          : 'אין תלמידים שמגיעים היום',
                      style: GoogleFonts.heebo(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    '$pickedUpOrDropped / $totalExpected',
                    style: GoogleFonts.heebo(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _data.students.length,
                  itemBuilder: (context, index) {
                    final student = _data.students[index];

                    return _StudentAttendanceCard(
                      row: student,
                      onBoarded: () {
                        _updateStatus(student, 'picked_up');
                      },
                      onDropped: () {
                        _updateStatus(student, 'dropped_off');
                      },
                      onAbsent: () {
                        _updateStatus(student, 'absent');
                      },
                      onWaiting: () {
                        _updateStatus(student, 'waiting');
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  final RouteStudentInfo row;
  final VoidCallback onBoarded;
  final VoidCallback onDropped;
  final VoidCallback onAbsent;
  final VoidCallback onWaiting;

  const _StudentAttendanceCard({
    required this.row,
    required this.onBoarded,
    required this.onDropped,
    required this.onAbsent,
    required this.onWaiting,
  });

  String get _status {
    return row.effectiveStatus.isEmpty ? 'waiting' : row.effectiveStatus;
  }

  Color get _cardColor {
    switch (_status) {
      case 'picked_up':
        return AppColors.statusBoardedBg;
      case 'dropped_off':
        return AppColors.statusDroppedBg;
      case 'absent':
        return AppColors.statusAbsentBg;
      case 'reported_absent':
        return AppColors.surfaceContainerLow;
      default:
        return AppColors.surface;
    }
  }

  Color get _cardBorder {
    switch (_status) {
      case 'picked_up':
        return AppColors.statusBoarded;
      case 'dropped_off':
        return AppColors.statusDropped;
      case 'absent':
        return AppColors.statusAbsent;
      case 'reported_absent':
        return AppColors.outline;
      default:
        return AppColors.outlineVariant;
    }
  }

  bool get _isWaiting {
    return _status == 'waiting';
  }

  bool get _isBoarded {
    return _status == 'picked_up';
  }

  bool get _isDropped {
    return _status == 'dropped_off';
  }

  bool get _isAbsent {
    return _status == 'absent';
  }

  bool get _isReportedAbsent {
    return _status == 'reported_absent';
  }

  bool get _canBoard {
    return _isWaiting && !_isReportedAbsent;
  }

  bool get _canDropOff {
    return _isBoarded && !_isReportedAbsent;
  }

  bool get _canMarkAbsent {
    return _isWaiting && !_isReportedAbsent;
  }

  bool get _canReturnToWaiting {
    return !_isWaiting && !_isReportedAbsent;
  }

  @override
  Widget build(BuildContext context) {
    final student = row.student;
    final label = AppConstants.attendanceStatusLabels[_status] ?? _status;
    final pictureUrl = student.pictureUrl;
    final hasPicture = pictureUrl != null && pictureUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: hasPicture ? NetworkImage(pictureUrl) : null,
                child: hasPicture
                    ? null
                    : Text(
                        student.firstName.isEmpty ? '?' : student.firstName[0],
                        style: GoogleFonts.heebo(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: GoogleFonts.heebo(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.address,
                      style: GoogleFonts.heebo(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'סטטוס נוכחי: $label',
                      style: GoogleFonts.heebo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isReportedAbsent)
            const _StatusBanner(
              icon: Icons.event_busy,
              label: 'ההורה דיווח שהילד לא מגיע היום',
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _canBoard ? onBoarded : null,
                        icon: const Icon(Icons.directions_bus),
                        label: const Text('עלה להסעה'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _canDropOff ? onDropped : null,
                        icon: const Icon(Icons.task_alt),
                        label: const Text('ירד ביעד'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _canMarkAbsent ? onAbsent : null,
                        icon: const Icon(Icons.person_off),
                        label: const Text('לא הגיע'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _canReturnToWaiting ? onWaiting : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('החזר לממתין'),
                      ),
                    ),
                  ],
                ),
                if (_isBoarded) ...[
                  const SizedBox(height: 12),
                  const _StatusBanner(
                    icon: Icons.directions_bus,
                    label: 'הילד נמצא בהסעה',
                  ),
                ],
                if (_isAbsent) ...[
                  const SizedBox(height: 12),
                  const _StatusBanner(
                    icon: Icons.person_off,
                    label: 'המלווה סימן שהילד לא הגיע',
                  ),
                ],
                if (_isDropped) ...[
                  const SizedBox(height: 12),
                  const _StatusBanner(
                    icon: Icons.task_alt,
                    label: 'הילד ירד ביעד',
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusBanner({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.heebo(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _EscortData {
  final RideRoute? route;
  final Ride? ride;
  final List<RouteStudentInfo> students;

  _EscortData({
    required this.route,
    required this.ride,
    required this.students,
  });

  factory _EscortData.empty() {
    return _EscortData(route: null, ride: null, students: const []);
  }
}
