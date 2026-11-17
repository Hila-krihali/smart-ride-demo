import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../models/student.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../auth/login_screen.dart';
import 'parent_absence_report_screen.dart';
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
    return await ApiService.getParentChildren(parentId: widget.user.id);
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

  List<Map<String, dynamic>> _dedupeEscorts(List<Map<String, dynamic>> escorts) {
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

      if (newRouteName.isNotEmpty && !existingRouteName.contains(newRouteName)) {
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'שלום ${widget.user.firstName}',
                          style: GoogleFonts.heebo(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'מידע על ההסעות של הילדים שלך',
                          style: GoogleFonts.heebo(
                            fontSize: 16,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'הילדים שלי',
                      style: GoogleFonts.heebo(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _loadError!,
                        style: GoogleFonts.heebo(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: _children.isEmpty
                        ? const Center(child: Text('לא נמצאו ילדים'))
                        : RefreshIndicator(
                            onRefresh: _refreshChildren,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _children.length,
                              itemBuilder: (context, index) {
                                final child = _children[index];

                                return _ChildCard(
                                  user: widget.user,
                                  child: child,
                                  onRefresh: _refreshChildren,
                                  onReportAbsence: () {
                                    _openAbsenceReport(child);
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openEscortsDialog,
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: const Icon(Icons.call, size: 28),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      ),
    );
  }
}

class _ChildCard extends StatefulWidget {
  final AppUser user;
  final Student child;
  final Future<void> Function() onRefresh;
  final VoidCallback onReportAbsence;

  const _ChildCard({
    required this.user,
    required this.child,
    required this.onRefresh,
    required this.onReportAbsence,
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

  String get _statusLabel {
    return AppConstants.attendanceStatusLabels[_status] ?? _status;
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

  Color get _statusColor {
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
        return AppColors.primary;
    }
  }

  Color get _statusBackground {
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

  IconData get _statusIcon {
    switch (_status) {
      case 'picked_up':
        return Icons.directions_bus;
      case 'dropped_off':
        return Icons.task_alt;
      case 'absent':
        return Icons.person_off;
      case 'reported_absent':
        return Icons.event_busy;
      default:
        return Icons.access_time;
    }
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

  @override
  Widget build(BuildContext context) {
    final statusText = _statusLabel;
    final pictureUrl = child.pictureUrl;
    final hasPicture = pictureUrl != null && pictureUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    backgroundImage: hasPicture
                        ? NetworkImage(pictureUrl)
                        : null,
                    child: hasPicture
                        ? null
                        : Text(
                            child.firstName.isEmpty ? '?' : child.firstName[0],
                            style: GoogleFonts.heebo(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                  Positioned(
                    left: -6,
                    bottom: -6,
                    child: Tooltip(
                      message: 'העלאת תמונה',
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isUploadingPicture
                              ? null
                              : _pickAndUploadPicture,
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: _isUploadingPicture
                                ? const Padding(
                                    padding: EdgeInsets.all(7),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.fullName,
                      style: GoogleFonts.heebo(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      child.address,
                      style: GoogleFonts.heebo(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _statusBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon, color: _statusColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    style: GoogleFonts.heebo(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isReportedAbsent) ...[
            const SizedBox(height: 10),
            Text(
              'דיווחת שהילד לא יגיע היום.',
              style: GoogleFonts.heebo(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          if (_isAbsent && !_isReportedAbsent) ...[
            const SizedBox(height: 10),
            Text(
              'הילד מסומן כרגע כלא מגיע.',
              style: GoogleFonts.heebo(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          if (_actionMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _actionMessage!,
              style: GoogleFonts.heebo(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _isActionError ? AppColors.error : AppColors.success,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
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
                  icon: const Icon(Icons.map),
                  label: const Text('מעקב הסעה'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _canShowComingButton
                    ? OutlinedButton.icon(
                        onPressed: _isCancelling ? null : _cancelAbsence,
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle),
                        label: Text(
                          _isCancelling ? 'מעדכן...' : 'הילד כן יגיע',
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: widget.onReportAbsence,
                        icon: const Icon(Icons.event_busy),
                        label: const Text('דווח שלא יגיע'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}