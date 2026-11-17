import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_user.dart';
import '../../models/ride.dart';
import '../../models/ride_route.dart';
import '../../models/route_student.dart';
import '../../models/student_message.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/child_widgets.dart';
import '../auth/login_screen.dart';

class EscortDashboardScreen extends StatefulWidget {
  final AppUser user;

  const EscortDashboardScreen({super.key, required this.user});

  @override
  State<EscortDashboardScreen> createState() => _EscortDashboardScreenState();
}

class _EscortDashboardScreenState extends State<EscortDashboardScreen> {
  Timer? _pollingTimer;

  _EscortData _data = _EscortData.empty();
  bool _isInitialLoading = true;
  String? _loadError;
  final Set<int> _busyStudentIds = {};

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<_EscortData> _fetch() async {
    final routes = await ApiService.getRoutesForEscort(
      escortId: widget.user.id,
    );
    if (routes.isEmpty) {
      return _EscortData.empty();
    }
    // Prefer the route that has a ride today.
    RideRoute route = routes.first;
    Ride? ride;
    for (final r in routes) {
      final active = await ApiService.getActiveRideForRoute(routeId: r.id);
      if (active != null) {
        route = r;
        ride = active;
        break;
      }
    }
    final students = await ApiService.getRouteStudentAssignments(
      routeId: route.id,
    );

    List<StudentMessage> messages = const [];
    Map<String, dynamic> progress = const {};
    try {
      messages = await ApiService.getRouteMessages(routeId: route.id);
      progress = await ApiService.getRideProgress(routeId: route.id);
    } catch (error) {
      // Only available in demo mode; the dashboard works without it.
      debugPrint('Escort extras unavailable: $error');
    }

    return _EscortData(
      route: route,
      ride: ride,
      students: students,
      messages: messages,
      progress: progress,
    );
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final loaded = await _fetch();
      if (!mounted) return;
      setState(() {
        _data = loaded;
        _loadError = null;
        _isInitialLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (initial)
          _loadError = error.toString().replaceFirst('Exception: ', '');
        _isInitialLoading = false;
      });
    }
  }

  String _statusOf(RouteStudentInfo row) =>
      row.effectiveStatus.isEmpty ? 'waiting' : row.effectiveStatus;

  bool _isNotComing(RouteStudentInfo row) {
    final status = _statusOf(row);
    return status == 'reported_absent' || status == 'absent';
  }

  Future<void> _updateStatus(RouteStudentInfo row, String status) async {
    final ride = _data.ride;
    if (ride == null) {
      _snack('אין היום נסיעה פעילה במסלול הזה');
      return;
    }
    setState(() => _busyStudentIds.add(row.studentId));
    try {
      await ApiService.updateAttendanceStatus(
        userId: widget.user.id,
        role: widget.user.role,
        rideId: ride.id,
        studentId: row.student.id,
        status: status,
      );
      final label = AppConstants.attendanceStatusLabels[status] ?? status;
      _snack('${row.student.firstName}: $label');
      await _load();
    } catch (error) {
      _snack(
        'העדכון נכשל: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _busyStudentIds.remove(row.studentId));
    }
  }

  Future<void> _sendMessage(int studentId, String text) async {
    try {
      await ApiService.sendStudentMessage(studentId: studentId, text: text);
      _snack('ההודעה נשלחה');
      await _load();
    } catch (error) {
      _snack('שליחת ההודעה נכשלה');
    }
  }

  Future<void> _composeGeneralMessage() async {
    final rows = _data.students;
    if (rows.isEmpty) return;
    int selected = rows.first.studentId;
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setLocal) {
              return AlertDialog(
                title: Text(
                  'הודעה חדשה',
                  style: GoogleFonts.heebo(fontWeight: FontWeight.w800),
                ),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selected,
                        decoration: const InputDecoration(
                          labelText: 'על איזה ילד/ה?',
                        ),
                        items: [
                          for (final r in rows)
                            DropdownMenuItem(
                              value: r.studentId,
                              child: Text(r.student.fullName),
                            ),
                        ],
                        onChanged: (v) =>
                            setLocal(() => selected = v ?? selected),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: 'לדוגמה: עלתה בלי כובע, ההורים עודכנו',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('ביטול'),
                  ),
                  ElevatedButton(
                    style: compactFilledStyle(),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('שליחה'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    final text = controller.text.trim();
    controller.dispose();
    if (result == true && text.isNotEmpty) {
      await _sendMessage(selected, text);
    }
  }

  void _openDetails(RouteStudentInfo row) {
    showStudentDetailsSheet(
      context,
      student: row.student,
      status: _statusOf(row),
      absenceMessage: _statusOf(row) == 'reported_absent'
          ? row.absenceMessage
          : null,
      absenceReportedBy: _statusOf(row) == 'reported_absent'
          ? row.absenceReportedBy
          : null,
      messages: row.messages,
      onSendMessage: (text) => _sendMessage(row.studentId, text),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          width: 420,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final students = _data.students;
    final coming = students.where((r) => !_isNotComing(r)).toList();
    final notComing = students.where(_isNotComing).toList();
    final onBoard = coming.where((r) => _statusOf(r) == 'picked_up').length;
    final arrived = coming.where((r) => _statusOf(r) == 'dropped_off').length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_data.route?.routeName ?? 'מסך מלווה'),
          actions: [
            IconButton(
              tooltip: 'רענון',
              icon: const Icon(Icons.refresh),
              onPressed: _load,
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
        body: _isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : PageWidth(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      if (_loadError != null)
                        Text(
                          _loadError!,
                          style: GoogleFonts.heebo(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Text(
                        'שלום ${widget.user.firstName} 👋',
                        style: GoogleFonts.heebo(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        _data.ride == null
                            ? 'אין היום נסיעה פעילה במסלול הזה'
                            : 'נסיעת היום · ${_directionLabel(_data.route?.direction)}',
                        style: GoogleFonts.heebo(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatTile(
                            label: 'מגיעים היום',
                            value: '${coming.length}',
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          _StatTile(
                            label: 'בהסעה',
                            value: '$onBoard',
                            color: AppColors.statusBoarded,
                          ),
                          const SizedBox(width: 8),
                          _StatTile(
                            label: 'הגיעו ליעד',
                            value: '$arrived',
                            color: AppColors.statusDropped,
                          ),
                          const SizedBox(width: 8),
                          _StatTile(
                            label: 'לא מגיעים',
                            value: '${notComing.length}',
                            color: AppColors.statusAbsent,
                          ),
                        ],
                      ),
                      _DriverBanner(
                        progress: _data.progress,
                        students: students,
                      ),
                      if (notComing.isNotEmpty) ...[
                        const SectionTitle('לא מגיעים היום'),
                        ...notComing.map(
                          (row) => _NotComingCard(
                            row: row,
                            status: _statusOf(row),
                            onTap: () => _openDetails(row),
                            onUndo: _statusOf(row) == 'absent'
                                ? () => _updateStatus(row, 'waiting')
                                : null,
                          ),
                        ),
                      ],
                      SectionTitle('רשימת איסוף (${coming.length})'),
                      if (coming.isEmpty)
                        Text(
                          'אין ילדים שמגיעים היום',
                          style: GoogleFonts.heebo(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ...coming.map(
                        (row) => _PickupCard(
                          row: row,
                          status: _statusOf(row),
                          isBusy: _busyStudentIds.contains(row.studentId),
                          isDriverWaiting: _isDriverWaitingFor(row.studentId),
                          onTap: () => _openDetails(row),
                          onSetStatus: (status) => _updateStatus(row, status),
                        ),
                      ),
                      SectionTitle(
                        'הודעות היום',
                        trailing: OutlinedButton.icon(
                          style: compactOutlinedStyle(
                            foreground: AppColors.primary,
                          ),
                          onPressed: students.isEmpty
                              ? null
                              : _composeGeneralMessage,
                          icon: const Icon(
                            Icons.add_comment_outlined,
                            size: 18,
                          ),
                          label: const Text('הודעה חדשה'),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: _data.messages.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text(
                                  'אין הודעות היום',
                                  style: GoogleFonts.heebo(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  for (final m in _data.messages.take(8))
                                    MessageTile(message: m),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  bool _isDriverWaitingFor(int studentId) {
    if (_data.progress['sim_state'] != 'waiting') return false;
    final ids = _data.progress['waiting_student_ids'];
    return ids is List && ids.contains(studentId);
  }

  static String _directionLabel(String? direction) {
    switch (direction) {
      case 'morning':
        return 'הסעת בוקר (מהבית לבית הספר)';
      case 'afternoon':
        return 'הסעת צהריים (מבית הספר הביתה)';
    }
    return '';
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.heebo(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.heebo(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows where the driver is (demo simulation).
class _DriverBanner extends StatelessWidget {
  final Map<String, dynamic> progress;
  final List<RouteStudentInfo> students;

  const _DriverBanner({required this.progress, required this.students});

  @override
  Widget build(BuildContext context) {
    final state = progress['sim_state'];
    String? text;
    IconData icon = Icons.directions_bus;
    Color color = AppColors.primary;
    if (state == 'driving') {
      text = 'ההסעה בדרך לתחנה הבאה';
    } else if (state == 'waiting') {
      final ids = progress['waiting_student_ids'];
      final names = students
          .where((r) => ids is List && ids.contains(r.studentId))
          .map((r) => r.student.firstName)
          .join(' ו');
      text = 'הנהג עומד בתחנה של $names – סמני שעלו להסעה כדי שימשיך';
      icon = Icons.pan_tool_alt;
      color = const Color(0xFFE65100);
    } else if (state == 'completed') {
      text = 'ההסעה הגיעה ליעד';
      icon = Icons.flag;
      color = AppColors.statusBoarded;
    }
    if (text == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.heebo(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  final RouteStudentInfo row;
  final String status;
  final bool isBusy;
  final bool isDriverWaiting;
  final VoidCallback onTap;
  final void Function(String status) onSetStatus;

  const _PickupCard({
    required this.row,
    required this.status,
    required this.isBusy,
    required this.isDriverWaiting,
    required this.onTap,
    required this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    final student = row.student;
    final age = student.age;
    final style = StatusStyle.of(status);
    final hasAlert = _hasMedicalAlert(row);

    final actions = <Widget>[];
    if (isBusy) {
      actions.add(
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (status == 'waiting') {
      actions.addAll([
        ElevatedButton.icon(
          style: compactFilledStyle(background: AppColors.statusBoarded),
          onPressed: () => onSetStatus('picked_up'),
          icon: const Icon(Icons.directions_bus, size: 18),
          label: const Text('עלה'),
        ),
        OutlinedButton(
          style: compactOutlinedStyle(foreground: AppColors.statusAbsent),
          onPressed: () => onSetStatus('absent'),
          child: const Text('לא היה בתחנה'),
        ),
      ]);
    } else if (status == 'picked_up') {
      actions.addAll([
        ElevatedButton.icon(
          style: compactFilledStyle(background: AppColors.statusDropped),
          onPressed: () => onSetStatus('dropped_off'),
          icon: const Icon(Icons.task_alt, size: 18),
          label: const Text('ירד ביעד'),
        ),
        TextButton(
          onPressed: () => onSetStatus('waiting'),
          child: const Text('בטל סימון'),
        ),
      ]);
    } else {
      actions.add(
        TextButton(
          onPressed: () => onSetStatus('waiting'),
          child: const Text('בטל סימון'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: status == 'waiting' ? AppColors.surface : style.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDriverWaiting
              ? const Color(0xFFE65100)
              : style.color.withValues(alpha: 0.35),
          width: isDriverWaiting ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 520;
              final info = Row(
                children: [
                  ChildAvatar.of(student, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                student.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.heebo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (age != null)
                              Text(
                                ' · בן/בת $age',
                                style: GoogleFonts.heebo(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            if (hasAlert) ...[
                              const SizedBox(width: 6),
                              const Tooltip(
                                message:
                                    'יש מידע רפואי / אלרגיה – פתחי את הפרטים',
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: AppColors.statusAbsent,
                                ),
                              ),
                            ],
                            if (row.messages.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: '${row.messages.length} הודעות היום',
                                child: const Icon(
                                  Icons.mark_chat_unread_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          student.address,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.heebo(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(child: StatusPill(status: status)),
                            if (isDriverWaiting) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'הנהג מחכה בתחנה',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.heebo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFE65100),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final buttons = Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: buttons,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 8),
                  buttons,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _hasMedicalAlert(RouteStudentInfo row) {
  final s = row.student;
  return _filled(s.allergies) || _filled(s.medicalInfo);
}

bool _filled(String? v) {
  final t = v?.trim() ?? '';
  return t.isNotEmpty && t != 'אין';
}

class _NotComingCard extends StatelessWidget {
  final RouteStudentInfo row;
  final String status;
  final VoidCallback onTap;
  final VoidCallback? onUndo;

  const _NotComingCard({
    required this.row,
    required this.status,
    required this.onTap,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final student = row.student;
    final String reason;
    if (status == 'reported_absent') {
      final by = row.absenceReportedBy;
      final msg = (row.absenceMessage ?? '').trim();
      reason =
          '${by == null ? 'ההורה' : by} דיווח/ה שלא יגיע'
          '${msg.isEmpty ? '' : ': "$msg"'}';
    } else {
      reason = 'סימנת שלא היה/תה בתחנה';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Opacity(opacity: 0.6, child: ChildAvatar.of(student, size: 44)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: GoogleFonts.heebo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      reason,
                      style: GoogleFonts.heebo(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onUndo != null)
                TextButton(onPressed: onUndo, child: const Text('בטל סימון')),
            ],
          ),
        ),
      ),
    );
  }
}

class _EscortData {
  final RideRoute? route;
  final Ride? ride;
  final List<RouteStudentInfo> students;
  final List<StudentMessage> messages;
  final Map<String, dynamic> progress;

  _EscortData({
    required this.route,
    required this.ride,
    required this.students,
    this.messages = const [],
    this.progress = const {},
  });

  factory _EscortData.empty() {
    return _EscortData(route: null, ride: null, students: const []);
  }
}
