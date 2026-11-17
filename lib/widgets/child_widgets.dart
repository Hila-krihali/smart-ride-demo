import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/student.dart';
import '../models/student_message.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';

/// Keeps page content at a comfortable width on big screens.
class PageWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const PageWidth({super.key, required this.child, this.maxWidth = 760});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Small, compact button style used inside cards.
ButtonStyle compactFilledStyle({Color? background}) {
  return ElevatedButton.styleFrom(
    minimumSize: const Size(0, 38),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    backgroundColor: background,
    textStyle: GoogleFonts.heebo(fontSize: 14, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

ButtonStyle compactOutlinedStyle({Color? foreground}) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(0, 38),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    foregroundColor: foreground,
    side: BorderSide(color: foreground ?? AppColors.outline, width: 1),
    textStyle: GoogleFonts.heebo(fontSize: 14, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

/// Round child photo. Falls back to a coloured circle with the first letter
/// when there is no picture (or it fails to load).
class ChildAvatar extends StatelessWidget {
  final String name;
  final String? pictureUrl;
  final double size;
  final int colorSeed;

  const ChildAvatar({
    super.key,
    required this.name,
    this.pictureUrl,
    this.size = 48,
    this.colorSeed = 0,
  });

  factory ChildAvatar.of(Student student, {double size = 48}) {
    return ChildAvatar(
      name: student.firstName,
      pictureUrl: student.pictureUrl,
      size: size,
      colorSeed: student.id,
    );
  }

  static const _palette = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF6C00),
    Color(0xFFAB47BC),
    Color(0xFF29B6F6),
    Color(0xFFEC407A),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[colorSeed.abs() % _palette.length];
    final fallback = Container(
      width: size,
      height: size,
      color: color.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: GoogleFonts.heebo(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
    final url = pictureUrl;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? fallback
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

/// Colour set for an attendance status.
class StatusStyle {
  final Color color;
  final Color background;
  final IconData icon;

  const StatusStyle(this.color, this.background, this.icon);

  static StatusStyle of(String status) {
    switch (status) {
      case 'picked_up':
        return const StatusStyle(
          AppColors.statusBoarded,
          AppColors.statusBoardedBg,
          Icons.directions_bus,
        );
      case 'dropped_off':
        return const StatusStyle(
          AppColors.statusDropped,
          AppColors.statusDroppedBg,
          Icons.task_alt,
        );
      case 'absent':
        return const StatusStyle(
          AppColors.statusAbsent,
          AppColors.statusAbsentBg,
          Icons.person_off,
        );
      case 'reported_absent':
        return const StatusStyle(
          AppColors.outline,
          AppColors.surfaceContainerLow,
          Icons.event_busy,
        );
      default:
        return const StatusStyle(
          Color(0xFF8D6E00),
          Color(0xFFFFF4CC),
          Icons.schedule,
        );
    }
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  final String? label;

  const StatusPill({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    final text = label ?? AppConstants.attendanceStatusLabels[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.heebo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: style.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title used on the dashboards.
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.heebo(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// One message line (author, child, time, text).
class MessageTile extends StatelessWidget {
  final StudentMessage message;
  final bool showStudentName;

  const MessageTile({
    super.key,
    required this.message,
    this.showStudentName = true,
  });

  @override
  Widget build(BuildContext context) {
    final role = AppConstants.roleLabels[message.authorRole] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            message.authorRole == 'parent'
                ? Icons.family_restroom
                : Icons.chat_bubble_outline,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    '${message.authorName}${role.isEmpty ? '' : ' ($role)'}',
                    if (showStudentName && message.studentName.isNotEmpty)
                      'על ${message.studentName}',
                  ].join(' · '),
                  style: GoogleFonts.heebo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  message.text,
                  style: GoogleFonts.heebo(
                    fontSize: 14,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (message.timeLabel.isNotEmpty)
            Text(
              message.timeLabel,
              style: GoogleFonts.heebo(fontSize: 12, color: AppColors.outline),
            ),
        ],
      ),
    );
  }
}

/// Asks for a short message. Returns the text, or null when cancelled.
Future<String?> showMessageComposer(
  BuildContext context, {
  required String title,
  String hint = 'כתבי כאן את ההודעה',
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.heebo(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(hintText: hint),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ביטול'),
            ),
            ElevatedButton.icon(
              style: compactFilledStyle(),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) Navigator.pop(dialogContext, text);
              },
              icon: const Icon(Icons.send, size: 18),
              label: const Text('שליחה'),
            ),
          ],
        ),
      );
    },
  ).whenComplete(controller.dispose);
}

/// Bottom sheet with everything the escort should know about a child.
Future<void> showStudentDetailsSheet(
  BuildContext context, {
  required Student student,
  String? status,
  String? absenceMessage,
  String? absenceReportedBy,
  List<StudentMessage> messages = const [],
  Future<void> Function(String text)? onSendMessage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return _StudentDetailsContent(
              scrollController: scrollController,
              student: student,
              status: status,
              absenceMessage: absenceMessage,
              absenceReportedBy: absenceReportedBy,
              messages: messages,
              onSendMessage: onSendMessage,
            );
          },
        ),
      );
    },
  );
}

class _StudentDetailsContent extends StatelessWidget {
  final ScrollController scrollController;
  final Student student;
  final String? status;
  final String? absenceMessage;
  final String? absenceReportedBy;
  final List<StudentMessage> messages;
  final Future<void> Function(String text)? onSendMessage;

  const _StudentDetailsContent({
    required this.scrollController,
    required this.student,
    required this.status,
    required this.absenceMessage,
    required this.absenceReportedBy,
    required this.messages,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final age = student.age;
    final subtitle = [
      if (age != null) 'בן/בת $age',
      if ((student.schoolName ?? '').isNotEmpty) student.schoolName!,
    ].join(' · ');

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            ChildAvatar.of(student, size: 76),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: GoogleFonts.heebo(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.heebo(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  if (status != null) ...[
                    const SizedBox(height: 6),
                    StatusPill(status: status!),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (absenceMessage != null || absenceReportedBy != null) ...[
          const SizedBox(height: 14),
          _InfoBox(
            color: AppColors.surfaceContainerLow,
            icon: Icons.event_busy,
            iconColor: AppColors.onSurfaceVariant,
            title:
                'סיבת ההיעדרות'
                '${absenceReportedBy == null ? '' : ' (דיווח של $absenceReportedBy)'}',
            text: (absenceMessage ?? '').isEmpty
                ? 'לא צוינה סיבה'
                : absenceMessage!,
          ),
        ],
        const SizedBox(height: 14),
        _DetailRow(
          icon: Icons.home_outlined,
          label: 'כתובת',
          value: student.address,
        ),
        _DetailRow(
          icon: Icons.phone_outlined,
          label: 'הורה',
          value: [
            student.parentName ?? '',
            student.parentPhone ?? '',
          ].where((v) => v.isNotEmpty).join(' · '),
        ),
        if ((student.mobilityStatus ?? '').isNotEmpty)
          _DetailRow(
            icon: Icons.accessible,
            label: 'ניידות',
            value: student.mobilityStatus!,
          ),
        const SizedBox(height: 8),
        _InfoBox(
          color: Student.hasValue(student.allergies)
              ? AppColors.statusAbsentBg
              : AppColors.surfaceContainerLow,
          icon: Icons.warning_amber_rounded,
          iconColor: Student.hasValue(student.allergies)
              ? AppColors.statusAbsent
              : AppColors.outline,
          title: 'אלרגיות',
          text: _orNone(student.allergies),
        ),
        _InfoBox(
          color: Student.hasValue(student.medicalInfo)
              ? AppColors.statusAbsentBg
              : AppColors.surfaceContainerLow,
          icon: Icons.medical_services_outlined,
          iconColor: Student.hasValue(student.medicalInfo)
              ? AppColors.statusAbsent
              : AppColors.outline,
          title: 'מידע רפואי חשוב',
          text: _orNone(student.medicalInfo),
        ),
        _InfoBox(
          color: Student.hasValue(student.sensitivities)
              ? const Color(0xFFFFF4CC)
              : AppColors.surfaceContainerLow,
          icon: Icons.psychology_alt_outlined,
          iconColor: Student.hasValue(student.sensitivities)
              ? const Color(0xFF8D6E00)
              : AppColors.outline,
          title: 'רגישויות ומוגבלויות',
          text: _orNone(student.sensitivities),
        ),
        if (Student.hasValue(student.generalInfo) ||
            Student.hasValue(student.notes))
          _InfoBox(
            color: AppColors.surfaceContainerLow,
            icon: Icons.info_outline,
            iconColor: AppColors.primary,
            title: 'מידע כללי',
            text: [
              if (Student.hasValue(student.generalInfo)) student.generalInfo!,
              if (Student.hasValue(student.notes)) student.notes!,
            ].join('\n'),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'הודעות היום',
                style: GoogleFonts.heebo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (onSendMessage != null)
              OutlinedButton.icon(
                style: compactOutlinedStyle(foreground: AppColors.primary),
                onPressed: () async {
                  final text = await showMessageComposer(
                    context,
                    title: 'הודעה על ${student.firstName}',
                  );
                  if (text == null) return;
                  await onSendMessage!(text);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: const Text('הודעה חדשה'),
              ),
          ],
        ),
        if (messages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'אין הודעות היום',
              style: GoogleFonts.heebo(color: AppColors.onSurfaceVariant),
            ),
          )
        else
          ...messages.map(
            (m) => MessageTile(message: m, showStudentName: false),
          ),
      ],
    );
  }

  static String _orNone(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? 'אין' : v;
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: GoogleFonts.heebo(
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: GoogleFonts.heebo(fontSize: 15))),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String text;

  const _InfoBox({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.heebo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(text, style: GoogleFonts.heebo(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
