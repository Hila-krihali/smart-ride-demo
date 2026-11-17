class Attendance {
  final int id;
  final int rideId;
  final int studentId;
  String status; // waiting / picked_up / absent / dropped_off
  int? updatedBy;
  DateTime? updatedAt;

  Attendance({
    required this.id,
    required this.rideId,
    required this.studentId,
    this.status = 'waiting',
    this.updatedBy,
    this.updatedAt,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] as int,
      rideId: json['ride_id'] as int,
      studentId: json['student_id'] as int,
      status: (json['status'] ?? 'waiting') as String,
      updatedBy: json['updated_by'] as int?,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_id': rideId,
      'student_id': studentId,
      'status': status,
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
