import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/app_user.dart';
import '../../models/ride_route.dart';
import '../../models/route_student.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/child_widgets.dart';
import '../auth/login_screen.dart';

/// One pickup point (children living at the same address share a stop).
class _Stop {
  final LatLng point;
  final List<int> studentIds;
  int arrivalIndex;

  _Stop(this.point, this.studentIds) : arrivalIndex = 0;
}

class DriverDashboardScreen extends StatefulWidget {
  final AppUser user;

  const DriverDashboardScreen({super.key, required this.user});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  static const _tick = Duration(milliseconds: 160);
  static const double _stepMeters = 8;
  static const _distance = Distance();

  final MapController _mapController = MapController();

  RideRoute? _route;
  List<RouteStudentInfo> _rows = [];
  List<_Stop> _stops = [];
  List<LatLng> _path = [];
  LatLng _depot = const LatLng(31.2445, 34.7985);
  LatLng? _school;
  String _schoolName = 'בית הספר';

  int _pointIndex = 0;
  String _simState =
      'not_started'; // not_started/driving/waiting/paused/completed
  int? _selectedStudentId;

  bool _isLoading = true;
  String? _error;

  Timer? _pollTimer;
  Timer? _driveTimer;
  int _ticksSinceSync = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _driveTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ loading
  Future<void> _init() async {
    try {
      final routes = await ApiService.getRoutesForDriver(
        driverId: widget.user.id,
      );
      RideRoute? route;
      for (final r in routes) {
        if (await ApiService.getActiveRideForRoute(routeId: r.id) != null) {
          route = r;
          break;
        }
      }
      route ??= routes.isEmpty ? null : routes.first;
      if (route == null) {
        setState(() {
          _isLoading = false;
          _error = 'לא נמצא מסלול לנהג';
        });
        return;
      }
      _route = route;
      await _loadStatuses();
      await _loadGeometry();
      await _restoreProgress();
      if (!mounted) return;
      setState(() => _isLoading = false);
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
      if (_simState == 'driving') _startTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadStatuses() async {
    final route = _route;
    if (route == null) return;
    final rows = await ApiService.getRouteStudentAssignments(routeId: route.id);
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  Future<void> _loadGeometry() async {
    final route = _route;
    if (route == null) return;
    final optimized = await ApiService.getOptimizedRoute(
      userId: widget.user.id,
      role: widget.user.role,
      routeId: route.id,
    );

    final start = _lonLat(optimized['start_point']);
    if (start != null) _depot = start;
    _school = _lonLat(optimized['end_point']);
    final schoolName = optimized['school_name'];
    if (schoolName is String && schoolName.isNotEmpty) _schoolName = schoolName;

    // Stops in pickup order, grouping children at the same address.
    final stops = <_Stop>[];
    final rawStops = optimized['stops'];
    if (rawStops is List) {
      for (final s in rawStops) {
        if (s is! Map) continue;
        final id = s['student_id'];
        final lat = s['latitude'];
        final lon = s['longitude'];
        if (id is! int || lat is! num || lon is! num) continue;
        final p = LatLng(lat.toDouble(), lon.toDouble());
        if (stops.isNotEmpty &&
            _distance.as(LengthUnit.Meter, stops.last.point, p) < 5) {
          stops.last.studentIds.add(id);
        } else {
          stops.add(_Stop(p, [id]));
        }
      }
    }

    // Road legs: depot -> stop 1 -> ... -> school. Fallback: straight lines.
    final legs = <List<LatLng>>[];
    final rawLegs = optimized['legs'];
    if (rawLegs is List) {
      for (final leg in rawLegs) {
        if (leg is! List) continue;
        final pts = <LatLng>[];
        for (final c in leg) {
          final p = _lonLat(c);
          if (p != null) pts.add(p);
        }
        if (pts.length >= 2) legs.add(pts);
      }
    }
    final expectedLegs = stops.length + (_school == null ? 0 : 1);
    if (legs.length != expectedLegs) {
      legs.clear();
      final points = [_depot, ...stops.map((s) => s.point), ?_school];
      for (var i = 0; i + 1 < points.length; i++) {
        legs.add([points[i], points[i + 1]]);
      }
    }

    final path = <LatLng>[];
    for (var i = 0; i < legs.length; i++) {
      final dense = _densify(legs[i]);
      path.addAll(path.isEmpty ? dense : dense.skip(1));
      if (i < stops.length) stops[i].arrivalIndex = path.length - 1;
    }
    if (path.isEmpty) path.add(_depot);

    if (!mounted) return;
    setState(() {
      _stops = stops;
      _path = path;
      _pointIndex = _pointIndex.clamp(0, path.length - 1);
    });
  }

  Future<void> _restoreProgress() async {
    final route = _route;
    if (route == null) return;
    try {
      final progress = await ApiService.getRideProgress(routeId: route.id);
      final state = progress['sim_state'];
      final index = progress['progress_index'];
      if (state is String && index is int && index < _path.length) {
        if (state == 'driving' || state == 'waiting' || state == 'paused') {
          _pointIndex = index;
          _simState = state;
        } else if (state == 'completed') {
          _pointIndex = _path.length - 1;
          _simState = 'completed';
        }
      }
    } catch (_) {
      // Not available outside demo mode.
    }
  }

  static LatLng? _lonLat(dynamic value) {
    if (value is List &&
        value.length >= 2 &&
        value[0] is num &&
        value[1] is num) {
      return LatLng((value[1] as num).toDouble(), (value[0] as num).toDouble());
    }
    return null;
  }

  /// Adds points so the bus moves smoothly (one point every few meters).
  List<LatLng> _densify(List<LatLng> points) {
    final out = <LatLng>[points.first];
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i];
      final b = points[i + 1];
      final d = _distance.as(LengthUnit.Meter, a, b);
      final steps = (d / _stepMeters).ceil();
      for (var k = 1; k <= steps; k++) {
        final t = k / steps;
        out.add(
          LatLng(
            a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t,
          ),
        );
      }
    }
    return out;
  }

  // ------------------------------------------------------------ status
  String _statusOf(int studentId) {
    for (final r in _rows) {
      if (r.studentId == studentId) {
        return r.effectiveStatus.isEmpty ? 'waiting' : r.effectiveStatus;
      }
    }
    return 'waiting';
  }

  bool _isHandled(int studentId) => _statusOf(studentId) != 'waiting';

  RouteStudentInfo? _row(int studentId) {
    for (final r in _rows) {
      if (r.studentId == studentId) return r;
    }
    return null;
  }

  /// Index in [_stops] of the next stop not yet reached, or -1.
  int get _nextStopIndex {
    for (var i = 0; i < _stops.length; i++) {
      if (_stops[i].arrivalIndex > _pointIndex) return i;
      if (_stops[i].arrivalIndex == _pointIndex &&
          !_stops[i].studentIds.every(_isHandled)) {
        return i;
      }
    }
    return -1;
  }

  _Stop? get _stopHere {
    for (final s in _stops) {
      if (s.arrivalIndex == _pointIndex) return s;
    }
    return null;
  }

  Future<void> _poll() async {
    try {
      await _loadStatuses();
    } catch (_) {
      return;
    }
    if (_simState == 'waiting') {
      final stop = _stopHere;
      if (stop == null || stop.studentIds.every(_isHandled)) {
        setState(() => _simState = 'driving');
        _sync(force: true);
        _startTimer();
      }
    }
  }

  // ------------------------------------------------------------ driving
  void _startTimer() {
    _driveTimer?.cancel();
    _driveTimer = Timer.periodic(_tick, (_) => _step());
  }

  void _step() {
    if (!mounted || _simState != 'driving') {
      _driveTimer?.cancel();
      return;
    }
    if (_pointIndex >= _path.length - 1) {
      _driveTimer?.cancel();
      setState(() => _simState = 'completed');
      _sync(force: true);
      return;
    }
    setState(() => _pointIndex++);
    final stop = _stopHere;
    if (stop != null && !stop.studentIds.every(_isHandled)) {
      _driveTimer?.cancel();
      setState(() => _simState = 'waiting');
      _sync(force: true);
      return;
    }
    _sync();
  }

  void _start() {
    setState(() {
      if (_simState == 'completed' || _simState == 'not_started') {
        _pointIndex = 0;
      }
      _simState = 'driving';
    });
    _sync(force: true);
    _startTimer();
  }

  void _pause() {
    _driveTimer?.cancel();
    setState(() => _simState = 'paused');
    _sync(force: true);
  }

  Future<void> _restart() async {
    _driveTimer?.cancel();
    setState(() {
      _pointIndex = 0;
      _simState = 'not_started';
    });
    await _loadStatuses();
    await _loadGeometry();
    _sync(force: true);
  }

  /// Sends the bus position (about once a second, or right away).
  void _sync({bool force = false}) {
    _ticksSinceSync++;
    if (!force && _ticksSinceSync < 6) return;
    _ticksSinceSync = 0;
    final route = _route;
    if (route == null || _path.isEmpty) return;
    final p = _path[_pointIndex.clamp(0, _path.length - 1)];
    final stop = _stopHere;
    ApiService.updateRideProgress(
      routeId: route.id,
      latitude: p.latitude,
      longitude: p.longitude,
      progressIndex: _pointIndex,
      simState: _simState,
      waitingStudentIds: _simState == 'waiting' && stop != null
          ? stop.studentIds.where((id) => !_isHandled(id)).toList()
          : const [],
    ).catchError((Object error) {
      debugPrint('Location sync error: $error');
    });
  }

  // ------------------------------------------------------------ UI helpers
  void _select(int studentId) {
    final row = _row(studentId);
    if (row == null) return;
    setState(() => _selectedStudentId = studentId);
    _mapController.move(
      LatLng(row.student.latitude, row.student.longitude),
      17,
    );
  }

  String _minutesTo(int targetIndex) {
    if (targetIndex <= _pointIndex || _path.isEmpty) return '';
    final meters = (targetIndex - _pointIndex) * _stepMeters;
    final minutes = (meters / 330).ceil();
    return minutes <= 1 ? 'פחות מדקה' : '$minutes דק׳';
  }

  String _names(List<int> ids) =>
      ids.map((id) => _row(id)?.student.firstName ?? '').join(' ו');

  ({String title, String subtitle, Color color, IconData icon}) _banner() {
    final next = _nextStopIndex;
    switch (_simState) {
      case 'waiting':
        final stop = _stopHere;
        final waiting =
            stop?.studentIds.where((id) => !_isHandled(id)).toList() ?? [];
        return (
          title: 'הגענו לתחנה של ${_names(waiting)} – ממתינים לאישור המלווה',
          subtitle:
              'הנסיעה תמשיך לבד כשהמלווה תסמן במסך שלה שעלו להסעה. '
              'בדמו: פתחו לשונית נוספת, התחברו כמלווה (שרה) וסמנו "עלה".',
          color: const Color(0xFFE65100),
          icon: Icons.pan_tool_alt,
        );
      case 'driving':
        if (next == -1) {
          return (
            title: 'בדרך ל$_schoolName',
            subtitle: 'הגעה משוערת: ${_minutesTo(_path.length - 1)}',
            color: AppColors.primary,
            icon: Icons.directions_bus,
          );
        }
        return (
          title: 'בדרך לתחנה של ${_names(_stops[next].studentIds)}',
          subtitle: 'הגעה משוערת: ${_minutesTo(_stops[next].arrivalIndex)}',
          color: AppColors.primary,
          icon: Icons.directions_bus,
        );
      case 'paused':
        return (
          title: 'הנסיעה בהשהיה',
          subtitle: 'לחצו "המשך" כדי להמשיך',
          color: AppColors.outline,
          icon: Icons.pause_circle,
        );
      case 'completed':
        return (
          title: 'הגענו ל$_schoolName 🎉',
          subtitle: 'הנסיעה הסתיימה',
          color: AppColors.statusBoarded,
          icon: Icons.flag,
        );
    }
    return (
      title: '${_stops.length} תחנות איסוף היום',
      subtitle: 'לחצו "התחלת נסיעה" כדי לצאת לדרך',
      color: AppColors.primary,
      icon: Icons.route,
    );
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final busPos = _path.isEmpty
        ? _depot
        : _path[_pointIndex.clamp(0, _path.length - 1)];
    final banner = _banner();
    final orderedIds = [for (final s in _stops) ...s.studentIds];
    final notComing = _rows
        .where((r) => !orderedIds.contains(r.studentId))
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_route?.routeName ?? 'מסך נהג'),
          actions: [
            IconButton(
              tooltip: 'התנתקות',
              icon: const Icon(Icons.logout),
              onPressed: () {
                _driveTimer?.cancel();
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
        body: _error != null
            ? Center(child: Text(_error!))
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: banner.color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: banner.color.withValues(alpha: 0.6),
                        width: _simState == 'waiting' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(banner.icon, color: banner.color, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                banner.title,
                                style: GoogleFonts.heebo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: banner.color,
                                ),
                              ),
                              Text(
                                banner.subtitle,
                                style: GoogleFonts.heebo(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: _controls()),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 700;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: wide ? 230 : 92,
                              margin: const EdgeInsets.fromLTRB(8, 0, 16, 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.outlineVariant,
                                ),
                              ),
                              child: ListView(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                children: [
                                  for (var i = 0; i < _stops.length; i++)
                                    for (final id in _stops[i].studentIds)
                                      _stopTile(id, i + 1, wide),
                                  _schoolTile(wide),
                                  if (notComing.isNotEmpty && wide) ...[
                                    const Divider(),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'לא מגיעים היום',
                                        style: GoogleFonts.heebo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (notComing.isNotEmpty)
                                    for (final r in notComing)
                                      _stopTile(r.studentId, null, wide),
                                ],
                              ),
                            ),
                            Expanded(child: _map(busPos)),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _controls() {
    switch (_simState) {
      case 'driving':
        return [
          OutlinedButton.icon(
            style: compactOutlinedStyle(foreground: AppColors.primary),
            onPressed: _pause,
            icon: const Icon(Icons.pause, size: 18),
            label: const Text('השהיה'),
          ),
        ];
      case 'paused':
        return [
          ElevatedButton.icon(
            style: compactFilledStyle(),
            onPressed: _start,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('המשך'),
          ),
          TextButton(onPressed: _restart, child: const Text('מההתחלה')),
        ];
      case 'waiting':
        return [TextButton(onPressed: _restart, child: const Text('מההתחלה'))];
      case 'completed':
        return [
          ElevatedButton.icon(
            style: compactFilledStyle(),
            onPressed: _restart,
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('נסיעה חדשה'),
          ),
        ];
    }
    return [
      ElevatedButton.icon(
        style: compactFilledStyle(background: AppColors.statusBoarded),
        onPressed: _path.length < 2 ? null : _start,
        icon: const Icon(Icons.play_arrow, size: 18),
        label: const Text('התחלת נסיעה'),
      ),
    ];
  }

  Widget _stopTile(int studentId, int? stopNumber, bool wide) {
    final row = _row(studentId);
    if (row == null) return const SizedBox.shrink();
    final status = _statusOf(studentId);
    final selected = _selectedStudentId == studentId;
    final waitingHere =
        _simState == 'waiting' &&
        (_stopHere?.studentIds.contains(studentId) ?? false) &&
        !_isHandled(studentId);
    final style = StatusStyle.of(status);
    final ringColor = waitingHere
        ? const Color(0xFFE65100)
        : selected
        ? AppColors.primary
        : style.color;

    final avatar = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor,
          width: selected || waitingHere ? 3 : 2,
        ),
      ),
      child: Opacity(
        opacity: status == 'reported_absent' || status == 'absent' ? 0.5 : 1,
        child: ChildAvatar.of(row.student, size: wide ? 40 : 46),
      ),
    );

    return Material(
      color: selected ? AppColors.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: () => _select(studentId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: wide
              ? Row(
                  children: [
                    avatar,
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stopNumber == null ? '' : '$stopNumber. '}'
                            '${row.student.fullName}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.heebo(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          StatusPill(status: status),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    avatar,
                    const SizedBox(height: 2),
                    Text(
                      row.student.firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.heebo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: style.color,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _schoolTile(bool wide) {
    return InkWell(
      onTap: _school == null ? null : () => _mapController.move(_school!, 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: wide
            ? Row(
                children: [
                  const SizedBox(
                    width: 46,
                    child: Icon(
                      Icons.school,
                      color: AppColors.statusBoarded,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _schoolName,
                      style: GoogleFonts.heebo(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  const Icon(
                    Icons.school,
                    color: AppColors.statusBoarded,
                    size: 34,
                  ),
                  Text(
                    'יעד',
                    style: GoogleFonts.heebo(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _map(LatLng busPos) {
    final selectedRow = _selectedStudentId == null
        ? null
        : _row(_selectedStudentId!);
    final safeIndex = _pointIndex.clamp(
      0,
      _path.isEmpty ? 0 : _path.length - 1,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 0, 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: busPos,
              initialZoom: 15,
              onTap: (_, _) => setState(() => _selectedStudentId = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartride.app',
              ),
              PolylineLayer(
                polylines: [
                  if (_path.length >= 2 && safeIndex > 0)
                    Polyline(
                      points: _path.sublist(0, safeIndex + 1),
                      strokeWidth: 5,
                      color: Colors.blueGrey.withValues(alpha: 0.45),
                    ),
                  if (_path.length >= 2 && safeIndex < _path.length - 1)
                    Polyline(
                      points: _path.sublist(safeIndex),
                      strokeWidth: 5,
                      color: AppColors.primary,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (_school != null)
                    Marker(
                      point: _school!,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.school,
                        color: AppColors.statusBoarded,
                        size: 38,
                      ),
                    ),
                  for (final r in _rows) _studentMarker(r),
                  Marker(
                    point: busPos,
                    width: 46,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            child: FloatingActionButton.small(
              heroTag: 'center_bus',
              tooltip: 'מרכז על ההסעה',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              onPressed: () => _mapController.move(busPos, 16),
              child: const Icon(Icons.my_location),
            ),
          ),
          if (selectedRow != null)
            Positioned(
              right: 10,
              left: 10,
              bottom: 10,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          ChildAvatar.of(selectedRow.student, size: 48),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  selectedRow.student.fullName,
                                  style: GoogleFonts.heebo(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  selectedRow.student.address,
                                  style: GoogleFonts.heebo(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                if ((selectedRow.student.mobilityStatus ?? '')
                                        .isNotEmpty &&
                                    selectedRow.student.mobilityStatus !=
                                        'רגיל')
                                  Text(
                                    'ניידות: ${selectedRow.student.mobilityStatus}',
                                    style: GoogleFonts.heebo(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFE65100),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                StatusPill(
                                  status: _statusOf(selectedRow.studentId),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => showStudentDetailsSheet(
                              context,
                              student: selectedRow.student,
                              status: _statusOf(selectedRow.studentId),
                              messages: selectedRow.messages,
                            ),
                            child: const Text('פרטים'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Marker _studentMarker(RouteStudentInfo r) {
    final selected = _selectedStudentId == r.studentId;
    final status = _statusOf(r.studentId);
    final faded = status == 'reported_absent' || status == 'absent';
    final size = selected ? 58.0 : 40.0;
    final ring = selected ? const Color(0xFFE65100) : Colors.white;
    return Marker(
      point: LatLng(r.student.latitude, r.student.longitude),
      width: selected ? 130 : 48,
      height: selected ? 92 : 48,
      child: GestureDetector(
        onTap: () => _select(r.studentId),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ring,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Opacity(
                opacity: faded ? 0.45 : 1,
                child: ChildAvatar.of(r.student, size: size - 6),
              ),
            ),
            if (selected)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.heebo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
