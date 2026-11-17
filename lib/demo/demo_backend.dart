// Demo backend that runs entirely inside the app (no server needed).
//
// Used only when the app is built with --dart-define=DEMO_MODE=true
// (for example the GitHub Pages demo). It mirrors the endpoints and JSON
// shapes of the FastAPI backend in /backend, using the same demo data as
// backend/seed_data.py, kept in memory. Refreshing the page resets the data.
//
// This file is pure Dart on purpose (no Flutter / package imports), so it can
// be tested with plain `dart test`-style scripts.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

typedef DemoFetchText = Future<String?> Function(Uri uri);

/// Optional key/value storage (browser localStorage on the web) so the demo
/// data survives a page refresh and is shared between browser tabs.
abstract class DemoStore {
  String? read(String key);
  void write(String key, String value);
}

class DemoResponse {
  DemoResponse(this.statusCode, Object? body)
    : bodyBytes = utf8.encode(jsonEncode(body));

  final int statusCode;
  final List<int> bodyBytes;

  Map<String, String> get headers => const {
    'content-type': 'application/json; charset=utf-8',
  };
}

class _HttpError implements Exception {
  _HttpError(this.statusCode, this.detail);
  final int statusCode;
  final String detail;
}

typedef _Row = Map<String, dynamic>;

class DemoBackend {
  DemoBackend({
    required String baseUrl,
    this.fetchText,
    this.enforceDepartureTime = false,
    this.store,
    DateTime Function()? clock,
  }) : _base = Uri.parse(baseUrl),
       _clock = clock ?? DateTime.now {
    _seed();
    if (!_syncIn()) _syncOut();
  }

  /// Where the shared demo state is kept (null = memory only).
  final DemoStore? store;

  static const _stateKey = 'smartride_demo_state_v2';
  static const _versionKey = 'smartride_demo_version_v2';
  String? _seenVersion;
  int _saveCounter = 0;

  /// Default starting point of the bus (the depot).
  static const double depotLat = 31.2445;
  static const double depotLon = 34.7985;

  Map<String, List<_Row>> get _tables => {
    'users': _users,
    'schools': _schools,
    'students': _students,
    'parent_student': _parentStudent,
    'vehicles': _vehicles,
    'routes': _routes,
    'route_assignments': _routeAssignments,
    'route_students': _routeStudents,
    'rides': _rides,
    'ride_students': _rideStudents,
    'attendance': _attendance,
    'parent_reports': _parentReports,
    'alerts': _alerts,
    'ride_locations': _rideLocations,
    'messages': _messages,
    'progress': _progress,
  };

  /// Loads the shared state if another tab (or an earlier visit) changed it.
  /// Returns true when stored state exists and is usable.
  bool _syncIn() {
    final st = store;
    if (st == null) return false;
    try {
      final version = st.read(_versionKey);
      if (version == null) return false;
      if (version == _seenVersion) return true;
      final raw = st.read(_stateKey);
      if (raw == null) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      // Data from an earlier day is replaced by a fresh demo day.
      if (decoded['day'] != _today) return false;
      final tables = decoded['tables'];
      if (tables is! Map<String, dynamic>) return false;
      for (final entry in _tables.entries) {
        final rows = tables[entry.key];
        if (rows is! List) return false;
        entry.value
          ..clear()
          ..addAll(rows.whereType<Map<String, dynamic>>());
      }
      _seenVersion = version;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _syncOut() {
    final st = store;
    if (st == null) return;
    try {
      final version =
          '${_now.microsecondsSinceEpoch}-${_saveCounter++}-${identityHashCode(this)}';
      st.write(_stateKey, jsonEncode({'day': _today, 'tables': _tables}));
      st.write(_versionKey, version);
      _seenVersion = version;
    } catch (_) {
      // Storage full or unavailable: keep working in memory.
    }
  }

  void _reset() {
    for (final table in _tables.values) {
      table.clear();
    }
    _seed();
  }

  final Uri _base;
  final DateTime Function() _clock;

  /// Used to call the public OSRM server for real road geometry.
  /// If null or it fails, a simple nearest-neighbour order is used.
  final DemoFetchText? fetchText;

  /// The real backend refuses "cancel absence" after the ride's planned
  /// departure time. In the demo this is off so visitors can try it any time.
  final bool enforceDepartureTime;

  /// True when [url] points at the (fake) backend.
  bool handles(Uri url) =>
      url.scheme == _base.scheme &&
      url.host == _base.host &&
      url.port == _base.port;

  // ---------------------------------------------------------------- tables
  final List<_Row> _users = [];
  final List<_Row> _schools = [];
  final List<_Row> _students = [];
  final List<_Row> _parentStudent = [];
  final List<_Row> _vehicles = [];
  final List<_Row> _routes = [];
  final List<_Row> _routeAssignments = [];
  final List<_Row> _routeStudents = [];
  final List<_Row> _rides = [];
  final List<_Row> _rideStudents = [];
  final List<_Row> _attendance = [];
  final List<_Row> _parentReports = [];
  final List<_Row> _alerts = [];
  final List<_Row> _rideLocations = [];
  final List<_Row> _messages = [];
  final List<_Row> _progress = [];
  final Map<String, List<List<double>>> _legCache = {};

  // ------------------------------------------------------------- time utils
  DateTime get _now => _clock();

  String _two(int v) => v.toString().padLeft(2, '0');

  String _dateOf(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  String get _today => _dateOf(_now);

  /// Naive ISO timestamp (no timezone suffix), like the Python backend.
  String _isoNow() {
    final s = _now.toIso8601String();
    return s.endsWith('Z') ? s.substring(0, s.length - 1) : s;
  }

  // ------------------------------------------------------------------ seed
  void _seed() {
    final now = _isoNow();
    final today = _today;

    _users.addAll([
      _user(1, 'שרה', 'כהן', '050-1234567', 'sara@example.com', 'escort'),
      _user(2, 'רחל', 'לוי', '050-2345678', 'rachel@example.com', 'parent'),
      _user(3, 'דוד', 'מזרחי', '050-3456789', 'david@example.com', 'driver'),
      _user(4, 'יעל', 'אברהם', '050-4567890', 'yael@example.com', 'manager'),
      _user(5, 'מיכל', 'פרץ', '050-5678901', 'michal@example.com', 'parent'),
      _user(6, 'אבי', 'גולד', '050-6789012', 'avi@example.com', 'escort'),
      _user(7, 'משה', 'ביטון', '050-7890123', 'moshe@example.com', 'driver'),
      _user(8, 'אורלי', 'דהן', '052-8123456', 'orly@example.com', 'parent'),
      _user(9, 'שירי', 'אזולאי', '054-9234567', 'shiri@example.com', 'parent'),
      _user(10, 'דנה', 'גבאי', '053-1345678', 'dana@example.com', 'parent'),
    ]);

    _schools.addAll([
      {
        'id': 1,
        'name': 'בית ספר אופק',
        'address': 'רחוב הרצל 15, באר שבע',
        'latitude': 31.253,
        'longitude': 34.7915,
      },
      {
        'id': 2,
        'name': 'מרכז חינוכי שחר',
        'address': 'רחוב ביאליק 8, באר שבע',
        'latitude': 31.25,
        'longitude': 34.789,
      },
    ]);

    _students.addAll([
      _student(
        1,
        'יוסי',
        'לוי',
        'שדרות רגר 22, באר שבע',
        31.2518,
        34.7913,
        'רגיש לרעש. מומלץ לעדכן מראש במקרה של שינוי במסלול.',
        'רגיל',
        2,
        1,
      ),
      _student(
        2,
        'נועה',
        'לוי',
        'שדרות רגר 22, באר שבע',
        31.2518,
        34.7913,
        'זקוקה לתזכורת רגועה לפני העלייה להסעה.',
        'רגיל',
        2,
        1,
      ),
      _student(
        3,
        'עומר',
        'פרץ',
        'רחוב הנשיאים 5, באר שבע',
        31.2545,
        34.788,
        'זקוק לעזרה בעלייה לרכב.',
        'כיסא גלגלים',
        5,
        1,
      ),
      _student(
        4,
        'תמר',
        'דהן',
        'שדרות בן גוריון 30, באר שבע',
        31.249,
        34.795,
        'יש לוודא שאחד ההורים נמצא בבית בזמן האיסוף.',
        'רגיל',
        8,
        1,
      ),
      _student(
        5,
        'איתן',
        'אזולאי',
        'רחוב העצמאות 12, באר שבע',
        31.256,
        34.787,
        'זקוק לליווי צמוד בתחילת הנסיעה.',
        'ליווי מיוחד',
        9,
        2,
      ),
      _student(
        6,
        'מאיה',
        'גבאי',
        'רחוב קרן קיימת 7, באר שבע',
        31.2475,
        34.7935,
        'מומלץ להושיב ליד החלון.',
        'רגיל',
        10,
        2,
      ),
    ]);

    // Details shown to the escort (and editable by the parent).
    const details = <int, List<String>>{
      // birth date, allergies, medical info, sensitivities, general info
      1: [
        '2017-03-12',
        'אין',
        'אין',
        'רגיש לרעשים חזקים, מעדיף לשבת בשורה הראשונה',
        'אוהב לדבר על כדורגל – זה עוזר להרגיע אותו',
      ],
      2: [
        '2019-06-02',
        'אלרגיה לבוטנים – אפיפן בכיס הקדמי של התיק',
        'אין',
        'זקוקה לתזכורת רגועה לפני העלייה להסעה',
        'תסמונת דאון. אוהבת שירים – שיר קצר עוזר לה לעלות להסעה',
      ],
      3: [
        '2016-11-20',
        'אין',
        'משתמש בכיסא גלגלים – נדרש מעלון',
        'אין',
        'תסמונת דאון. אמא מלווה אותו עד הרכב',
      ],
      4: [
        '2018-01-15',
        'רגישות ללקטוז',
        'אין',
        'מתקשה במעברים – כדאי להודיע לה מראש לפני כל עצירה',
        'יש לוודא שהורה נמצא בבית בזמן ההחזרה',
      ],
      5: [
        '2018-04-10',
        'אין',
        'אפילפסיה – תרופת חירום בתיק הקדמי, הוראות מצורפות',
        'מכשירי שמיעה בשתי האוזניים – לדבר מולו ולוודא שהמכשירים דלוקים',
        'זקוק לליווי צמוד בתחילת הנסיעה',
      ],
      6: [
        '2013-12-30',
        'אלרגיה לעקיצות דבורים',
        'אין',
        'שתל שבלול – לדבר מולה, לאט וברור. מעדיפה לשבת ליד החלון',
        '',
      ],
    };
    for (final s in _students) {
      final d = details[s['id']];
      if (d == null) continue;
      s['birth_date'] = d[0];
      s['allergies'] = d[1];
      s['medical_info'] = d[2];
      s['sensitivities'] = d[3];
      s['general_info'] = d[4];
      // Upload pictures to web/children/<id>.jpg to show real photos.
      s['picture_url'] = 'children/${s['id']}.jpg';
    }

    for (final pair in const [
      [2, 1], [2, 2], [8, 4], [5, 3], [9, 5], [10, 6], //
    ]) {
      _parentStudent.add({'parent_id': pair[0], 'student_id': pair[1]});
    }

    _vehicles.addAll([
      {
        'id': 1,
        'vehicle_number': '12-345-67',
        'vehicle_type': 'מיניבוס נגיש',
        'seats_count': 12,
        'has_accessibility': true,
        'notes': null,
      },
      {
        'id': 2,
        'vehicle_number': '23-456-78',
        'vehicle_type': 'מיניבוס רגיל',
        'seats_count': 8,
        'has_accessibility': false,
        'notes': null,
      },
    ]);

    _routes.addAll([
      _route(
        1,
        1,
        'מסלול 1 - אופק בוקר',
        'morning',
        '07:15:00',
        3,
        '12-345-67',
        'מיניבוס נגיש',
        'active',
      ),
      _route(
        2,
        1,
        'מסלול 1 - אופק צהריים',
        'afternoon',
        '14:00:00',
        3,
        '12-345-67',
        'מיניבוס נגיש',
        'planned',
      ),
      _route(
        3,
        1,
        'מסלול 2 - שחר בוקר',
        'morning',
        '07:30:00',
        7,
        '23-456-78',
        'מיניבוס רגיל',
        'planned',
      ),
    ]);

    var assignmentId = 1;
    for (final a in const [
      // route, student, escort, order
      [1, 1, 1, 1], [1, 2, 1, 2], [1, 3, 1, 3], [1, 4, 1, 4],
      [2, 1, 1, 1], [2, 2, 1, 2],
      [3, 5, 6, 1], [3, 6, 6, 2],
    ]) {
      _routeAssignments.add({
        'id': assignmentId++,
        'route_id': a[0],
        'student_id': a[1],
        'escort_id': a[2],
        'default_pickup_order': a[3],
      });
    }

    for (final r in const [
      [1, 1, 1, '07:30:00'],
      [1, 2, 2, '07:35:00'],
      [1, 3, 3, '07:40:00'],
      [1, 4, 4, '07:50:00'],
      [2, 1, 1, '14:00:00'],
      [2, 2, 2, '14:05:00'],
      [3, 5, 1, '07:45:00'],
      [3, 6, 2, '07:55:00'],
    ]) {
      _routeStudents.add({
        'route_id': r[0],
        'student_id': r[1],
        'pickup_order': r[2],
        'planned_pickup_time': r[3],
      });
    }

    _rides.addAll([
      {
        'id': 1,
        'route_id': 1,
        'ride_date': today,
        'status': 'active',
        'current_latitude': null,
        'current_longitude': null,
        'last_location_update': null,
      },
      {
        'id': 2,
        'route_id': 2,
        'ride_date': today,
        'status': 'planned',
        'current_latitude': null,
        'current_longitude': null,
        'last_location_update': null,
      },
      {
        'id': 3,
        'route_id': 3,
        'ride_date': today,
        'status': 'planned',
        'current_latitude': null,
        'current_longitude': null,
        'last_location_update': null,
      },
    ]);

    _rideStudents.addAll([
      _rideStudent(1, 1, 1, 1, true, 1, null, 'waiting', null),
      _rideStudent(2, 1, 2, 1, true, 2, null, 'waiting', null),
      _rideStudent(3, 1, 3, 1, false, 3, null, 'absent', null),
      _rideStudent(4, 1, 4, 1, true, 4, null, 'waiting', null),
    ]);

    _attendance.addAll([
      _att(1, 1, 1, 'waiting', null, now),
      _att(2, 1, 2, 'waiting', null, now),
      _att(3, 1, 3, 'absent', 5, now),
      _att(4, 1, 4, 'waiting', null, now),
    ]);

    _parentReports.add({
      'id': 1,
      'parent_id': 5,
      'student_id': 3,
      'report_type': 'morning_absence',
      'start_date': today,
      'end_date': null,
      'message': 'עומר עם חום ונשאר היום בבית.',
      'status': 'open',
      'created_at': now,
    });

    _messages.add({
      'id': 1,
      'student_id': 3,
      'author_id': 5,
      'author_name': 'מיכל פרץ',
      'author_role': 'parent',
      'text': 'דיווח היעדרות: עומר עם חום ונשאר היום בבית.',
      'date': today,
      'created_at': now,
    });

    _alerts.addAll([
      {
        'id': 1,
        'ride_id': 1,
        'alert_type': 'delay',
        'message': 'מסלול 1 בבוקר מתעכב בכ־5 דקות.',
        'severity': 'low',
        'status': 'open',
        'created_at': now,
      },
      {
        'id': 2,
        'ride_id': null,
        'alert_type': 'parent_report',
        'message': 'התקבל דיווח היעדרות חדש מהורה.',
        'severity': 'medium',
        'status': 'open',
        'created_at': now,
      },
    ]);
  }

  _Row _user(
    int id,
    String first,
    String last,
    String phone,
    String email,
    String role,
  ) => {
    'id': id,
    'first_name': first,
    'last_name': last,
    'phone_number': phone,
    'email': email,
    'role': role,
    'picture_url': null,
  };

  _Row _student(
    int id,
    String first,
    String last,
    String address,
    double lat,
    double lon,
    String notes,
    String mobility,
    int parentId,
    int schoolId,
  ) => {
    'id': id,
    'first_name': first,
    'last_name': last,
    'address': address,
    'latitude': lat,
    'longitude': lon,
    'notes': notes,
    'mobility_status': mobility,
    'parent_id': parentId,
    'school_id': schoolId,
    'picture_url': null,
    'is_active': true,
  };

  _Row _route(
    int id,
    int schoolId,
    String name,
    String direction,
    String departure,
    int driverId,
    String vehicleNumber,
    String vehicleType,
    String status,
  ) => {
    'id': id,
    'school_id': schoolId,
    'name': name,
    'direction': direction,
    'planned_departure_time': departure,
    'driver_id': driverId,
    'vehicle_number': vehicleNumber,
    'vehicle_type': vehicleType,
    'status': status,
  };

  _Row _rideStudent(
    int id,
    int rideId,
    int studentId,
    int escortId,
    bool isGoing,
    int? order,
    int? eta,
    String status,
    String? boarded,
  ) => {
    'id': id,
    'ride_id': rideId,
    'student_id': studentId,
    'escort_id': escortId,
    'is_going': isGoing,
    'pickup_order': order,
    'eta_minutes': eta,
    'status': status,
    'boarded_time': boarded,
    'dropped_off_time': null,
  };

  _Row _att(
    int id,
    int rideId,
    int studentId,
    String status,
    int? by,
    String? at,
  ) => {
    'id': id,
    'ride_id': rideId,
    'student_id': studentId,
    'status': status,
    'updated_by': by,
    'updated_at': at,
  };

  // -------------------------------------------------------------- helpers
  int _nextId(List<_Row> table) {
    var maxId = 0;
    for (final row in table) {
      final id = row['id'] as int;
      if (id > maxId) maxId = id;
    }
    return maxId + 1;
  }

  /// created_at descending, newest id first on ties.
  int _newestFirst(_Row a, _Row b) {
    final c = (b['created_at'] as String? ?? '').compareTo(
      a['created_at'] as String? ?? '',
    );
    return c != 0 ? c : (b['id'] as int).compareTo(a['id'] as int);
  }

  _Row? _first(Iterable<_Row> rows) => rows.isEmpty ? null : rows.first;

  List<_Row> _sortedById(Iterable<_Row> rows) =>
      rows.toList()..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

  _Row? _byId(List<_Row> table, int id) =>
      _first(table.where((r) => r['id'] == id));

  _Row? _activeRideForRoute(int routeId) => _first(
    _sortedById(
      _rides.where((r) => r['route_id'] == routeId && r['status'] == 'active'),
    ),
  );

  _Row? _attendanceFor(int rideId, int studentId) => _first(
    _attendance.where(
      (a) => a['ride_id'] == rideId && a['student_id'] == studentId,
    ),
  );

  _Row? _rideStudentFor(int rideId, int studentId) => _first(
    _rideStudents.where(
      (r) => r['ride_id'] == rideId && r['student_id'] == studentId,
    ),
  );

  _Row _studentToDict(_Row s) => {
    'id': s['id'],
    'first_name': s['first_name'],
    'last_name': s['last_name'],
    'address': s['address'],
    'latitude': s['latitude'],
    'longitude': s['longitude'],
    'notes': s['notes'],
    'mobility_status': s['mobility_status'],
    'parent_id': s['parent_id'],
    'school_id': s['school_id'],
    'picture_url': s['picture_url'],
    'birth_date': s['birth_date'],
    'allergies': s['allergies'],
    'medical_info': s['medical_info'],
    'sensitivities': s['sensitivities'],
    'general_info': s['general_info'],
    'school_name': _byId(_schools, s['school_id'] as int)?['name'],
    'parent_name': _userName(s['parent_id'] as int?),
    'parent_phone': s['parent_id'] == null
        ? null
        : _byId(_users, s['parent_id'] as int)?['phone_number'],
  };

  String? _userName(int? id) {
    if (id == null) return null;
    final u = _byId(_users, id);
    return u == null ? null : '${u['first_name']} ${u['last_name']}';
  }

  /// Today's messages about a student, newest first.
  List<_Row> _messagesForStudents(Set<int> studentIds) {
    final today = _today;
    final rows =
        _messages
            .where(
              (m) => studentIds.contains(m['student_id']) && m['date'] == today,
            )
            .toList()
          ..sort(_newestFirst);
    return rows.map((m) {
      final student = _byId(_students, m['student_id'] as int);
      return <String, dynamic>{
        'id': m['id'],
        'student_id': m['student_id'],
        'student_name': student == null
            ? ''
            : '${student['first_name']} ${student['last_name']}',
        'author_name': m['author_name'],
        'author_role': m['author_role'],
        'text': m['text'],
        'created_at': m['created_at'],
      };
    }).toList();
  }

  /// The parent's absence report that covers today for [direction], if any.
  _Row? _activeAbsenceReport(int studentId, String? direction, String date) {
    final types = _absenceTypesForDirection(direction);
    final reports = _parentReports.where((r) {
      if (r['student_id'] != studentId) return false;
      if (!types.contains(r['report_type'])) return false;
      if (r['status'] == 'cancelled') return false;
      if ((r['start_date'] as String).compareTo(date) > 0) return false;
      final end = r['end_date'] as String?;
      return end == null || end.compareTo(date) >= 0;
    }).toList()..sort(_newestFirst);
    return reports.isEmpty ? null : reports.first;
  }

  void _addMessage(int studentId, int authorId, String text) {
    final author = _byId(_users, authorId);
    _messages.add({
      'id': _nextId(_messages),
      'student_id': studentId,
      'author_id': authorId,
      'author_name': author == null
          ? 'משתמש'
          : '${author['first_name']} ${author['last_name']}',
      'author_role': author?['role'] ?? '',
      'text': text,
      'date': _today,
      'created_at': _isoNow(),
    });
  }

  _Row _routeToDict(_Row route, int? escortId) => {
    'id': route['id'],
    'name': route['name'],
    'route_name': route['name'],
    'direction': route['direction'],
    'planned_departure_time': route['planned_departure_time'],
    'driver_id': route['driver_id'],
    'escort_id': escortId,
    'vehicle_number': route['vehicle_number'],
    'vehicle_type': route['vehicle_type'],
    'status': route['status'],
  };

  List<_Row> _assignmentsForRoute(int routeId) =>
      _sortedById(_routeAssignments.where((a) => a['route_id'] == routeId));

  int? _firstEscortForRoute(int routeId) {
    final a = _assignmentsForRoute(routeId);
    return a.isEmpty ? null : a.first['escort_id'] as int;
  }

  List<String> _absenceTypesForDirection(String? direction) {
    if (direction == 'morning')
      return ['morning_absence', 'date_range_absence'];
    if (direction == 'afternoon') {
      return ['afternoon_absence', 'date_range_absence'];
    }
    return ['morning_absence', 'afternoon_absence', 'date_range_absence'];
  }

  List<String> _directionsForReportType(String reportType) {
    switch (reportType) {
      case 'morning_absence':
        return ['morning'];
      case 'afternoon_absence':
        return ['afternoon'];
      case 'date_range_absence':
        return ['morning', 'afternoon'];
    }
    return [];
  }

  Set<int> _reportedAbsentStudentIds(
    Iterable<int> studentIds,
    String? direction,
    String targetDate,
  ) {
    final ids = studentIds.toSet();
    final types = _absenceTypesForDirection(direction);
    final result = <int>{};
    for (final r in _parentReports) {
      if (!ids.contains(r['student_id'])) continue;
      if (!types.contains(r['report_type'])) continue;
      if ((r['start_date'] as String).compareTo(targetDate) > 0) continue;
      if (r['status'] == 'cancelled') continue;
      final end = r['end_date'] as String?;
      if (end == null || end.compareTo(targetDate) >= 0) {
        result.add(r['student_id'] as int);
      }
    }
    return result;
  }

  bool _hasReportedAbsence(int studentId, String? direction, String date) =>
      _reportedAbsentStudentIds([studentId], direction, date).isNotEmpty;

  static const _absentStatuses = {'absent', 'no_show'};
  static const _boardedStatuses = {'picked_up', 'boarded', 'in_ride'};

  /// Same rules as route_routes._effective_status.
  String _routeEffectiveStatus(
    bool reportedAbsent,
    String? attendance,
    String? rideStudent,
  ) {
    final statuses = {
      for (final s in [attendance, rideStudent])
        if (s != null && s.isNotEmpty) s,
    };
    if (reportedAbsent) return 'reported_absent';
    if (statuses.any(_absentStatuses.contains)) return 'absent';
    if (statuses.contains('dropped_off')) return 'dropped_off';
    if (statuses.any(_boardedStatuses.contains)) return 'picked_up';
    return 'waiting';
  }

  /// Same rules as parent_routes._effective_status.
  String _parentEffectiveStatus(
    bool reportedAbsent,
    String? attendance,
    String? rideStudent,
  ) {
    final statuses = {
      for (final s in [attendance, rideStudent])
        if (s != null && s.isNotEmpty) s.trim().toLowerCase(),
    };
    if (reportedAbsent) return 'reported_absent';
    if (statuses.contains('dropped_off')) return 'dropped_off';
    if (statuses.any(_boardedStatuses.contains)) return 'picked_up';
    if (statuses.any(_absentStatuses.contains)) return 'absent';
    return 'waiting';
  }

  int _statusPriority(String? status) {
    switch (status) {
      case 'reported_absent':
        return 50;
      case 'dropped_off':
        return 40;
      case 'picked_up':
        return 30;
      case 'absent':
        return 20;
      case 'waiting':
        return 10;
    }
    return 0;
  }

  /// Rows of (ride, route, assignment) for active rides that include the
  /// student, ordered by ride date then ride id.
  List<List<_Row>> _activeRideRowsForStudent(
    int studentId, {
    List<String>? directions,
    int? rideId,
  }) {
    final rows = <List<_Row>>[];
    for (final ride in _rides) {
      if (ride['status'] != 'active') continue;
      if (rideId != null && ride['id'] != rideId) continue;
      final route = _byId(_routes, ride['route_id'] as int);
      if (route == null) continue;
      if (directions != null &&
          directions.isNotEmpty &&
          !directions.contains(route['direction'])) {
        continue;
      }
      for (final a in _assignmentsForRoute(route['id'] as int)) {
        if (a['student_id'] == studentId) rows.add([ride, route, a]);
      }
    }
    rows.sort((x, y) {
      final byDate = (x[0]['ride_date'] as String).compareTo(
        y[0]['ride_date'] as String,
      );
      if (byDate != 0) return byDate;
      return (x[0]['id'] as int).compareTo(y[0]['id'] as int);
    });
    return rows;
  }

  _Row _childStatusFields(int studentId) {
    final rows = _activeRideRowsForStudent(studentId);
    if (rows.isEmpty) {
      final absent = _hasReportedAbsence(studentId, null, _today);
      return {
        'attendance_status': null,
        'ride_student_status': null,
        'reported_absent_today': absent,
        'effective_status': _parentEffectiveStatus(absent, null, null),
        'route_direction': null,
        'active_ride_id': null,
        'eta_minutes': null,
      };
    }

    _Row? best;
    var bestPriority = -1;
    for (final row in rows) {
      final ride = row[0];
      final route = row[1];
      final rideId = ride['id'] as int;
      final rs = _rideStudentFor(rideId, studentId);
      final att = _attendanceFor(rideId, studentId);
      final attStatus = att?['status'] as String?;
      final rsStatus = rs?['status'] as String?;
      final absent = _hasReportedAbsence(
        studentId,
        route['direction'] as String?,
        ride['ride_date'] as String,
      );
      final effective = _parentEffectiveStatus(absent, attStatus, rsStatus);
      final data = <String, dynamic>{
        'attendance_status': attStatus,
        'ride_student_status': rsStatus,
        'reported_absent_today': absent,
        'effective_status': effective,
        'route_direction': route['direction'],
        'active_ride_id': rideId,
        'eta_minutes': rs?['eta_minutes'],
      };
      final p = _statusPriority(effective);
      if (p > bestPriority) {
        bestPriority = p;
        best = data;
      }
    }
    return best!;
  }

  List<_Row> _childrenOf(int parentId) {
    final linked = _parentStudent
        .where((l) => l['parent_id'] == parentId)
        .map((l) => l['student_id'])
        .toSet();
    return _sortedById(
      _students.where(
        (s) => s['parent_id'] == parentId || linked.contains(s['id']),
      ),
    );
  }

  bool _studentBelongsToParent(int parentId, int studentId) {
    if (_students.any(
      (s) => s['id'] == studentId && s['parent_id'] == parentId,
    )) {
      return true;
    }
    return _parentStudent.any(
      (l) => l['parent_id'] == parentId && l['student_id'] == studentId,
    );
  }

  // ------------------------------------------------------------- dispatch
  Future<DemoResponse> handle(
    String method,
    Uri url,
    Map<String, String> headers,
    List<int> bodyBytes,
  ) async {
    // Small delay so loading states look natural.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final h = <String, String>{
      for (final e in headers.entries) e.key.toLowerCase(): e.value,
    };
    _syncIn();
    try {
      final upper = method.toUpperCase();
      final result = await _dispatch(upper, url, h, bodyBytes);
      if (upper != 'GET') _syncOut();
      return DemoResponse(200, result);
    } on _HttpError catch (e) {
      return DemoResponse(e.statusCode, {'detail': e.detail});
    } on FormatException catch (e) {
      return DemoResponse(422, {'detail': 'Invalid request: ${e.message}'});
    } on TypeError catch (e) {
      return DemoResponse(422, {'detail': 'Invalid request: $e'});
    }
  }

  Map<String, dynamic> _jsonBody(List<int> bytes, Map<String, String> h) {
    if (bytes.isEmpty) return {};
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('JSON object expected');
  }

  int _userIdHeader(Map<String, String> h) {
    final v = int.tryParse(h['x-user-id'] ?? '');
    if (v == null) throw _HttpError(422, 'x-user-id header is required');
    return v;
  }

  String _roleHeader(Map<String, String> h) {
    final v = h['x-role'];
    if (v == null) throw _HttpError(422, 'x-role header is required');
    return v;
  }

  Future<Object?> _dispatch(
    String method,
    Uri url,
    Map<String, String> h,
    List<int> body,
  ) async {
    var segments = url.pathSegments.where((s) => s.isNotEmpty).toList();
    // Support a base URL with a path prefix.
    final prefix = _base.pathSegments.where((s) => s.isNotEmpty).toList();
    if (prefix.isNotEmpty &&
        segments.length >= prefix.length &&
        segments.sublist(0, prefix.length).join('/') == prefix.join('/')) {
      segments = segments.sublist(prefix.length);
    }
    final path = segments.join('/');

    int? intAt(int i) => i < segments.length ? int.tryParse(segments[i]) : null;

    if (method == 'GET' && path.isEmpty) {
      return {'message': 'Smart Ride Management API', 'version': '1.0.0'};
    }
    if (method == 'GET' && path == 'health') return {'status': 'ok'};

    if (method == 'POST' && path == 'auth/login') return _login(body, h);

    if (method == 'POST' && path == 'demo/reset') {
      _reset();
      return {'status': 'ok'};
    }

    // ---- messages
    if (method == 'POST' && path == 'messages') return _postMessage(body, h);

    // ---- attendance
    if (method == 'POST' && path == 'attendance/status') {
      return _updateAttendance(body, h);
    }
    if (method == 'GET' &&
        segments.length == 3 &&
        segments[0] == 'attendance' &&
        segments[1] == 'ride' &&
        intAt(2) != null) {
      final rideId = intAt(2)!;
      return _sortedById(
        _attendance.where((a) => a['ride_id'] == rideId),
      ).map((a) => Map<String, dynamic>.from(a)).toList();
    }

    // ---- routes
    if (segments.isNotEmpty && segments[0] == 'route') {
      if (method == 'GET' && segments.length == 1) {
        return _sortedById(_routes)
            .map((r) => _routeToDict(r, _firstEscortForRoute(r['id'] as int)))
            .toList();
      }
      if (method == 'GET' &&
          segments.length == 3 &&
          segments[1] == 'driver' &&
          intAt(2) != null) {
        final driverId = intAt(2)!;
        return _sortedById(_routes.where((r) => r['driver_id'] == driverId))
            .map((r) => _routeToDict(r, _firstEscortForRoute(r['id'] as int)))
            .toList();
      }
      if (method == 'GET' &&
          segments.length == 3 &&
          segments[1] == 'escort' &&
          intAt(2) != null) {
        final escortId = intAt(2)!;
        final routeIds = _routeAssignments
            .where((a) => a['escort_id'] == escortId)
            .map((a) => a['route_id'])
            .toSet();
        return _sortedById(
          _routes.where((r) => routeIds.contains(r['id'])),
        ).map((r) => _routeToDict(r, escortId)).toList();
      }
      if (segments.length == 3 && intAt(1) != null) {
        final routeId = intAt(1)!;
        final action = segments[2];
        if (method == 'GET' && action == 'active-ride') {
          final ride = _activeRideForRoute(routeId);
          return ride == null ? null : Map<String, dynamic>.from(ride);
        }
        if (method == 'GET' && action == 'students') {
          return _routeStudentsResponse(routeId);
        }
        if (method == 'GET' && action == 'optimize') {
          return _optimize(routeId);
        }
        if (method == 'POST' && action == 'location') {
          _userIdHeader(h);
          return _updateLocation(routeId, body, h);
        }
        if (method == 'GET' && action == 'location') {
          return _latestLocation(routeId);
        }
        if (method == 'GET' && action == 'progress') {
          return _rideProgress(routeId);
        }
        if (method == 'GET' && action == 'messages') {
          final ids = _assignmentsForRoute(
            routeId,
          ).map((a) => a['student_id'] as int).toSet();
          return _messagesForStudents(ids);
        }
      }
    }

    // ---- parent
    if (segments.isNotEmpty && segments[0] == 'parent') {
      if (method == 'GET' && path == 'parent/children') {
        final uid = _userIdHeader(h);
        _requireParent(h, 'Only parents can access this endpoint');
        return _childrenOf(uid)
            .map(
              (s) => {
                ..._studentToDict(s),
                ..._childStatusFields(s['id'] as int),
              },
            )
            .toList();
      }
      if (method == 'POST' &&
          segments.length == 4 &&
          segments[1] == 'children' &&
          segments[3] == 'picture' &&
          intAt(2) != null) {
        return _uploadPicture(intAt(2)!, body, h);
      }
      if (method == 'PUT' &&
          segments.length == 4 &&
          segments[1] == 'children' &&
          segments[3] == 'details' &&
          intAt(2) != null) {
        return _updateChildDetails(intAt(2)!, body, h);
      }
      if (method == 'GET' &&
          segments.length == 4 &&
          segments[1] == 'children' &&
          segments[3] == 'tracking' &&
          intAt(2) != null) {
        return _childTracking(intAt(2)!, h);
      }
      if (method == 'GET' && path == 'parent/messages') {
        final uid = _userIdHeader(h);
        _requireParent(h, 'Only parents can access this endpoint');
        return _messagesForStudents(
          _childrenOf(uid).map((s) => s['id'] as int).toSet(),
        );
      }
      if (method == 'POST' && path == 'parent/report') {
        return _createReport(body, h);
      }
      if (method == 'POST' && path == 'parent/report/cancel') {
        return _cancelReport(body, h);
      }
      if (method == 'GET' && path == 'parent/escorts') {
        return _parentEscorts(h);
      }
      if (method == 'GET' && path == 'parent/reports') {
        final uid = _userIdHeader(h);
        final reports =
            _parentReports.where((r) => r['parent_id'] == uid).toList()
              ..sort(_newestFirst);
        return reports.map(_reportToDict).toList();
      }
    }

    // ---- management
    if (segments.isNotEmpty && segments[0] == 'management' && method == 'GET') {
      _userIdHeader(h);
      final role = _roleHeader(h);
      if (role != 'manager' && role != 'admin') {
        throw _HttpError(403, 'Only managers can access this endpoint');
      }
      switch (path) {
        case 'management/dashboard':
          return {
            'active_rides': _rides.where((r) => r['status'] == 'active').length,
            'students': _students.length,
            'routes': _routes.length,
            'vehicles': _vehicles.length,
            'alerts': _alerts.where((a) => a['status'] == 'open').length,
            'reports': _parentReports
                .where((r) => r['status'] == 'open')
                .length,
          };
        case 'management/students':
          return _sortedById(_students).map(_studentToDict).toList();
        case 'management/routes':
          return _sortedById(_routes).map((r) {
            final assignments = _assignmentsForRoute(r['id'] as int);
            return {
              ..._routeToDict(
                r,
                assignments.isEmpty
                    ? null
                    : assignments.first['escort_id'] as int,
              ),
              'student_count': assignments.length,
            };
          }).toList();
        case 'management/reports':
          final reports = _parentReports.toList()..sort(_newestFirst);
          return reports.map(_reportToDict).toList();
        case 'management/alerts':
          final alerts = _alerts.toList()..sort(_newestFirst);
          return alerts.map((a) => Map<String, dynamic>.from(a)).toList();
        case 'management/schools':
          return _sortedById(
            _schools,
          ).map((s) => Map<String, dynamic>.from(s)).toList();
        case 'management/users':
          return _sortedById(
            _users,
          ).map((u) => Map<String, dynamic>.from(u)).toList();
      }
    }

    throw _HttpError(404, 'Not Found');
  }

  void _requireParent(Map<String, String> h, String message) {
    if (_roleHeader(h).trim().toLowerCase() != 'parent') {
      throw _HttpError(403, message);
    }
  }

  // ------------------------------------------------------------ endpoints
  Object _login(List<int> body, Map<String, String> h) {
    final email = _jsonBody(body, h)['email'];
    if (email is! String) throw const FormatException('email is required');
    final user = _first(_users.where((u) => u['email'] == email));
    if (user == null) throw _HttpError(404, 'User not found');
    return {
      'id': user['id'],
      'user_id': user['id'],
      'role': user['role'],
      'first_name': user['first_name'],
      'last_name': user['last_name'],
      'email': user['email'],
      'phone_number': user['phone_number'],
    };
  }

  static const _statusAliases = {
    'pending': 'waiting',
    'boarded': 'picked_up',
    'in_ride': 'picked_up',
    'no_show': 'absent',
  };
  static const _allowedStatuses = {
    'waiting',
    'picked_up',
    'dropped_off',
    'absent',
  };

  Object _updateAttendance(List<int> body, Map<String, String> h) {
    final uid = _userIdHeader(h);
    final role = _roleHeader(h);
    final req = _jsonBody(body, h);
    final rideId = req['ride_id'] as int;
    final studentId = req['student_id'] as int;
    final rawStatus = req['status'] as String;

    if (role != 'escort' && role != 'manager') {
      throw _HttpError(403, 'Only escorts or managers can update attendance');
    }
    final lowered = rawStatus.trim().toLowerCase();
    final status = _statusAliases[lowered] ?? lowered;
    if (!_allowedStatuses.contains(status)) {
      throw _HttpError(400, 'Unsupported attendance status: $rawStatus');
    }

    final ride = _byId(_rides, rideId);
    if (ride == null) throw _HttpError(404, 'Ride not found');

    final now = _isoNow();
    var att = _attendanceFor(rideId, studentId);
    if (att == null) {
      att = _att(_nextId(_attendance), rideId, studentId, status, uid, now);
      _attendance.add(att);
    } else {
      att['status'] = status;
      att['updated_by'] = uid;
      att['updated_at'] = now;
    }

    var rs = _rideStudentFor(rideId, studentId);
    if (rs == null) {
      final assignment = _first(
        _assignmentsForRoute(
          ride['route_id'] as int,
        ).where((a) => a['student_id'] == studentId),
      );
      rs = {
        'id': _nextId(_rideStudents),
        'ride_id': rideId,
        'student_id': studentId,
        'escort_id': assignment?['escort_id'] ?? uid,
        'is_going': true,
        'pickup_order': assignment?['default_pickup_order'],
        'eta_minutes': null,
        'status': 'waiting',
        'boarded_time': null,
        'dropped_off_time': null,
      };
      _rideStudents.add(rs);
    }
    rs['status'] = status;
    if (status == 'picked_up') {
      rs['is_going'] = true;
      rs['boarded_time'] ??= now;
    } else if (status == 'dropped_off') {
      rs['is_going'] = true;
      rs['boarded_time'] ??= now;
      rs['dropped_off_time'] ??= now;
    } else if (status == 'absent') {
      rs['is_going'] = false;
      rs['boarded_time'] = null;
      rs['dropped_off_time'] = null;
    } else if (status == 'waiting') {
      rs['is_going'] = true;
      rs['boarded_time'] = null;
      rs['dropped_off_time'] = null;
    }

    return Map<String, dynamic>.from(att);
  }

  Object _routeStudentsResponse(int routeId) {
    final route = _byId(_routes, routeId);
    if (route == null) throw _HttpError(404, 'Route not found');
    final ride = _activeRideForRoute(routeId);
    final targetDate = ride?['ride_date'] as String? ?? _today;
    final direction = route['direction'] as String?;

    // Primary source: route_assignments. Fallback: route_students.
    final entries = <_Row>[];
    final assignments = _assignmentsForRoute(routeId).toList()
      ..sort((a, b) {
        final oa = a['default_pickup_order'] as int?;
        final ob = b['default_pickup_order'] as int?;
        if (oa != ob) {
          if (oa == null) return 1;
          if (ob == null) return -1;
          return oa.compareTo(ob);
        }
        return (a['student_id'] as int).compareTo(b['student_id'] as int);
      });
    for (final a in assignments) {
      entries.add({
        'id': a['id'],
        'student_id': a['student_id'],
        'escort_id': a['escort_id'],
        'default_pickup_order': a['default_pickup_order'],
      });
    }
    if (entries.isEmpty) {
      final rs = _routeStudents.where((r) => r['route_id'] == routeId).toList()
        ..sort((a, b) {
          final oa = a['pickup_order'] as int?;
          final ob = b['pickup_order'] as int?;
          if (oa != ob) {
            if (oa == null) return 1;
            if (ob == null) return -1;
            return oa.compareTo(ob);
          }
          return (a['student_id'] as int).compareTo(b['student_id'] as int);
        });
      var index = 1;
      for (final r in rs) {
        entries.add({
          'id': index++,
          'student_id': r['student_id'],
          'escort_id': null,
          'default_pickup_order': r['pickup_order'],
        });
      }
    }

    final absentIds = _reportedAbsentStudentIds(
      entries.map((e) => e['student_id'] as int),
      direction,
      targetDate,
    );

    final result = <_Row>[];
    for (final e in entries) {
      final studentId = e['student_id'] as int;
      final student = _byId(_students, studentId);
      if (student == null) continue;
      String? attStatus;
      String? rsStatus;
      int? rsOrder;
      int? eta;
      if (ride != null) {
        final rideId = ride['id'] as int;
        attStatus = _attendanceFor(rideId, studentId)?['status'] as String?;
        final rs = _rideStudentFor(rideId, studentId);
        rsStatus = rs?['status'] as String?;
        rsOrder = rs?['pickup_order'] as int?;
        eta = rs?['eta_minutes'] as int?;
      }
      final absent = absentIds.contains(studentId);
      result.add({
        'id': e['id'],
        'route_id': routeId,
        'student_id': studentId,
        'escort_id': e['escort_id'],
        'default_pickup_order': e['default_pickup_order'],
        // Python uses `or`, so 0 falls back too.
        'pickup_order': (rsOrder == null || rsOrder == 0)
            ? e['default_pickup_order']
            : rsOrder,
        'attendance_status': attStatus,
        'ride_student_status': rsStatus,
        'reported_absent_today': absent,
        'effective_status': _routeEffectiveStatus(absent, attStatus, rsStatus),
        'route_direction': direction,
        'active_ride_id': ride?['id'],
        'eta_minutes': eta,
        'student': _studentToDict(student),
        'absence_report': () {
          if (!absent) return null;
          final report = _activeAbsenceReport(studentId, direction, targetDate);
          if (report == null) return null;
          return <String, dynamic>{
            'report_type': report['report_type'],
            'message': report['message'],
            'reported_by': _userName(report['parent_id'] as int?),
            'created_at': report['created_at'],
          };
        }(),
        'messages': _messagesForStudents({studentId}),
      });
    }
    return result;
  }

  Future<Object> _optimize(int routeId) async {
    final route = _byId(_routes, routeId);
    if (route == null) throw _HttpError(404, 'Route not found');

    var studentIds = _routeAssignments
        .where((a) => a['route_id'] == routeId)
        .map((a) => a['student_id'] as int)
        .toList();
    if (studentIds.isEmpty) {
      studentIds = _routeStudents
          .where((r) => r['route_id'] == routeId)
          .map((r) => r['student_id'] as int)
          .toList();
    }
    final students = _sortedById(
      _students.where((s) => studentIds.contains(s['id'])),
    );

    final school = students.isEmpty
        ? null
        : _byId(_schools, students.first['school_id'] as int);

    final ride = _activeRideForRoute(routeId);
    final targetDate = ride?['ride_date'] as String? ?? _today;
    final absentIds = _reportedAbsentStudentIds(
      studentIds,
      route['direction'] as String?,
      targetDate,
    );
    final active = students.where((s) => !absentIds.contains(s['id'])).toList();

    final ordered = _orderFromDepot(active);
    final legs = await _routeLegs(ordered, school);

    final stops = <_Row>[];
    var order = 1;
    for (final s in ordered) {
      stops.add({
        'student_id': s['id'],
        'student_name': '${s['first_name']} ${s['last_name']}',
        'address': s['address'],
        'latitude': s['latitude'] ?? 0,
        'longitude': s['longitude'] ?? 0,
        'pickup_order': order++,
      });
    }
    return {
      'route_id': route['id'],
      'route_name': route['name'],
      'stops': stops,
      'geometry': [for (final leg in legs) ...leg],
      // Demo extras for the driver simulation.
      'start_point': [depotLon, depotLat],
      'end_point': school == null
          ? null
          : [school['longitude'], school['latitude']],
      'school_name': school?['name'],
      'legs': legs,
    };
  }

  /// Pickup order: nearest neighbour starting from the depot; children at
  /// the same address stay together.
  List<_Row> _orderFromDepot(List<_Row> active) {
    final groups = <String, List<_Row>>{};
    for (final s in active) {
      groups.putIfAbsent(_coordKey(s), () => []).add(s);
    }
    final unique = groups.values.map((g) => g.first).toList();
    final ordered = _nearestNeighbour(unique, {
      'latitude': depotLat,
      'longitude': depotLon,
    });
    return [
      for (final u in ordered) ...groups[_coordKey(u)] ?? [u],
    ];
  }

  /// Road geometry ([[lon, lat], ...]) for depot -> each stop -> school.
  /// Uses the public OSRM server when reachable, straight lines otherwise.
  Future<List<List<List<double>>>> _routeLegs(
    List<_Row> ordered,
    _Row? school,
  ) async {
    final points = <List<double>>[
      [depotLon, depotLat],
    ];
    for (final s in ordered) {
      final p = [
        (s['longitude'] as num? ?? 0).toDouble(),
        (s['latitude'] as num? ?? 0).toDouble(),
      ];
      final last = points.last;
      if ((last[0] - p[0]).abs() < 1e-7 && (last[1] - p[1]).abs() < 1e-7) {
        continue; // same address as the previous stop
      }
      points.add(p);
    }
    if (school != null) {
      points.add([
        (school['longitude'] as num).toDouble(),
        (school['latitude'] as num).toDouble(),
      ]);
    }

    final legs = <List<List<double>>>[];
    for (var i = 0; i + 1 < points.length; i++) {
      legs.add(await _leg(points[i], points[i + 1]));
    }
    return legs;
  }

  Future<List<List<double>>> _leg(List<double> from, List<double> to) async {
    final key = '${from[0]},${from[1]};${to[0]},${to[1]}';
    final cached = _legCache[key];
    if (cached != null) return cached;

    List<List<double>> leg = [from, to];
    final fetch = fetchText;
    if (fetch != null) {
      try {
        final uri = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$key'
          '?overview=full&geometries=geojson',
        );
        final text = await fetch(uri).timeout(const Duration(seconds: 6));
        final data = text == null ? null : jsonDecode(text);
        final routes = data is Map ? data['routes'] : null;
        final geometry =
            routes is List && routes.isNotEmpty && routes.first is Map
            ? (routes.first as Map)['geometry']
            : null;
        final coords = geometry is Map ? geometry['coordinates'] : null;
        if (coords is List && coords.length >= 2) {
          final parsed = <List<double>>[
            for (final c in coords)
              if (c is List && c.length >= 2 && c[0] is num && c[1] is num)
                [(c[0] as num).toDouble(), (c[1] as num).toDouble()],
          ];
          if (parsed.length >= 2) {
            // Make sure the leg starts and ends exactly at the stops.
            leg = [from, ...parsed, to];
          }
        }
      } catch (_) {
        // keep the straight line
      }
    }
    _legCache[key] = leg;
    return leg;
  }

  String _coordKey(_Row s) {
    final lat = ((s['latitude'] as num? ?? 0) * 1e6).round();
    final lon = ((s['longitude'] as num? ?? 0) * 1e6).round();
    return '$lat,$lon';
  }

  List<_Row> _nearestNeighbour(List<_Row> stops, _Row? school) {
    var curLat = (school?['latitude'] as num? ?? 0).toDouble();
    var curLon = (school?['longitude'] as num? ?? 0).toDouble();
    final remaining = stops.toList();
    final ordered = <_Row>[];
    while (remaining.isNotEmpty) {
      _Row? best;
      var bestDist = double.infinity;
      for (final s in remaining) {
        final dLat = (s['latitude'] as num? ?? 0).toDouble() - curLat;
        final dLon = (s['longitude'] as num? ?? 0).toDouble() - curLon;
        final d = dLat * dLat + dLon * dLon;
        if (d < bestDist) {
          bestDist = d;
          best = s;
        }
      }
      ordered.add(best!);
      remaining.remove(best);
      curLat = (best['latitude'] as num? ?? 0).toDouble();
      curLon = (best['longitude'] as num? ?? 0).toDouble();
    }
    return ordered;
  }

  Object _updateLocation(int routeId, List<int> body, Map<String, String> h) {
    final req = _jsonBody(body, h);
    final lat = (req['latitude'] as num).toDouble();
    final lon = (req['longitude'] as num).toDouble();
    final ride = _activeRideForRoute(routeId);
    if (ride == null) throw _HttpError(404, 'No active ride for this route');
    final now = _isoNow();
    final loc = {
      'id': _nextId(_rideLocations),
      'ride_id': ride['id'],
      'latitude': lat,
      'longitude': lon,
      'recorded_at': now,
    };
    _rideLocations.add(loc);
    // Keep memory small during long demo drives.
    if (_rideLocations.length > 500) _rideLocations.removeAt(0);
    ride['current_latitude'] = lat;
    ride['current_longitude'] = lon;
    ride['last_location_update'] = now;

    // Demo extras: where the simulated drive is, so it can resume and so the
    // escort can see who the driver is waiting for.
    final progressIndex = req['progress_index'];
    final simState = req['sim_state'];
    if (progressIndex is int || simState is String) {
      _progress.removeWhere((p) => p['route_id'] == routeId);
      _progress.add({
        'id': routeId,
        'route_id': routeId,
        'progress_index': progressIndex is int ? progressIndex : 0,
        'sim_state': simState is String ? simState : 'driving',
        'waiting_student_ids':
            (req['waiting_student_ids'] as List?)?.whereType<int>().toList() ??
            <int>[],
        'updated_at': now,
      });
    }
    return {
      'ride_id': ride['id'],
      'latitude': lat,
      'longitude': lon,
      'recorded_at': now,
    };
  }

  Object _latestLocation(int routeId) {
    final ride = _activeRideForRoute(routeId);
    if (ride == null) throw _HttpError(404, 'No active ride for this route');
    final locs = _rideLocations
        .where((l) => l['ride_id'] == ride['id'])
        .toList();
    if (locs.isEmpty) throw _HttpError(404, 'No location data yet');
    final last = locs.reduce(
      (a, b) =>
          (a['recorded_at'] as String).compareTo(b['recorded_at'] as String) >=
              0
          ? a
          : b,
    );
    return {
      'ride_id': last['ride_id'],
      'latitude': last['latitude'],
      'longitude': last['longitude'],
      'recorded_at': last['recorded_at'],
    };
  }

  _Row _reportToDict(_Row r) => {
    'id': r['id'],
    'parent_id': r['parent_id'],
    'student_id': r['student_id'],
    'report_type': r['report_type'],
    'start_date': r['start_date'],
    'end_date': r['end_date'],
    'message': r['message'],
    'status': r['status'],
    'created_at': r['created_at'],
  };

  String _parseDate(Object? value, String field) {
    if (value is! String) throw FormatException('$field must be a date');
    final d = DateTime.tryParse(value);
    if (d == null) throw FormatException('$field must be a date');
    return _dateOf(d);
  }

  Object _createReport(List<int> body, Map<String, String> h) {
    final uid = _userIdHeader(h);
    _roleHeader(h);
    final req = _jsonBody(body, h);
    final studentId = req['student_id'] as int;
    final reportType = req['report_type'] as String;
    var startDate = _parseDate(req['start_date'], 'start_date');
    String? endDate = req['end_date'] == null
        ? null
        : _parseDate(req['end_date'], 'end_date');
    final message = req['message'] as String?;

    _requireParent(h, 'Only parents can submit reports');
    if (!_studentBelongsToParent(uid, studentId)) {
      throw _HttpError(
        403,
        'Student $studentId does not belong to parent $uid',
      );
    }

    final directions = _directionsForReportType(reportType);
    final rows = _activeRideRowsForStudent(studentId, directions: directions);
    if (rows.isNotEmpty) {
      startDate = rows.first[0]['ride_date'] as String;
      if (reportType != 'date_range_absence') endDate = null;
    }

    final report = <String, dynamic>{
      'id': _nextId(_parentReports),
      'parent_id': uid,
      'student_id': studentId,
      'report_type': reportType,
      'start_date': startDate,
      'end_date': endDate,
      'message': message,
      'status': 'open',
      'created_at': _isoNow(),
    };
    _parentReports.add(report);

    const typeLabels = {
      'morning_absence': 'לא יגיע/תגיע בבוקר',
      'afternoon_absence': 'לא צריך/ה הסעה חזור',
      'date_range_absence': 'היעדרות לכמה ימים',
    };
    final label = typeLabels[reportType] ?? 'היעדרות';
    _addMessage(
      studentId,
      uid,
      'דיווח היעדרות ($label)'
      '${message == null || message.trim().isEmpty ? '' : ': ${message.trim()}'}',
    );

    _applyAbsence(uid, studentId, directions, startDate, endDate ?? startDate);
    return _reportToDict(report);
  }

  void _applyAbsence(
    int parentId,
    int studentId,
    List<String> directions,
    String start,
    String end,
  ) {
    if (directions.isEmpty) return;
    final now = _isoNow();
    for (final row in _activeRideRowsForStudent(
      studentId,
      directions: directions,
    )) {
      final ride = row[0];
      final assignment = row[2];
      final date = ride['ride_date'] as String;
      if (date.compareTo(start) < 0 || date.compareTo(end) > 0) continue;
      final rideId = ride['id'] as int;

      final att = _attendanceFor(rideId, studentId);
      if (att == null) {
        _attendance.add(
          _att(
            _nextId(_attendance),
            rideId,
            studentId,
            'absent',
            parentId,
            now,
          ),
        );
      } else {
        att['status'] = 'absent';
        att['updated_by'] = parentId;
        att['updated_at'] = now;
      }

      final rs = _rideStudentFor(rideId, studentId);
      if (rs == null) {
        _rideStudents.add({
          'id': _nextId(_rideStudents),
          'ride_id': rideId,
          'student_id': studentId,
          'escort_id': assignment['escort_id'],
          'is_going': false,
          'pickup_order': assignment['default_pickup_order'],
          'eta_minutes': null,
          'status': 'absent',
          'boarded_time': null,
          'dropped_off_time': null,
        });
      } else {
        rs['is_going'] = false;
        rs['status'] = 'absent';
        rs['boarded_time'] = null;
        rs['dropped_off_time'] = null;
      }
    }
  }

  Object _cancelReport(List<int> body, Map<String, String> h) {
    final uid = _userIdHeader(h);
    _roleHeader(h);
    final req = _jsonBody(body, h);
    final studentId = req['student_id'] as int;
    final rideId = req['ride_id'] as int?;

    _requireParent(h, 'Only parents can cancel absence reports');
    if (!_studentBelongsToParent(uid, studentId)) {
      throw _HttpError(
        403,
        'Student $studentId does not belong to parent $uid',
      );
    }

    final rows = _activeRideRowsForStudent(studentId, rideId: rideId);
    if (rows.isEmpty) {
      throw _HttpError(404, 'לא נמצאה הסעה פעילה עבור הילד');
    }

    final beforeDeparture = <List<_Row>>[];
    for (final row in rows) {
      if (!enforceDepartureTime) {
        beforeDeparture.add(row);
        continue;
      }
      final departure = DateTime.tryParse(
        '${row[0]['ride_date']}T${row[1]['planned_departure_time']}',
      );
      if (departure == null) continue;
      if (_now.isBefore(departure)) beforeDeparture.add(row);
    }
    if (beforeDeparture.isEmpty) {
      throw _HttpError(
        400,
        'אי אפשר לעדכן שהילד יגיע, כי שעת יציאת ההסעה כבר עברה',
      );
    }

    final rideDates = beforeDeparture
        .map((r) => r[0]['ride_date'] as String)
        .toList();
    const absenceTypes = {
      'morning_absence',
      'afternoon_absence',
      'date_range_absence',
    };
    final reports = _parentReports
        .where(
          (r) =>
              r['parent_id'] == uid &&
              r['student_id'] == studentId &&
              absenceTypes.contains(r['report_type']) &&
              r['status'] != 'cancelled',
        )
        .toList();

    var cancelled = 0;
    for (final r in reports) {
      final start = r['start_date'] as String;
      final end = r['end_date'] as String? ?? start;
      if (rideDates.any(
        (d) => start.compareTo(d) <= 0 && d.compareTo(end) <= 0,
      )) {
        r['status'] = 'cancelled';
        cancelled++;
      }
    }
    if (cancelled == 0) {
      for (final r in reports) {
        r['status'] = 'cancelled';
        cancelled++;
      }
    }

    final now = _isoNow();
    final updated = <int>[];
    for (final row in beforeDeparture) {
      final ride = row[0];
      final assignment = row[2];
      final rid = ride['id'] as int;
      final att = _attendanceFor(rid, studentId);
      if (att == null) {
        _attendance.add(
          _att(_nextId(_attendance), rid, studentId, 'waiting', uid, now),
        );
      } else {
        att['status'] = 'waiting';
        att['updated_by'] = uid;
        att['updated_at'] = now;
      }
      final rs = _rideStudentFor(rid, studentId);
      if (rs == null) {
        _rideStudents.add({
          'id': _nextId(_rideStudents),
          'ride_id': rid,
          'student_id': studentId,
          'escort_id': assignment['escort_id'],
          'is_going': true,
          'pickup_order': assignment['default_pickup_order'],
          'eta_minutes': null,
          'status': 'waiting',
          'boarded_time': null,
          'dropped_off_time': null,
        });
      } else {
        rs['is_going'] = true;
        rs['status'] = 'waiting';
        rs['boarded_time'] = null;
        rs['dropped_off_time'] = null;
      }
      updated.add(rid);
    }

    _addMessage(studentId, uid, 'עדכון מההורה: הילד/ה כן מגיע/ה היום להסעה');

    return {
      'message': 'הדיווח בוטל והילד סומן כמגיע להסעה',
      'student_id': studentId,
      'updated_ride_ids': updated,
      'cancelled_reports_count': cancelled,
    };
  }

  Object _parentEscorts(Map<String, String> h) {
    final uid = _userIdHeader(h);
    _requireParent(h, 'Only parents can access escort contacts');
    final childIds = _childrenOf(uid).map((s) => s['id'] as int).toSet();
    if (childIds.isEmpty) return <Object>[];

    final rows = <List<_Row>>[];
    for (final a in _routeAssignments) {
      if (!childIds.contains(a['student_id'])) continue;
      final escort = _byId(_users, a['escort_id'] as int);
      final student = _byId(_students, a['student_id'] as int);
      final route = _byId(_routes, a['route_id'] as int);
      if (escort == null || student == null || route == null) continue;
      if (escort['role'] != 'escort') continue;
      rows.add([escort, student, route]);
    }
    rows.sort((x, y) {
      for (var i = 0; i < 3; i++) {
        final c = (x[i]['id'] as int).compareTo(y[i]['id'] as int);
        if (c != 0) return c;
      }
      return 0;
    });

    final byKey = <String, _Row>{};
    for (final row in rows) {
      final escort = row[0];
      final student = row[1];
      final route = row[2];
      final key = '${escort['id']}-${student['id']}';
      final item = byKey.putIfAbsent(
        key,
        () => {
          'escort_id': escort['id'],
          'first_name': escort['first_name'],
          'last_name': escort['last_name'],
          'phone_number': escort['phone_number'],
          'email': escort['email'],
          'student_id': student['id'],
          'student_name': '${student['first_name']} ${student['last_name']}',
          'route_id': route['id'],
          'route_name': route['name'],
          'direction': route['direction'],
          'routes': <Object>[],
          'route_names': <String>[],
        },
      );
      (item['routes'] as List<Object>).add({
        'route_id': route['id'],
        'route_name': route['name'],
        'direction': route['direction'],
      });
      (item['route_names'] as List<String>).add(route['name'] as String);
    }

    return byKey.values.map((item) {
      final names = <String>[];
      for (final n in item['route_names'] as List<String>) {
        if (!names.contains(n)) names.add(n);
      }
      item['route_name'] = names.join(' / ');
      return item;
    }).toList();
  }

  // ------------------------------------------------------- demo extras
  Object _postMessage(List<int> body, Map<String, String> h) {
    final uid = _userIdHeader(h);
    final role = _roleHeader(h).trim().toLowerCase();
    final req = _jsonBody(body, h);
    final studentId = req['student_id'] as int;
    final text = (req['text'] as String? ?? '').trim();
    if (text.isEmpty) throw _HttpError(400, 'ההודעה ריקה');
    if (text.length > 500) throw _HttpError(400, 'ההודעה ארוכה מדי');
    if (_byId(_students, studentId) == null) {
      throw _HttpError(404, 'Student not found');
    }
    if (role == 'parent' && !_studentBelongsToParent(uid, studentId)) {
      throw _HttpError(
        403,
        'Student $studentId does not belong to parent $uid',
      );
    }
    _addMessage(studentId, uid, text);
    return _messagesForStudents({studentId}).first;
  }

  Object _rideProgress(int routeId) {
    final ride = _activeRideForRoute(routeId);
    final p = _first(_progress.where((x) => x['route_id'] == routeId));
    return {
      'route_id': routeId,
      'ride_id': ride?['id'],
      'progress_index': p?['progress_index'] ?? 0,
      'sim_state': p?['sim_state'] ?? 'not_started',
      'waiting_student_ids': p?['waiting_student_ids'] ?? <int>[],
      'latitude': ride?['current_latitude'],
      'longitude': ride?['current_longitude'],
      'updated_at': p?['updated_at'],
    };
  }

  Object _updateChildDetails(
    int studentId,
    List<int> body,
    Map<String, String> h,
  ) {
    final uid = _userIdHeader(h);
    _requireParent(h, 'Only parents can update child details');
    if (!_studentBelongsToParent(uid, studentId)) {
      throw _HttpError(
        403,
        'Student $studentId does not belong to parent $uid',
      );
    }
    final student = _byId(_students, studentId);
    if (student == null) throw _HttpError(404, 'Student not found');
    final req = _jsonBody(body, h);
    const fields = [
      'allergies',
      'medical_info',
      'sensitivities',
      'general_info',
    ];
    for (final f in fields) {
      if (!req.containsKey(f)) continue;
      final v = req[f];
      if (v != null && v is! String) throw FormatException('$f must be text');
      final text = (v as String? ?? '').trim();
      if (text.length > 500) throw _HttpError(400, 'הטקסט ארוך מדי');
      student[f] = text;
    }
    if (req.containsKey('birth_date')) {
      final v = req['birth_date'];
      student['birth_date'] = v == null || (v is String && v.trim().isEmpty)
          ? null
          : _parseDate(v, 'birth_date');
    }
    return {..._studentToDict(student), ..._childStatusFields(studentId)};
  }

  double _metersBetween(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return 2 * r * atan2(sqrt(a), sqrt(1 - a));
  }

  Object _childTracking(int studentId, Map<String, String> h) {
    final uid = _userIdHeader(h);
    _requireParent(h, 'Only parents can track rides');
    if (!_studentBelongsToParent(uid, studentId)) {
      throw _HttpError(
        403,
        'Student $studentId does not belong to parent $uid',
      );
    }
    final student = _byId(_students, studentId)!;
    final status = _childStatusFields(studentId);
    final rows = _activeRideRowsForStudent(studentId);
    final home = {
      'latitude': student['latitude'],
      'longitude': student['longitude'],
    };
    if (rows.isEmpty) {
      return {
        'has_ride': false,
        'effective_status': status['effective_status'],
        'home': home,
      };
    }
    final ride = rows.first[0];
    final route = rows.first[1];
    final school = _byId(_schools, route['school_id'] as int);
    final busLat = (ride['current_latitude'] as num?)?.toDouble();
    final busLon = (ride['current_longitude'] as num?)?.toDouble();
    final effective = status['effective_status'] as String?;
    final progress = _first(
      _progress.where((p) => p['route_id'] == route['id']),
    );

    int? eta;
    String? etaTarget;
    if (busLat != null && busLon != null) {
      double? tLat;
      double? tLon;
      if (effective == 'waiting') {
        etaTarget = 'home';
        tLat = (student['latitude'] as num).toDouble();
        tLon = (student['longitude'] as num).toDouble();
      } else if (effective == 'picked_up' && school != null) {
        etaTarget = 'school';
        tLat = (school['latitude'] as num).toDouble();
        tLon = (school['longitude'] as num).toDouble();
      }
      if (tLat != null && tLon != null) {
        // City driving ~20 km/h, plus a minute per stop on the way.
        final meters = _metersBetween(busLat, busLon, tLat, tLon);
        eta = (meters / 330).ceil();
        if (eta < 1) eta = 1;
      }
    }

    return {
      'has_ride': true,
      'route_id': route['id'],
      'route_name': route['name'],
      'direction': route['direction'],
      'effective_status': effective,
      'ride_started': busLat != null,
      'sim_state': progress?['sim_state'] ?? 'not_started',
      'bus': busLat == null
          ? null
          : {
              'latitude': busLat,
              'longitude': busLon,
              'updated_at': ride['last_location_update'],
            },
      'home': home,
      'school': school == null
          ? null
          : {
              'name': school['name'],
              'latitude': school['latitude'],
              'longitude': school['longitude'],
            },
      'eta_minutes': eta,
      'eta_target': etaTarget,
    };
  }

  // ------------------------------------------------------ picture upload
  Object _uploadPicture(int studentId, List<int> body, Map<String, String> h) {
    final uid = _userIdHeader(h);
    _requireParent(h, 'Only parents can upload child pictures');
    if (!_studentBelongsToParent(uid, studentId)) {
      throw _HttpError(
        403,
        'Student $studentId does not belong to parent $uid',
      );
    }
    final student = _byId(_students, studentId);
    if (student == null) throw _HttpError(404, 'Student not found');

    final file = _extractMultipartFile(body, h['content-type'] ?? '');
    if (file == null || file.value.isEmpty) {
      throw _HttpError(400, 'Image file is empty');
    }
    const allowed = {'image/jpeg', 'image/png', 'image/webp'};
    if (!allowed.contains(file.key)) {
      throw _HttpError(400, 'Only JPG, PNG, and WebP images are supported');
    }
    if (file.value.length > 5 * 1024 * 1024) {
      throw _HttpError(400, 'Image file must be smaller than 5MB');
    }

    // Instead of Cloudinary, keep the picture in memory as a data URL.
    student['picture_url'] =
        'data:${file.key};base64,${base64Encode(file.value)}';
    return {..._studentToDict(student), ..._childStatusFields(studentId)};
  }

  /// Returns (content type, bytes) of the "file" part, or null.
  MapEntry<String, List<int>>? _extractMultipartFile(
    List<int> body,
    String contentType,
  ) {
    final match = RegExp(r'boundary=("?)([^";]+)\1').firstMatch(contentType);
    if (match == null) return null;
    final boundary = ascii.encode('--${match.group(2)}');
    const headerEnd = [13, 10, 13, 10]; // \r\n\r\n

    var pos = _indexOf(body, boundary, 0);
    while (pos >= 0) {
      final partStart = pos + boundary.length;
      final next = _indexOf(body, boundary, partStart);
      if (next < 0) break;
      final hdrEnd = _indexOf(body, headerEnd, partStart);
      if (hdrEnd >= 0 && hdrEnd < next) {
        final headerText = latin1
            .decode(body.sublist(partStart, hdrEnd))
            .toLowerCase();
        if (headerText.contains('name="file"')) {
          final typeMatch = RegExp(
            r'content-type:\s*([^\r\n;]+)',
          ).firstMatch(headerText);
          var dataEnd = next;
          // Strip the \r\n before the next boundary.
          if (dataEnd >= 2 &&
              body[dataEnd - 2] == 13 &&
              body[dataEnd - 1] == 10) {
            dataEnd -= 2;
          }
          final bytes = body.sublist(hdrEnd + headerEnd.length, dataEnd);
          return MapEntry(
            typeMatch?.group(1)?.trim() ?? 'application/octet-stream',
            bytes,
          );
        }
      }
      pos = next;
    }
    return null;
  }

  int _indexOf(List<int> data, List<int> pattern, int start) {
    outer:
    for (var i = start; i <= data.length - pattern.length; i++) {
      for (var j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }
}
