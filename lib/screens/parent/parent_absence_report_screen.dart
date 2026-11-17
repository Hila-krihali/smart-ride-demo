import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../models/app_user.dart';
import '../../models/student.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/child_widgets.dart';

class ParentAbsenceReportScreen extends StatefulWidget {
  final AppUser user;
  final Student student;

  const ParentAbsenceReportScreen({
    super.key,
    required this.user,
    required this.student,
  });

  @override
  State<ParentAbsenceReportScreen> createState() =>
      _ParentAbsenceReportScreenState();
}

class _ParentAbsenceReportScreenState extends State<ParentAbsenceReportScreen> {
  String _reportType = 'morning_absence';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  final TextEditingController _messageController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _dateToApi(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _selectDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = picked;

        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ApiService.createParentReport(
        studentId: widget.student.id,
        reportType: _reportType,
        startDate: _dateToApi(_startDate),
        endDate: _reportType == 'date_range_absence' && _endDate != null
            ? _dateToApi(_endDate!)
            : null,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הדיווח נשלח בהצלחה למלווה ולהנהלה'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? 'שליחת הדיווח נכשלה. נסי שוב.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _studentInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          ChildAvatar.of(widget.student, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.student.fullName,
              style: GoogleFonts.heebo(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _reportType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _reportType = value;

          if (_reportType != 'date_range_absence') {
            _endDate = null;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.heebo(
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.heebo(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptions() {
    return [
      _reportOption(
        value: 'morning_absence',
        title: 'לא יגיע בבוקר',
        subtitle: 'הילד לא יעלה להסעת הבוקר',
        icon: Icons.wb_sunny,
      ),
      _reportOption(
        value: 'afternoon_absence',
        title: 'לא צריך הסעה חזור',
        subtitle: 'הילד לא יעלה להסעת החזור',
        icon: Icons.nights_stay,
      ),
      _reportOption(
        value: 'date_range_absence',
        title: 'היעדרות בטווח תאריכים',
        subtitle: 'הילד לא יגיע למשך כמה ימים',
        icon: Icons.date_range,
      ),
    ];
  }

  Widget _dateSelector({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              date != null
                  ? '$label: ${DateFormat('dd/MM/yyyy').format(date)}'
                  : '$label: בחר תאריך',
              style: GoogleFonts.heebo(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('דיווח היעדרות')),
        body: PageWidth(
          maxWidth: 640,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _studentInfoCard(),
                const SizedBox(height: 24),
                Text(
                  'סוג הדיווח',
                  style: GoogleFonts.heebo(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildOptions(),
                const SizedBox(height: 24),
                Text(
                  'תאריך',
                  style: GoogleFonts.heebo(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _dateSelector(
                  label: 'מתאריך',
                  date: _startDate,
                  onTap: () => _selectDate(isStart: true),
                ),
                if (_reportType == 'date_range_absence') ...[
                  const SizedBox(height: 8),
                  _dateSelector(
                    label: 'עד תאריך',
                    date: _endDate,
                    onTap: () => _selectDate(isStart: false),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'הערה אופציונלית',
                  style: GoogleFonts.heebo(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'לדוגמה: הילד לא יגיע מחר ללימודים',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.heebo(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitReport,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isSubmitting ? 'שולח דיווח...' : 'שלח דיווח'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
