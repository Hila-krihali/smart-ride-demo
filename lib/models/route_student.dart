import 'student.dart';
import 'student_message.dart';

class RouteStudent {
  final int routeId;
  final int studentId;
  final int pickupOrder;
  final String? plannedPickupTime;

  RouteStudent({
    required this.routeId,
    required this.studentId,
    required this.pickupOrder,
    this.plannedPickupTime,
  });
}

class RouteStudentInfo {
  final int id;
  final int routeId;
  final int studentId;
  final int? escortId;
  final int? pickupOrder;
  final String? attendanceStatus;
  final String? rideStudentStatus;
  final bool reportedAbsentToday;
  final String effectiveStatus;
  final String? routeDirection;
  final int? activeRideId;
  final Student student;

  /// Why the child is not coming today (parent's absence report), if any.
  final String? absenceMessage;
  final String? absenceReportedBy;

  /// Today's messages about this child (newest first).
  final List<StudentMessage> messages;

  RouteStudentInfo({
    required this.id,
    required this.routeId,
    required this.studentId,
    this.escortId,
    this.pickupOrder,
    this.attendanceStatus,
    this.rideStudentStatus,
    this.reportedAbsentToday = false,
    this.effectiveStatus = 'waiting',
    this.routeDirection,
    this.activeRideId,
    required this.student,
    this.absenceMessage,
    this.absenceReportedBy,
    this.messages = const [],
  });

  static int? _readInt(dynamic value) {
    return value is num ? value.toInt() : null;
  }

  factory RouteStudentInfo.fromJson(Map<String, dynamic> json) {
    return RouteStudentInfo(
      id: _readInt(json['id']) ?? 0,
      routeId: _readInt(json['route_id']) ?? 0,
      studentId: _readInt(json['student_id']) ?? 0,
      escortId: json['escort_id'] as int?,
      pickupOrder:
          _readInt(json['pickup_order']) ??
          _readInt(json['default_pickup_order']),
      attendanceStatus: json['attendance_status'] as String?,
      rideStudentStatus: json['ride_student_status'] as String?,
      reportedAbsentToday: (json['reported_absent_today'] as bool?) ?? false,
      effectiveStatus: (json['effective_status'] ?? 'waiting') as String,
      routeDirection: json['route_direction'] as String?,
      activeRideId: json['active_ride_id'] as int?,
      student: Student.fromJson(json['student'] as Map<String, dynamic>),
      absenceMessage:
          (json['absence_report'] as Map<String, dynamic>?)?['message']
              as String?,
      absenceReportedBy:
          (json['absence_report'] as Map<String, dynamic>?)?['reported_by']
              as String?,
      messages: StudentMessage.listFromJson(json['messages']),
    );
  }

  RouteStudentInfo copyWith({
    String? attendanceStatus,
    String? rideStudentStatus,
    bool? reportedAbsentToday,
    String? effectiveStatus,
  }) {
    return RouteStudentInfo(
      id: id,
      routeId: routeId,
      studentId: studentId,
      escortId: escortId,
      pickupOrder: pickupOrder,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      rideStudentStatus: rideStudentStatus ?? this.rideStudentStatus,
      reportedAbsentToday: reportedAbsentToday ?? this.reportedAbsentToday,
      effectiveStatus: effectiveStatus ?? this.effectiveStatus,
      routeDirection: routeDirection,
      activeRideId: activeRideId,
      student: student,
      absenceMessage: absenceMessage,
      absenceReportedBy: absenceReportedBy,
      messages: messages,
    );
  }
}
