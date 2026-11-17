import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/app_user.dart';
import '../../models/ride_route.dart';
import '../../models/student.dart';
import '../../services/api_service.dart';
import '../../services/mock_data_service.dart';
import '../../utils/app_colors.dart';
import '../auth/login_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  final AppUser user;

  const DriverDashboardScreen({super.key, required this.user});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _mockData = MockDataService();

  List<LatLng> _routePoints = [];
  List<Student> _students = [];
  RideRoute? _route;
  String _rideStatus = 'planned';
  int _currentPointIndex = 0;
  int _nextStopIndex = 0;

  // המילון שישמור את הסטטוסים החיים מבלי לגעת באובייקט הסטודנט!
  Map<int, String> _liveStatuses = {};

  bool _isWaitingForStudent = false;

  Timer? _pollingTimer;
  Timer? _driveTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _driveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final routes = await ApiService.getRoutesForDriver(driverId: widget.user.id);
      final route = routes.isEmpty ? null : routes.first;

      if (route == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final ride = await ApiService.getActiveRideForRoute(routeId: route.id);
      final students = await ApiService.getRouteStudents(routeId: route.id);

      // מושכים את הסטטוסים העדכניים ושומרים אותם במילון נפרד
      Map<int, String> fetchedStatuses = {};
      try {
        final assignments = await ApiService.getRouteStudentAssignments(routeId: route.id);
        for (var a in assignments) {
          if (a.effectiveStatus != null && a.effectiveStatus.toString().isNotEmpty) {
            fetchedStatuses[a.studentId as int] = a.effectiveStatus.toString();
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch live attendance: $e');
      }

      final optimizedRoute = await ApiService.getOptimizedRoute(
        userId: widget.user.id,
        role: widget.user.role,
        routeId: route.id,
      );

      final stops = optimizedRoute['stops'] as List<dynamic>? ?? [];
      final Map<int, int> orderMap = {};
      for (var stop in stops) {
        if (stop['student_id'] != null && stop['pickup_order'] != null) {
          orderMap[stop['student_id']] = stop['pickup_order'];
        }
      }

      students.sort((a, b) {
        final orderA = orderMap[a.id] ?? 999;
        final orderB = orderMap[b.id] ?? 999;
        return orderA.compareTo(orderB);
      });

      final geometry = optimizedRoute['geometry'];
      List<LatLng> newRoutePoints = _mockData.getSimulatedRoutePoints().map((p) => LatLng(p[0], p[1])).toList();

      if (geometry is List && geometry.isNotEmpty) {
        newRoutePoints = geometry.map<LatLng>((point) {
          final lon = (point as List)[0] as num;
          final lat = (point[1] as num);
          return LatLng(lat.toDouble(), lon.toDouble());
        }).toList();
      }

      if (mounted) {
        setState(() {
          _route = route;
          _students = students;
          _routePoints = newRoutePoints;
          _liveStatuses = fetchedStatuses; // עדכון המילון החי

          if (_rideStatus != 'active' && _rideStatus != 'completed') {
            _rideStatus = ride?.status ?? route.status ?? 'planned';
          }

          int oldNextStop = _nextStopIndex;
          _updateNextStopIndex();

          // שחרור הנסיעה אם התלמיד טופל
          if (_isWaitingForStudent && _rideStatus == 'active') {
            // אם מדד התחנה גדל, זה אומר שהתלמיד שחיכינו לו סומן (כנאסף או כנעדר)
            // ולכן המערכת קידמה את התור. זה הסימן שלנו לנסוע!
            if (_nextStopIndex > oldNextStop) {
              debugPrint("התור התקדם! משחרר נסיעה לתחנה הבאה.");
              _isWaitingForStudent = false;
              _moveNextWithRealSpeed(_route);
            }
          }

          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('DriverDashboard update error: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateNextStopIndex() {
    final index = _students.indexWhere((s) {
      // שימוש במילון החי
      final status = _liveStatuses[s.id] ?? s.effectiveStatus ?? '';
      return status != 'boarded' && 
             status != 'picked_up' && 
             status != 'absent' && 
             status != 'reported_absent';
    });

    _nextStopIndex = (index == -1) ? _students.length : index;
  }

  void _startRide(RideRoute? route) {
    setState(() {
      _rideStatus = 'active';
      _currentPointIndex = 0;
      _isWaitingForStudent = false;
    });

    _driveTimer?.cancel();
    _moveNextWithRealSpeed(route);
  }

  void _moveNextWithRealSpeed(RideRoute? route) {
    if (!mounted || _rideStatus != 'active') return;
    if (_currentPointIndex >= _routePoints.length - 1) {
      setState(() => _rideStatus = 'completed');
      return;
    }

    if (_nextStopIndex < _students.length) {
      final nextStudent = _students[_nextStopIndex];
      // שימוש במילון החי
      final status = (_liveStatuses[nextStudent.id] ?? nextStudent.effectiveStatus ?? '').toLowerCase();
      final isAlreadyBoarded = status == 'boarded' || status == 'picked_up' || status == 'בהסעה';

      final currentPos = _routePoints[_currentPointIndex];
      final distanceToStudent = const Distance().as(
        LengthUnit.Meter,
        currentPos,
        LatLng(nextStudent.latitude, nextStudent.longitude),
      );

      if (distanceToStudent < 50 && !isAlreadyBoarded && !_isWaitingForStudent) {
        setState(() {
          _isWaitingForStudent = true;
        });
        debugPrint("הגענו לתחנה, עוצר וממתין ל: ${nextStudent.fullName}");
        return; 
      }
    }

    final p1 = _routePoints[_currentPointIndex];
    final p2 = _routePoints[_currentPointIndex + 1];

    final distanceInMeters = const Distance().as(LengthUnit.Meter, p1, p2);
    const double speedMetersPerSecond = 50.0; 

    final double durationInSeconds = distanceInMeters / speedMetersPerSecond;
    final int durationInMs = (durationInSeconds * 1000).round();

    _driveTimer?.cancel();
    _driveTimer = Timer(Duration(milliseconds: durationInMs.clamp(10, 2000)), () async {
      if (!mounted) return;

      setState(() {
        _currentPointIndex++;
      });

      final currentPos = _routePoints[_currentPointIndex];

      if (route != null) {
        try {
          await ApiService.updateRouteLocation(
            userId: widget.user.id,
            role: widget.user.role,
            routeId: route.id,
            latitude: currentPos.latitude,
            longitude: currentPos.longitude,
          );
        } catch (error) {
          debugPrint('Location sync error: $error');
        }
      }

      _moveNextWithRealSpeed(route);
    });
  }

  String _calculateETA(LatLng currentPos, LatLng destination) {
    final distanceInMeters = const Distance().as(LengthUnit.Meter, currentPos, destination);
    final timeInMinutes = (distanceInMeters / 833.33).ceil();

    if (timeInMinutes <= 1) return "פחות מדקה";
    return "עוד $timeInMinutes דק'";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _routePoints.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentPos = _routePoints.isNotEmpty
        ? _routePoints[_currentPointIndex.clamp(0, _routePoints.length - 1)]
        : const LatLng(31.249, 34.79);

    String etaText = "";
    if (_rideStatus == 'active' && !_isWaitingForStudent) {
      if (_nextStopIndex < _students.length) {
        final nextStudent = _students[_nextStopIndex];
        etaText = " (${_calculateETA(currentPos, LatLng(nextStudent.latitude, nextStudent.longitude))})";
      } else if (_routePoints.isNotEmpty) {
        etaText = " (${_calculateETA(currentPos, _routePoints.last)})";
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Driver dashboard'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: () {
                ApiService.logout();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ElevatedButton.icon(
                onPressed: () => _startRide(_route),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Start'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isWaitingForStudent ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isWaitingForStudent ? AppColors.primary : AppColors.outlineVariant,
                  width: _isWaitingForStudent ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isWaitingForStudent ? Icons.pan_tool : Icons.directions_bus,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_route?.routeName ?? 'No route', style: GoogleFonts.heebo(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                          _rideStatus == 'active'
                              ? (_isWaitingForStudent
                                  ? 'ממתין לאישור מלווה עבור: ${_students[_nextStopIndex].fullName}'
                                  : 'Next stop: ${_nextStopIndex < _students.length ? _students[_nextStopIndex].fullName : "School"}$etaText')
                              : '${_students.length} students',
                          style: GoogleFonts.heebo(
                            fontSize: 14,
                            color: _isWaitingForStudent ? AppColors.primary : AppColors.onSurfaceVariant,
                            fontWeight: _isWaitingForStudent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 104,
                    margin: const EdgeInsets.only(right: 16, left: 8, bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: _students.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _students.length) {
                          return _stopChip('School', Icons.school, index <= _nextStopIndex && _rideStatus == 'active', null, false, false);
                        }

                        final student = _students[index];
                        // קריאת הסטטוס מהמילון החי!
                        final status = _liveStatuses[student.id] ?? student.effectiveStatus ?? '';
                        
                        final bool isAbsent = status == 'reported_absent' || status == 'absent';
                        final bool isBoarded = status == 'boarded' || status == 'picked_up';
                        final bool isCurrentTarget = (_isWaitingForStudent && index == _nextStopIndex);

                        return _stopChip(
                          student.fullName,
                          Icons.person,
                          isBoarded,
                          student.pictureUrl,
                          isAbsent,
                          isCurrentTarget,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 16, right: 8, bottom: 16),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: FlutterMap(
                        options: MapOptions(initialCenter: currentPos, initialZoom: 14.5),
                        children: [
                          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.smartride.app'),
                          PolylineLayer(polylines: [
                            if (_currentPointIndex > 0 && _routePoints.isNotEmpty)
                              Polyline(
                                points: _routePoints.sublist(0, _currentPointIndex + 1),
                                strokeWidth: 4,
                                color: Colors.blueAccent.withValues(alpha: 0.35),
                              ),
                            if (_routePoints.isNotEmpty)
                              Polyline(
                                points: _routePoints.sublist(_currentPointIndex.clamp(0, _routePoints.length - 1)),
                                strokeWidth: 5,
                                color: Colors.blue.shade900,
                              ),
                          ]),
                          MarkerLayer(markers: [
                            Marker(point: currentPos, width: 44, height: 44, child: const Icon(Icons.directions_bus, color: AppColors.primary, size: 36)),
                            ..._students.map((s) => Marker(
                                  point: LatLng(s.latitude, s.longitude),
                                  width: 36,
                                  height: 36,
                                  child: Tooltip(message: s.fullName, child: const Icon(Icons.location_on, color: AppColors.error, size: 32)),
                                )),
                            Marker(point: _routePoints.isNotEmpty ? _routePoints.last : currentPos, width: 36, height: 36, child: const Icon(Icons.school, color: AppColors.statusBoarded, size: 32)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stopChip(String name, IconData icon, bool done, String? imageUrl, bool isAbsent, bool isCurrentTarget) {
    Color arcColor;
    if (done) {
      arcColor = Colors.grey.shade400;
    } else if (isAbsent) {
      arcColor = AppColors.error;
    } else if (isCurrentTarget) {
      arcColor = Colors.orange;
    } else {
      arcColor = AppColors.statusBoarded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: arcColor, width: isCurrentTarget ? 4 : 3),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: isCurrentTarget ? Colors.orange.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
              child: (imageUrl == null || imageUrl.isEmpty) ? Icon(icon, color: AppColors.primary, size: 26) : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.heebo(
              fontSize: 11,
              fontWeight: done || isCurrentTarget ? FontWeight.bold : FontWeight.normal,
              color: done ? Colors.grey : (isAbsent ? AppColors.error : (isCurrentTarget ? Colors.orange : AppColors.onSurface)),
            ),
          ),
        ],
      ),
    );
  }
}