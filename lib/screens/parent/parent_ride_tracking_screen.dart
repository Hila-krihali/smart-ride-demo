import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/app_user.dart';
import '../../models/student.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/child_widgets.dart';

/// Live map: where the bus is, the child's home and the school.
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
  final MapController _mapController = MapController();
  Timer? _timer;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getChildTracking(
        studentId: widget.student.id,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'לא הצלחנו לטעון את מיקום ההסעה';
      });
    }
  }

  static LatLng? _point(dynamic value) {
    if (value is! Map) return null;
    final lat = value['latitude'];
    final lon = value['longitude'];
    if (lat is! num || lon is! num) return null;
    return LatLng(lat.toDouble(), lon.toDouble());
  }

  String _headline() {
    final data = _data;
    final name = widget.student.firstName;
    if (data == null) return 'טוען...';
    final status = data['effective_status'];
    if (status == 'reported_absent') {
      return 'דיווחת ש$name לא מגיע/ה היום';
    }
    if (data['has_ride'] != true) {
      return 'אין היום הסעה פעילה עבור $name';
    }
    if (status == 'dropped_off') {
      return '$name הגיע/ה ליעד בשלום ✅';
    }
    if (data['ride_started'] != true) {
      return 'ההסעה עוד לא יצאה לדרך';
    }
    final eta = data['eta_minutes'];
    final etaText = eta is num
        ? (eta <= 1 ? 'פחות מדקה' : '${eta.toInt()} דקות')
        : '';
    if (status == 'picked_up') {
      return etaText.isEmpty
          ? '$name בהסעה, בדרך ליעד'
          : '$name בהסעה · הגעה משוערת ליעד: $etaText';
    }
    if (data['sim_state'] == 'waiting') {
      return 'ההסעה עומדת בתחנה ותמשיך בקרוב';
    }
    return etaText.isEmpty
        ? 'ההסעה בדרך אליכם'
        : 'זמן הגעה משוער הביתה: $etaText';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final home =
        _point(data?['home']) ??
        LatLng(widget.student.latitude, widget.student.longitude);
    final bus = _point(data?['bus']);
    final school = _point(data?['school']);
    final schoolData = data?['school'];
    final schoolName = schoolData is Map
        ? schoolData['name']?.toString()
        : null;
    final started = data?['ride_started'] == true;
    final routeName = data?['route_name']?.toString();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('איפה ההסעה של ${widget.student.firstName}?'),
        ),
        body: Column(
          children: [
            PageWidth(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    ChildAvatar.of(widget.student, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _headline(),
                            style: GoogleFonts.heebo(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          if (routeName != null)
                            Text(
                              routeName,
                              style: GoogleFonts.heebo(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          if (!started && data?['has_ride'] == true)
                            Text(
                              'בדמו: התחברו כנהג ולחצו "התחלת נסיעה" – '
                              'ההסעה תופיע כאן ותזוז במפה.',
                              style: GoogleFonts.heebo(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          if (_error != null)
                            Text(
                              _error!,
                              style: GoogleFonts.heebo(
                                fontSize: 13,
                                color: AppColors.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (bus != null)
                      IconButton(
                        tooltip: 'הצג את ההסעה',
                        icon: const Icon(Icons.my_location),
                        onPressed: () => _mapController.move(bus, 16),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: home, initialZoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.smartride.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (school != null)
                          Marker(
                            point: school,
                            width: 120,
                            height: 56,
                            child: _MapLabel(
                              icon: Icons.school,
                              color: AppColors.statusBoarded,
                              text: schoolName ?? 'בית הספר',
                            ),
                          ),
                        Marker(
                          point: home,
                          width: 120,
                          height: 66,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: ChildAvatar.of(widget.student, size: 38),
                              ),
                              const _LabelChip(text: 'הבית'),
                            ],
                          ),
                        ),
                        if (bus != null)
                          Marker(
                            point: bus,
                            width: 48,
                            height: 48,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _MapLabel({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 30),
        _LabelChip(text: text),
      ],
    );
  }
}

class _LabelChip extends StatelessWidget {
  final String text;

  const _LabelChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.heebo(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
