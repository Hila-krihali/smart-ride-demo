class ParentReport {
  final int id;
  final int parentId;
  final int studentId;
  final String reportType; // morning_absence / afternoon_absence / date_range_absence / note
  final DateTime startDate;
  final DateTime? endDate;
  final String? message;
  String status; // open / approved / handled
  final DateTime createdAt;

  ParentReport({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.reportType,
    required this.startDate,
    this.endDate,
    this.message,
    this.status = 'open',
    required this.createdAt,
  });
}
