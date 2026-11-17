/// A short message about a child (from a parent, the escort or the office).
class StudentMessage {
  final int id;
  final int studentId;
  final String studentName;
  final String authorName;
  final String authorRole;
  final String text;
  final DateTime? createdAt;

  StudentMessage({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.authorName,
    required this.authorRole,
    required this.text,
    this.createdAt,
  });

  factory StudentMessage.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'];
    return StudentMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      studentName: (json['student_name'] ?? '') as String,
      authorName: (json['author_name'] ?? '') as String,
      authorRole: (json['author_role'] ?? '') as String,
      text: (json['text'] ?? '') as String,
      createdAt: created is String ? DateTime.tryParse(created) : null,
    );
  }

  static List<StudentMessage> listFromJson(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(StudentMessage.fromJson)
        .toList();
  }

  /// "08:05" style time, or empty.
  String get timeLabel {
    final t = createdAt;
    if (t == null) {
      return '';
    }
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }
}
