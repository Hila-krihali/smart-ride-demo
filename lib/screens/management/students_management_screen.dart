import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/student.dart';
import '../../services/api_service.dart';
import '../../services/mock_data_service.dart';
import '../../utils/app_colors.dart';

class StudentsManagementScreen extends StatefulWidget {
  final int? userId;
  final String? role;

  const StudentsManagementScreen({super.key, this.userId, this.role});

  @override
  State<StudentsManagementScreen> createState() => _StudentsManagementScreenState();
}

class _StudentsManagementScreenState extends State<StudentsManagementScreen> {
  late Future<List<Student>> _studentsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _studentsFuture = _loadStudents();
  }

  Future<List<Student>> _loadStudents() async {
    if (widget.userId == null || widget.role == null) {
      debugPrint('StudentsManagement opened without logged-in user context; using mock fallback.');
      return MockDataService().students;
    }

    try {
      return await ApiService.getManagementStudents(
        userId: widget.userId!,
        role: widget.role!,
      );
    } catch (error) {
      debugPrint('StudentsManagement backend load failed; using mock fallback: $error');
      return MockDataService().students;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Students')),
        body: FutureBuilder<List<Student>>(
          future: _studentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allStudents = snapshot.data ?? <Student>[];
            final filtered = allStudents.where((student) {
              if (_searchQuery.isEmpty) return true;
              return student.fullName.contains(_searchQuery) ||
                  student.address.contains(_searchQuery);
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search student',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} students',
                        style: GoogleFonts.heebo(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final student = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: ExpansionTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                            child: Text(
                              student.firstName.isEmpty ? '?' : student.firstName[0],
                              style: GoogleFonts.heebo(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            student.fullName,
                            style: GoogleFonts.heebo(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            student.address,
                            style: GoogleFonts.heebo(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _row(Icons.location_on, 'Address', student.address),
                                  _row(Icons.accessible, 'Mobility', student.mobilityStatus ?? 'regular'),
                                  if (student.notes != null) _row(Icons.note, 'Notes', student.notes!),
                                  _row(Icons.school, 'School id', '${student.schoolId}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.heebo(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(child: Text(value, style: GoogleFonts.heebo(fontSize: 13))),
        ],
      ),
    );
  }
}
