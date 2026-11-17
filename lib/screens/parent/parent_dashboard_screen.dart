import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../models/student.dart';
import '../../models/student_message.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/child_widgets.dart';
import '../auth/login_screen.dart';
import 'parent_absence_report_screen.dart';
import 'parent_child_details_screen.dart';
import 'parent_ride_tracking_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  final AppUser user;

  const ParentDashboardScreen({super.key, required this.user});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final Map<int, String> _lastKnownStatuses = {};

  Timer? _statusPollingTimer;

  List<Student> _children = [];
  List<StudentMessage> _messages = [];
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _didLoadInitialStatuses = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    _loadInitialChildren();

    _statusPollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshChildrenSilently(),
    );
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    super.dispose();
  }

  Future<List<Student>> _fetchChildren() async {
    final children = await ApiService.getParentChildren(
      parentId: widget.user.id,
    );
    try {
      final messages = await ApiService.getParentMessages();
      if (mounted) {
        final changed =
            messages.length != _messages.length ||
            (messages.isNotEmpty &&
                _messages.isNotEmpty &&
                messages.first.id != _messages.first.id);
        if (changed) setState(() => _messages = messages);
      }
    } catch (error) {
      // Messages exist only in demo mode.
      debugPrint('Parent messages unavailable: $error');
    }
    return children;
  }

  Future<void> _openDetails(Student child) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ParentChildDetailsScreen(student: child),
      ),
    );
    if (changed == true) {
      await _refreshChildren();
    }
  }

  Future<void> _messageEscort(Student child) async {
    final text = await showMessageComposer(
      context,
      title: 'הודעה למלווה על ${child.firstName}',
      hint: 'לדוגמה: היום יוצא 10 דקות מאוחר יותר',
    );
    if (text == null) return;
    try {
      await ApiService.sendStudentMessage(studentId: child.id, text: text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ההודעה נשלחה למלווה')));
      await _refreshChildren();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('שליחת ההודעה נכשלה')));
    }
  }

  Future<void> _loadInitialChildren() async {
    setState(() {
      _isInitialLoading = true;
      _loadError = null;
    });

    try {
      final children = await _fetchChildren();

      if (!mounted) {
        return;
      }

      _checkForLiveStatusChanges(children, showNotifications: false);

      setState(() {
        _children = children;
        _isInitialLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error.toString().replaceFirst('Exception: ', '');
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _refreshChildren() async {
    setState(() {
      _isRefreshing = true;
      _loadError = null;
    });

    try {
      final children = await _fetchChildren();

      if (!mounted) {
        return;
      }

      _checkForLiveStatusChanges(children, showNotifications: false);

      setState(() {
        _children = children;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error.toString().replaceFirst('Exception: ', '');
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshChildrenSilently() async {
    if (!mounted || _isRefreshing || _isInitialLoading) {
      return;
    }

    try {
      final children = await _fetchChildren();

      if (!mounted) {
        return;
      }

      final hasVisualChange = _hasChildrenVisualChange(children);

      _checkForLiveStatusChanges(children, showNotifications: true);

      if (hasVisualChange) {
        setState(() {
          _children = children;
        });
      }
    } catch (error) {
      debugPrint('ParentDashboard silent refresh failed: $error');
    }
  }

  bool _hasChildrenVisualChange(List<Student> newChildren) {
    if (newChildren.length != _children.length) {
      return true;
    }

    final oldById = {for (final child in _children) child.id: child};

    for (final newChild in newChildren) {
      final oldChild = oldById[newChild.id];

      if (oldChild == null) {
        return true;
      }

      final oldStatus = _statusOf(oldChild);
      final newStatus = _statusOf(newChild);

      if (oldStatus != newStatus) {
        return true;
      }

      if (oldChild.reportedAbsentToday != newChild.reportedAbsentToday) {
        return true;
      }

      if (oldChild.attendanceStatus != newChild.attendanceStatus) {
        return true;
      }

      if (oldChild.rideStudentStatus != newChild.rideStudentStatus) {
        return true;
      }

      if (oldChild.pictureUrl != newChild.pictureUrl) {
        return true;
      }

      if (oldChild.activeRideId != newChild.activeRideId) {
        return true;
      }
    }

    return false;
  }

  String _statusOf(Student child) {
    final effectiveStatus = child.effectiveStatus?.trim();
    final attendanceStatus = child.attendanceStatus?.trim();
    final rideStudentStatus = child.rideStudentStatus?.trim();

    if (effectiveStatus != null &&
        effectiveStatus.isNotEmpty &&
        effectiveStatus != 'planned') {
      return effectiveStatus;
    }

    if (attendanceStatus != null && attendanceStatus.isNotEmpty) {
      return attendanceStatus;
    }

    if (rideStudentStatus != null && rideStudentStatus.isNotEmpty) {
      return rideStudentStatus;
    }

    if (child.reportedAbsentToday) {
      return 'reported_absent';
    }

    return 'waiting';
  }

  void _checkForLiveStatusChanges(
    List<Student> children, {
    required bool showNotifications,
  }) {
    for (final child in children) {
      final currentStatus = _statusOf(child);
      final previousStatus = _lastKnownStatuses[child.id];

      if (showNotifications &&
          _didLoadInitialStatuses &&
          previousStatus != null &&
          previousStatus != currentStatus) {
        _showParentStatusPopup(child: child, newStatus: currentStatus);
      }

      _lastKnownStatuses[child.id] = currentStatus;
    }

    _didLoadInitialStatuses = true;
  }

  Future<void> _playNotificationSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (error) {
      debugPrint('Could not play notification sound: $error');
    }
  }

  void _showParentStatusPopup({
    required Student child,
    required String newStatus,
  }) {
    String? message;

    if (newStatus == 'picked_up') {
      message = '${child.fullName} עלה/עלתה להסעה';
    } else if (newStatus == 'dropped_off') {
      message = '${child.fullName} ירד/ירדה ביעד';
    } else if (newStatus == 'reported_absent' || newStatus == 'absent') {
      message = '${child.fullName} סומן/סומנה כלא מגיע/ה היום';
    } else if (newStatus == 'waiting') {
      message = '${child.fullName} מסומן/מסומנת כמגיע/ה להסעה';
    }

    if (message == null || !mounted) {
      return;
    }

    _playNotificationSound();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.heebo(fontWeight: FontWeight.w700),
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openAbsenceReport(Student child) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ParentAbsenceReportScreen(user: widget.user, student: child),
      ),
    );

    if (changed == true) {
      await _refreshChildren();
    }
  }

  List<Map<String, dynamic>> _dedupeEscorts(
    List<Map<String, dynamic>> escorts,
  ) {
    final Map<String, Map<String, dynamic>> byEscortAndStudent = {};

    for (final escort in escorts) {
      final escortId = (escort['escort_id'] ?? '').toString();
      final studentId = (escort['student_id'] ?? '').toString();

      final key = '$escortId-$studentId';

      if (!byEscortAndStudent.containsKey(key)) {
        byEscortAndStudent[key] = Map<String, dynamic>.from(escort);
        continue;
      }

      final existing = byEscortAndStudent[key]!;
      final existingRouteName = (existing['route_name'] ?? '').toString();
      final newRouteName = (escort['route_name'] ?? '').toString();

      if (newRouteName.isNotEmpty &&
          !existingRouteName.contains(newRouteName)) {
        existing['route_name'] = existingRouteName.isEmpty
            ? newRouteName
            : '$existingRouteName / $newRouteName';
      }
    }

    return byEscortAndStudent.values.toList();
  }

  Future<void> _openEscortsDialog() async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ApiService.getParentEscorts(parentId: widget.user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final escorts = _dedupeEscorts(snapshot.data ?? []);

              if (escorts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'לא נמצאו מלווים לילדים שלך',
                    style: GoogleFonts.heebo(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              return SafeArea(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: escorts.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final escort = escorts[index];

                    final firstName = (escort['first_name'] ?? '').toString();
                    final lastName = (escort['last_name'] ?? '').toString();
                    final phone = (escort['phone_number'] ?? '').toString();
                    final studentName = (escort['student_name'] ?? '')
                        .toString();
                    final routeName = (escort['route_name'] ?? '').toString();

                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.support_agent),
                      ),
                      title: Text(
                        '$firstName $lastName',
                        style: GoogleFonts.heebo(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'טלפון: ${phone.isEmpty ? "לא קיים" : phone}\n'
                        'ילד/ה: $studentName\n'
                        'מסלול: $routeName',
                        style: GoogleFonts.heebo(),
                      ),
                      trailing: const Icon(Icons.phone),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('מסך הורה'),
          actions: [
            IconButton(
              tooltip: 'רענון',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshChildren,
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
                  onRefresh: _refreshChildren,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      Text(
                        'שלום ${widget.user.firstName} 👋',
                        style: GoogleFonts.heebo(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'כאן רואים את מצב ההסעה של הילדים שלך היום',
                        style: GoogleFonts.heebo(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (_loadError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _loadError!,
                          style: GoogleFonts.heebo(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SectionTitle('הילדים שלי'),
                      if (_children.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('לא נמצאו ילדים')),
                        ),
                      ..._children.map(
                        (child) => _ChildCard(
                          user: widget.user,
                          child: child,
                          messages: _messages
                              .where((m) => m.studentId == child.id)
                              .toList(),
                          onRefresh: _refreshChildren,
                          onReportAbsence: () => _openAbsenceReport(child),
                          onEditDetails: () => _openDetails(child),
                          onMessageEscort: () => _messageEscort(child),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openEscortsDialog,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.call),
          label: const Text('המלווים'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      ),
    );
  }
}

class _ChildCard extends StatefulWidget {
  final AppUser user;
  final Student child;
  final List<StudentMessage> messages;
  final Future<void> Function() onRefresh;
  final VoidCallback onReportAbsence;
  final VoidCallback onEditDetails;
  final VoidCallback onMessageEscort;

  const _ChildCard({
    required this.user,
    required this.child,
    required this.messages,
    required this.onRefresh,
    required this.onReportAbsence,
    required this.onEditDetails,
    required this.onMessageEscort,
  });

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isCancelling = false;
  bool _isUploadingPicture = false;
  String? _actionMessage;
  bool _isActionError = false;

  Student get child => widget.child;

  String get _status {
    final effectiveStatus = child.effectiveStatus?.trim();
    final attendanceStatus = child.attendanceStatus?.trim();
    final rideStudentStatus = child.rideStudentStatus?.trim();

    if (effectiveStatus != null &&
        effectiveStatus.isNotEmpty &&
        effectiveStatus != 'planned') {
      return effectiveStatus;
    }

    if (attendanceStatus != null && attendanceStatus.isNotEmpty) {
      return attendanceStatus;
    }

    if (rideStudentStatus != null && rideStudentStatus.isNotEmpty) {
      return rideStudentStatus;
    }

    if (child.reportedAbsentToday) {
      return 'reported_absent';
    }

    return 'waiting';
  }

  bool get _isReportedAbsent {
    return _status == 'reported_absent' || child.reportedAbsentToday;
  }

  bool get _isAbsent {
    return _status == 'absent';
  }

  bool get _canShowComingButton {
    return _isReportedAbsent || _isAbsent;
  }

  Future<void> _cancelAbsence() async {
    setState(() {
      _isCancelling = true;
      _actionMessage = null;
      _isActionError = false;
    });

    try {
      await ApiService.cancelParentAbsence(
        studentId: child.id,
        rideId: child.activeRideId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _actionMessage = 'עודכן בהצלחה: הילד מסומן כמגיע להסעה';
        _isActionError = false;
      });

      await widget.onRefresh();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionMessage = error.toString().replaceFirst('Exception: ', '');
        _isActionError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadPicture() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (image == null) {
      return;
    }

    setState(() {
      _isUploadingPicture = true;
      _actionMessage = null;
      _isActionError = false;
    });

    try {
      await ApiService.uploadParentChildPicture(
        studentId: child.id,
        imageFile: image,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _actionMessage = 'התמונה עודכנה בהצלחה';
        _isActionError = false;
      });

      await widget.onRefresh();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionMessage = error.toString().replaceFirst('Exception: ', '');
        _isActionError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPicture = false;
        });
      }
    }
  }

  String get _statusExplanation {
    switch (_status) {
      case 'waiting':
        return 'מתוכנן/ת להגיע היום. ההסעה עוד לא אספה אותו/ה.';
      case 'picked_up':
        return 'עלה/תה להסעה ונמצא/ת בדרך.';
      case 'dropped_off':
        return 'הגיע/ה ליעד בשלום.';
      case 'absent':
        return 'המלווה סימנה שלא היה/תה בתחנה.';
      case 'reported_absent':
        return 'דיווחת שלא יגיע/תגיע היום. המלווה רואה את הדיווח.';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final age = child.age;
    final subtitle = [
      if (age != null) 'בן/בת $age',
      if ((child.schoolName ?? '').isNotEmpty) child.schoolName!,
    ].join(' · ');
    final style = StatusStyle.of(_status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ChildAvatar.of(child, size: 60),
                    Positioned(
                      left: -4,
                      bottom: -4,
                      child: Tooltip(
                        message: 'החלפת תמונה',
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _isUploadingPicture
                                ? null
                                : _pickAndUploadPicture,
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: _isUploadingPicture
                                  ? const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.fullName,
                        style: GoogleFonts.heebo(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: GoogleFonts.heebo(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 6),
                      StatusPill(status: _status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(style.icon, size: 20, color: style.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusExplanation,
                      style: GoogleFonts.heebo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_actionMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _actionMessage!,
                style: GoogleFonts.heebo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _isActionError ? AppColors.error : AppColors.success,
                ),
              ),
            ],
            if (widget.messages.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...widget.messages
                  .take(2)
                  .map((m) => MessageTile(message: m, showStudentName: false)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_canShowComingButton)
                  ElevatedButton.icon(
                    style: compactFilledStyle(),
                    onPressed: _isCancelling ? null : _cancelAbsence,
                    icon: _isCancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle, size: 18),
                    label: Text(
                      _isCancelling ? 'מעדכן...' : 'הילד/ה כן מגיע/ה',
                    ),
                  )
                else
                  OutlinedButton.icon(
                    style: compactOutlinedStyle(
                      foreground: AppColors.statusAbsent,
                    ),
                    onPressed: widget.onReportAbsence,
                    icon: const Icon(Icons.event_busy, size: 18),
                    label: const Text('דיווח שלא יגיע/תגיע'),
                  ),
                OutlinedButton.icon(
                  style: compactOutlinedStyle(foreground: AppColors.primary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParentRideTrackingScreen(
                          user: widget.user,
                          student: child,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('איפה ההסעה?'),
                ),
                OutlinedButton.icon(
                  style: compactOutlinedStyle(foreground: AppColors.primary),
                  onPressed: widget.onMessageEscort,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('הודעה למלווה'),
                ),
                OutlinedButton.icon(
                  style: compactOutlinedStyle(foreground: AppColors.primary),
                  onPressed: widget.onEditDetails,
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('פרטי הילד/ה'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
