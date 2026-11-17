class Student {
  final int id;
  final String firstName;
  final String lastName;
  final String address;
  final double latitude;
  final double longitude;
  final String? pictureUrl;
  final String? mobilityStatus;
  final String? notes;
  final int? parentId;
  final int schoolId;
  final bool isActive;
  final String? attendanceStatus;
  final String? rideStudentStatus;
  final bool reportedAbsentToday;
  final String? effectiveStatus;
  final String? routeDirection;
  final int? activeRideId;
  final int? etaMinutes;

  // Extra details (shown to the escort, editable by the parent).
  final String? birthDate; // yyyy-MM-dd
  final String? schoolName;
  final String? parentName;
  final String? parentPhone;
  final String? allergies;
  final String? medicalInfo;
  final String? sensitivities;
  final String? generalInfo;

  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.pictureUrl,
    this.mobilityStatus,
    this.notes,
    this.parentId,
    required this.schoolId,
    this.isActive = true,
    this.attendanceStatus,
    this.rideStudentStatus,
    this.reportedAbsentToday = false,
    this.effectiveStatus,
    this.routeDirection,
    this.activeRideId,
    this.etaMinutes,
    this.birthDate,
    this.schoolName,
    this.parentName,
    this.parentPhone,
    this.allergies,
    this.medicalInfo,
    this.sensitivities,
    this.generalInfo,
  });

  String get fullName => '$firstName $lastName';

  /// Age in whole years, or null when the birth date is unknown.
  int? get age {
    final raw = birthDate;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final born = DateTime.tryParse(raw);
    if (born == null) {
      return null;
    }
    final now = DateTime.now();
    var years = now.year - born.year;
    if (now.month < born.month ||
        (now.month == born.month && now.day < born.day)) {
      years--;
    }
    return years < 0 ? null : years;
  }

  /// True when an important-sounding value is filled in (not empty / "אין").
  static bool hasValue(String? value) {
    final v = value?.trim() ?? '';
    return v.isNotEmpty && v != 'אין' && v != '-';
  }

  static int _intValue(dynamic value, {int defaultValue = 0}) {
    if (value == null) {
      return defaultValue;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }

    return defaultValue;
  }

  static int? _nullableIntValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  static double _doubleValue(dynamic value, {double defaultValue = 0}) {
    if (value == null) {
      return defaultValue;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }

    return defaultValue;
  }

  static bool _boolValue(dynamic value, {bool defaultValue = false}) {
    if (value == null) {
      return defaultValue;
    }

    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return defaultValue;
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: _intValue(json['id']),
      firstName: (json['first_name'] ?? '') as String,
      lastName: (json['last_name'] ?? '') as String,
      address: (json['address'] ?? '') as String,
      latitude: _doubleValue(json['latitude']),
      longitude: _doubleValue(json['longitude']),
      pictureUrl: json['picture_url'] as String?,
      mobilityStatus: json['mobility_status'] as String?,
      notes: json['notes'] as String?,
      parentId: _nullableIntValue(json['parent_id']),
      schoolId: _intValue(json['school_id']),
      isActive: _boolValue(json['is_active'], defaultValue: true),
      attendanceStatus: json['attendance_status'] as String?,
      rideStudentStatus: json['ride_student_status'] as String?,
      reportedAbsentToday: _boolValue(json['reported_absent_today']),

      // התיקון כאן: תופס את כל השמות האפשריים של הסטטוס ומגן מ-null
      effectiveStatus:
          json['status'] as String? ??
          json['effective_status'] as String? ??
          'planned',

      routeDirection: json['route_direction'] as String?,
      activeRideId: _nullableIntValue(json['active_ride_id']),
      etaMinutes: _nullableIntValue(json['eta_minutes']),
      birthDate: json['birth_date'] as String?,
      schoolName: json['school_name'] as String?,
      parentName: json['parent_name'] as String?,
      parentPhone: json['parent_phone'] as String?,
      allergies: json['allergies'] as String?,
      medicalInfo: json['medical_info'] as String?,
      sensitivities: json['sensitivities'] as String?,
      generalInfo: json['general_info'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'picture_url': pictureUrl,
      'mobility_status': mobilityStatus,
      'notes': notes,
      'parent_id': parentId,
      'school_id': schoolId,
      'is_active': isActive,
      'attendance_status': attendanceStatus,
      'ride_student_status': rideStudentStatus,
      'reported_absent_today': reportedAbsentToday,
      'effective_status': effectiveStatus,
      'route_direction': routeDirection,
      'active_ride_id': activeRideId,
      'eta_minutes': etaMinutes,
      'birth_date': birthDate,
      'school_name': schoolName,
      'parent_name': parentName,
      'parent_phone': parentPhone,
      'allergies': allergies,
      'medical_info': medicalInfo,
      'sensitivities': sensitivities,
      'general_info': generalInfo,
    };
  }
}
