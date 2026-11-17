import '../models/app_user.dart';
import '../models/school.dart';
import '../models/student.dart';
import '../models/vehicle.dart';
import '../models/ride_route.dart';
import '../models/route_student.dart';
import '../models/ride.dart';
import '../models/attendance.dart';
import '../models/parent_report.dart';
import '../models/alert.dart';

class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal();

  // --- Users ---
  final List<AppUser> users = [
    AppUser(id: 1, firstName: 'שרה', lastName: 'כהן', phoneNumber: '050-1234567', email: 'sara@example.com', role: 'escort'),
    AppUser(id: 2, firstName: 'רחל', lastName: 'לוי', phoneNumber: '050-2345678', email: 'rachel@example.com', role: 'parent'),
    AppUser(id: 3, firstName: 'דוד', lastName: 'מזרחי', phoneNumber: '050-3456789', email: 'david@example.com', role: 'driver'),
    AppUser(id: 4, firstName: 'יעל', lastName: 'אברהם', phoneNumber: '050-4567890', email: 'yael@example.com', role: 'manager'),
    AppUser(id: 5, firstName: 'מיכל', lastName: 'פרץ', phoneNumber: '050-5678901', email: 'michal@example.com', role: 'parent'),
    AppUser(id: 6, firstName: 'אבי', lastName: 'גולד', phoneNumber: '050-6789012', email: 'avi@example.com', role: 'escort'),
    AppUser(id: 7, firstName: 'משה', lastName: 'ביטון', phoneNumber: '050-7890123', email: 'moshe@example.com', role: 'driver'),
  ];

  // --- Schools ---
  final List<School> schools = [
    School(id: 1, name: 'בית ספר אופק', address: 'רחוב הרצל 15, באר שבע', latitude: 31.2530, longitude: 34.7915),
    School(id: 2, name: 'מרכז חינוך מיוחד השחר', address: 'רחוב ביאליק 8, באר שבע', latitude: 31.2500, longitude: 34.7890),
  ];

  // --- Students (addresses around Beer Sheva) ---
  final List<Student> students = [
    Student(id: 1, firstName: 'יוסי', lastName: 'לוי', address: 'רחוב רגר 22, באר שבע', latitude: 31.2518, longitude: 34.7913, schoolId: 1, mobilityStatus: 'רגיל', notes: 'רגיש לרעש'),
    Student(id: 2, firstName: 'נועה', lastName: 'לוי', address: 'רחוב רגר 22, באר שבע', latitude: 31.2518, longitude: 34.7913, schoolId: 1, mobilityStatus: 'רגיל'),
    Student(id: 3, firstName: 'עומר', lastName: 'פרץ', address: 'רחוב הנשיא 5, באר שבע', latitude: 31.2545, longitude: 34.7880, schoolId: 1, mobilityStatus: 'כיסא גלגלים', notes: 'צריך מעלון'),
    Student(id: 4, firstName: 'תמר', lastName: 'דהן', address: 'שדרות בן גוריון 30, באר שבע', latitude: 31.2490, longitude: 34.7950, schoolId: 1, mobilityStatus: 'רגיל'),
    Student(id: 5, firstName: 'איתן', lastName: 'אזולאי', address: 'רחוב העצמאות 12, באר שבע', latitude: 31.2560, longitude: 34.7870, schoolId: 2, mobilityStatus: 'ליווי מיוחד', notes: 'צריך ליווי צמוד'),
    Student(id: 6, firstName: 'מאיה', lastName: 'גבאי', address: 'רחוב קרן קיימת 7, באר שבע', latitude: 31.2475, longitude: 34.7935, schoolId: 2, mobilityStatus: 'רגיל'),
  ];

  // Parent-Student relationships
  final Map<int, List<int>> parentStudents = {
    2: [1, 2], // Rachel -> Yossi, Noa
    5: [3],    // Michal -> Omer
  };

  // --- Vehicles ---
  final List<Vehicle> vehicles = [
    Vehicle(id: 1, vehicleNumber: '12-345-67', vehicleType: 'מיניבוס', seatsCount: 12, hasAccessibility: true),
    Vehicle(id: 2, vehicleNumber: '23-456-78', vehicleType: 'מיניבוס', seatsCount: 8),
  ];

  // --- Routes ---
  final List<RideRoute> routes = [
    RideRoute(id: 1, routeName: 'קו 1 - בוקר אופק', schoolId: 1, escortId: 1, driverId: 3, vehicleId: 1, direction: 'morning', status: 'active'),
    RideRoute(id: 2, routeName: 'קו 1 - צהריים אופק', schoolId: 1, escortId: 1, driverId: 3, vehicleId: 1, direction: 'afternoon', status: 'planned'),
    RideRoute(id: 3, routeName: 'קו 2 - בוקר השחר', schoolId: 2, escortId: 6, driverId: 7, vehicleId: 2, direction: 'morning', status: 'planned'),
  ];

  // --- Route-Student assignments ---
  final List<RouteStudent> routeStudents = [
    RouteStudent(routeId: 1, studentId: 1, pickupOrder: 1, plannedPickupTime: '07:30'),
    RouteStudent(routeId: 1, studentId: 2, pickupOrder: 2, plannedPickupTime: '07:30'),
    RouteStudent(routeId: 1, studentId: 3, pickupOrder: 3, plannedPickupTime: '07:40'),
    RouteStudent(routeId: 1, studentId: 4, pickupOrder: 4, plannedPickupTime: '07:50'),
    RouteStudent(routeId: 2, studentId: 1, pickupOrder: 1, plannedPickupTime: '14:00'),
    RouteStudent(routeId: 2, studentId: 2, pickupOrder: 2, plannedPickupTime: '14:00'),
    RouteStudent(routeId: 2, studentId: 3, pickupOrder: 3, plannedPickupTime: '14:10'),
    RouteStudent(routeId: 2, studentId: 4, pickupOrder: 4, plannedPickupTime: '14:20'),
    RouteStudent(routeId: 3, studentId: 5, pickupOrder: 1, plannedPickupTime: '07:45'),
    RouteStudent(routeId: 3, studentId: 6, pickupOrder: 2, plannedPickupTime: '07:55'),
  ];

  // --- Today's Rides ---
  late List<Ride> rides = [
    Ride(id: 1, routeId: 1, rideDate: DateTime.now(), status: 'active', startTime: DateTime.now().subtract(const Duration(minutes: 15))),
    Ride(id: 2, routeId: 2, rideDate: DateTime.now(), status: 'planned'),
    Ride(id: 3, routeId: 3, rideDate: DateTime.now(), status: 'planned'),
  ];

  // --- Attendance ---
  late List<Attendance> attendances = [
    Attendance(id: 1, rideId: 1, studentId: 1, status: 'picked_up', updatedBy: 1, updatedAt: DateTime.now().subtract(const Duration(minutes: 10))),
    Attendance(id: 2, rideId: 1, studentId: 2, status: 'picked_up', updatedBy: 1, updatedAt: DateTime.now().subtract(const Duration(minutes: 10))),
    Attendance(id: 3, rideId: 1, studentId: 3, status: 'waiting'),
    Attendance(id: 4, rideId: 1, studentId: 4, status: 'waiting'),
  ];

  // --- Parent Reports ---
  final List<ParentReport> parentReports = [
    ParentReport(
      id: 1,
      parentId: 5,
      studentId: 3,
      reportType: 'morning_absence',
      startDate: DateTime.now(),
      message: 'עומר לא מרגיש טוב, לא יגיע היום',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  // --- Alerts ---
  final List<Alert> alerts = [
    Alert(id: 1, rideId: 1, alertType: 'delay', message: 'קו 1 בוקר - איחור של 5 דקות', severity: 'low', createdAt: DateTime.now().subtract(const Duration(minutes: 5))),
    Alert(id: 2, rideId: null, alertType: 'parent_report', message: 'עומר פרץ - דיווח היעדרות מהורה', severity: 'medium', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
  ];

  // --- Helper Methods ---

  AppUser? getUserById(int id) => users.where((u) => u.id == id).firstOrNull;

  List<AppUser> getUsersByRole(String role) => users.where((u) => u.role == role).toList();

  Student? getStudentById(int id) => students.where((s) => s.id == id).firstOrNull;

  List<Student> getStudentsForRoute(int routeId) {
    final studentIds = routeStudents
        .where((rs) => rs.routeId == routeId)
        .toList()
      ..sort((a, b) => a.pickupOrder.compareTo(b.pickupOrder));
    return studentIds.map((rs) => getStudentById(rs.studentId)).whereType<Student>().toList();
  }

  List<Student> getStudentsForParent(int parentId) {
    final studentIds = parentStudents[parentId] ?? [];
    return studentIds.map((id) => getStudentById(id)).whereType<Student>().toList();
  }

  RideRoute? getRouteForEscort(int escortId) => routes.where((r) => r.escortId == escortId).firstOrNull;

  RideRoute? getRouteForDriver(int driverId) => routes.where((r) => r.driverId == driverId).firstOrNull;

  Ride? getActiveRideForRoute(int routeId) => rides.where((r) => r.routeId == routeId && r.status == 'active').firstOrNull;

  List<Attendance> getAttendanceForRide(int rideId) => attendances.where((a) => a.rideId == rideId).toList();

  Attendance? getAttendanceForStudent(int rideId, int studentId) =>
      attendances.where((a) => a.rideId == rideId && a.studentId == studentId).firstOrNull;

  void updateAttendanceStatus(int rideId, int studentId, String newStatus, int updatedBy) {
    final attendance = getAttendanceForStudent(rideId, studentId);
    if (attendance != null) {
      attendance.status = newStatus;
      attendance.updatedBy = updatedBy;
      attendance.updatedAt = DateTime.now();
    }
  }

  School? getSchoolById(int id) => schools.where((s) => s.id == id).firstOrNull;

  Vehicle? getVehicleById(int id) => vehicles.where((v) => v.id == id).firstOrNull;

  void addParentReport(ParentReport report) {
    parentReports.add(report);
    alerts.add(Alert(
      id: alerts.length + 1,
      alertType: 'parent_report',
      message: 'דיווח חדש מהורה: ${report.message ?? report.reportType}',
      severity: 'medium',
      createdAt: DateTime.now(),
    ));
  }

  // GPS simulation points for route 1 (Beer Sheva area)
  List<List<double>> getSimulatedRoutePoints() {
    return [
      [31.2480, 34.7900], // Start
      [31.2490, 34.7905],
      [31.2500, 34.7910],
      [31.2510, 34.7913], // Near student 1&2
      [31.2518, 34.7913], // Pickup student 1&2
      [31.2525, 34.7905],
      [31.2535, 34.7895],
      [31.2545, 34.7880], // Pickup student 3
      [31.2540, 34.7890],
      [31.2530, 34.7920],
      [31.2510, 34.7940],
      [31.2490, 34.7950], // Pickup student 4
      [31.2500, 34.7940],
      [31.2515, 34.7925],
      [31.2530, 34.7915], // Arrive at school
    ];
  }
}
