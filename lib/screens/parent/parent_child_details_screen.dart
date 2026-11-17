import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../models/student.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/child_widgets.dart';

/// Lets a parent fill in what the escort should know about the child.
class ParentChildDetailsScreen extends StatefulWidget {
  final Student student;

  const ParentChildDetailsScreen({super.key, required this.student});

  @override
  State<ParentChildDetailsScreen> createState() =>
      _ParentChildDetailsScreenState();
}

class _ParentChildDetailsScreenState extends State<ParentChildDetailsScreen> {
  late final TextEditingController _allergies;
  late final TextEditingController _medical;
  late final TextEditingController _sensitivities;
  late final TextEditingController _general;
  DateTime? _birthDate;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _allergies = TextEditingController(text: s.allergies ?? '');
    _medical = TextEditingController(text: s.medicalInfo ?? '');
    _sensitivities = TextEditingController(text: s.sensitivities ?? '');
    _general = TextEditingController(text: s.generalInfo ?? '');
    _birthDate = s.birthDate == null ? null : DateTime.tryParse(s.birthDate!);
  }

  @override
  void dispose() {
    _allergies.dispose();
    _medical.dispose();
    _sensitivities.dispose();
    _general.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 8),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: 'תאריך לידה',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ApiService.updateChildDetails(
        studentId: widget.student.id,
        details: {
          'birth_date': _birthDate == null
              ? null
              : DateFormat('yyyy-MM-dd').format(_birthDate!),
          'allergies': _allergies.text.trim(),
          'medical_info': _medical.text.trim(),
          'sensitivities': _sensitivities.text.trim(),
          'general_info': _general.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הפרטים נשמרו והמלווה יראה אותם'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 4,
        maxLength: 500,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text('הפרטים של ${s.firstName}')),
        body: PageWidth(
          maxWidth: 640,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  ChildAvatar.of(s, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.fullName,
                          style: GoogleFonts.heebo(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          [
                            if ((s.schoolName ?? '').isNotEmpty) s.schoolName!,
                            s.address,
                          ].join(' · '),
                          style: GoogleFonts.heebo(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'המידע כאן מוצג למלווה בהסעה, כדי שתדע איך לשמור על הילד/ה.',
                style: GoogleFonts.heebo(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickBirthDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'תאריך לידה',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'בחירת תאריך'
                        : DateFormat('dd/MM/yyyy').format(_birthDate!),
                    style: GoogleFonts.heebo(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _field(
                label: 'אלרגיות',
                hint: 'לדוגמה: בוטנים – אפיפן בתיק. אם אין, כתבו "אין"',
                icon: Icons.warning_amber_rounded,
                controller: _allergies,
              ),
              _field(
                label: 'מידע רפואי חשוב',
                hint: 'מחלות, תרופות, מה לעשות במקרה חירום',
                icon: Icons.medical_services_outlined,
                controller: _medical,
              ),
              _field(
                label: 'רגישויות ומוגבלויות',
                hint: 'לדוגמה: רגיש לרעש, צריך עזרה בעלייה לרכב',
                icon: Icons.psychology_alt_outlined,
                controller: _sensitivities,
              ),
              _field(
                label: 'מידע כללי',
                hint: 'כל דבר נוסף שכדאי למלווה לדעת',
                icon: Icons.info_outline,
                controller: _general,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: GoogleFonts.heebo(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'שומר...' : 'שמירה'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
