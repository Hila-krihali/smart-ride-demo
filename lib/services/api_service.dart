import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../demo/demo_http_client.dart';
import '../models/app_user.dart';
import '../models/attendance.dart';
import '../models/ride.dart';
import '../models/ride_route.dart';
import '../models/route_student.dart';
import '../models/student.dart';

class ApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  /// In demo mode all requests are answered in-app (see lib/demo).
  static final http.Client _client = AppConfig.isDemo
      ? createDemoHttpClient(baseUrl)
      : http.Client();

  static AppUser? _currentUser;

  static AppUser? get currentUser => _currentUser;

  static bool get hasValidSession {
    final user = _currentUser;
    return user != null && user.id > 0 && user.role.isNotEmpty;
  }

  static void setCurrentUser(AppUser user) {
    if (user.id <= 0 || user.role.isEmpty) {
      throw StateError('Authenticated user must include id and role.');
    }

    _currentUser = user;
    debugPrint(
      'ApiService session stored: user_id=${user.id}, role=${user.role}',
    );
  }

  static void logout() {
    debugPrint('ApiService session cleared.');
    _currentUser = null;
  }

  static Map<String, String> _headers({int? userId, String? role}) {
    final Map<String, String> map = {'Content-Type': 'application/json'};

    if (userId != null) {
      map['x-user-id'] = userId.toString();
    }
    if (role != null) {
      map['x-role'] = role;
    }

    return map;
  }

  static Map<String, String> _authHeaders({int? userId, String? role}) {
    if (!hasValidSession) {
      throw StateError(
        'No logged-in user. Login must complete before API calls.',
      );
    }

    final resolvedUserId = userId ?? _currentUser?.id;
    final resolvedRole = role ?? _currentUser?.role;

    if (resolvedUserId == null ||
        resolvedRole == null ||
        resolvedRole.isEmpty) {
      throw StateError(
        'No logged-in user. Login must complete before API calls.',
      );
    }

    return _headers(userId: resolvedUserId, role: resolvedRole);
  }

  static Map<String, String> _multipartAuthHeaders({
    int? userId,
    String? role,
  }) {
    final headers = Map<String, String>.from(
      _authHeaders(userId: userId, role: role),
    );
    headers.remove('Content-Type');
    return headers;
  }

  static dynamic _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }

    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static String _extractErrorMessage(http.Response response) {
    try {
      final decoded = _decodeResponse(response);

      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];

        if (detail != null) {
          return detail.toString();
        }

        final message = decoded['message'];

        if (message != null) {
          return message.toString();
        }
      }
    } catch (_) {}

    return 'Request failed: ${response.statusCode} ${response.body}';
  }

  static void _validateResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response));
    }
  }

  static MediaType _mediaTypeForImage(XFile imageFile) {
    final mimeType = imageFile.mimeType;

    if (mimeType != null && mimeType.contains('/')) {
      final parts = mimeType.split('/');
      return MediaType(parts[0], parts[1]);
    }

    final extension = imageFile.name.split('.').last.toLowerCase();

    if (extension == 'png') {
      return MediaType('image', 'png');
    }

    if (extension == 'webp') {
      return MediaType('image', 'webp');
    }

    return MediaType('image', 'jpeg');
  }

  static Future<Map<String, dynamic>> healthCheck() async {
    final response = await _client.get(Uri.parse('$baseUrl/health'));
    _validateResponse(response);

    final decoded = _decodeResponse(response);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  static Future<Map<String, dynamic>> root() async {
    final response = await _client.get(Uri.parse('$baseUrl/'));
    _validateResponse(response);

    final decoded = _decodeResponse(response);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  static Future<AppUser> login({required String email}) async {
    debugPrint('ApiService login started for email=$email');

    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email}),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is Map<String, dynamic>) {
      final user = AppUser.fromJson(decoded);
      setCurrentUser(user);

      debugPrint(
        'ApiService login succeeded: user_id=${user.id}, role=${user.role}',
      );

      return user;
    }

    throw Exception('Invalid login response');
  }

  static Future<List<Student>> getParentChildren({
    required int parentId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/parent/children'),
      headers: _authHeaders(userId: parentId, role: 'parent'),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Student.fromJson)
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(Student.fromJson)
            .toList();
      }

      if (decoded['children'] is List) {
        return (decoded['children'] as List)
            .whereType<Map<String, dynamic>>()
            .map(Student.fromJson)
            .toList();
      }

      if (decoded['students'] is List) {
        return (decoded['students'] as List)
            .whereType<Map<String, dynamic>>()
            .map(Student.fromJson)
            .toList();
      }
    }

    return <Student>[];
  }

  static Future<Student> uploadParentChildPicture({
    required int studentId,
    required XFile imageFile,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/parent/children/$studentId/picture'),
    );

    request.headers.addAll(_multipartAuthHeaders(role: 'parent'));

    final bytes = await imageFile.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name,
        contentType: _mediaTypeForImage(imageFile),
      ),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is Map<String, dynamic>) {
      return Student.fromJson(decoded);
    }

    throw Exception('Invalid student picture upload response');
  }

  static Future<Map<String, dynamic>> createParentReport({
    required int studentId,
    required String reportType,
    required String startDate,
    String? endDate,
    String? message,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/parent/report'),
      headers: _authHeaders(),
      body: jsonEncode({
        'student_id': studentId,
        'report_type': reportType,
        'start_date': startDate,
        'end_date': endDate,
        'message': message,
      }),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  static Future<Map<String, dynamic>> cancelParentAbsence({
    required int studentId,
    int? rideId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/parent/report/cancel'),
      headers: _authHeaders(),
      body: jsonEncode({'student_id': studentId, 'ride_id': rideId}),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  static Future<List<dynamic>> getParentReports({required int parentId}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/parent/reports'),
      headers: _authHeaders(userId: parentId, role: 'parent'),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) {
        return decoded['data'] as List<dynamic>;
      }

      if (decoded['reports'] is List) {
        return decoded['reports'] as List<dynamic>;
      }
    }

    return [];
  }

  static Future<List<Map<String, dynamic>>> getParentEscorts({
    required int parentId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/parent/escorts'),
      headers: _authHeaders(userId: parentId, role: 'parent'),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }

    return <Map<String, dynamic>>[];
  }

  static Future<Map<String, dynamic>> updateAttendanceStatus({
    required int userId,
    required String role,
    required int rideId,
    required int studentId,
    required String status,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/attendance/status'),
      headers: _authHeaders(userId: userId, role: role),
      body: jsonEncode({
        'ride_id': rideId,
        'student_id': studentId,
        'status': status,
      }),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  static Future<List<Attendance>> getRideAttendance({
    required int userId,
    required String role,
    required int rideId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/attendance/ride/$rideId'),
      headers: _authHeaders(userId: userId, role: role),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Attendance.fromJson)
          .toList();
    }

    return [];
  }

  static Future<List<RideRoute>> getRoutesForDriver({
    required int driverId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/route/driver/$driverId'),
      headers: _authHeaders(userId: driverId, role: _currentUser?.role),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RideRoute.fromJson)
          .toList();
    }

    return <RideRoute>[];
  }

  static Future<List<RideRoute>> getRoutesForEscort({
    required int escortId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/route/escort/$escortId'),
      headers: _authHeaders(userId: escortId, role: _currentUser?.role),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RideRoute.fromJson)
          .toList();
    }

    return <RideRoute>[];
  }

  static Future<List<RideRoute>> getRoutes() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/route'),
      headers: _authHeaders(),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RideRoute.fromJson)
          .toList();
    }

    return <RideRoute>[];
  }

  static Future<Ride?> getActiveRideForRoute({required int routeId}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/route/$routeId/active-ride'),
      headers: _authHeaders(),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is Map<String, dynamic>) {
      return Ride.fromJson(decoded);
    }

    return null;
  }

  static Future<List<Student>> getRouteStudents({required int routeId}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/route/$routeId/students'),
      headers: _authHeaders(),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => Student.fromJson(row['student'] as Map<String, dynamic>),
          )
          .toList();
    }

    return <Student>[];
  }

  static Future<List<RouteStudentInfo>> getRouteStudentAssignments({
    required int routeId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/route/$routeId/students'),
      headers: _authHeaders(),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RouteStudentInfo.fromJson)
          .toList();
    }

    return <RouteStudentInfo>[];
  }

  static Future<Map<int, Attendance>> getAttendanceByStudent({
    required int userId,
    required String role,
    required int rideId,
  }) async {
    final attendance = await getRideAttendance(
      userId: userId,
      role: role,
      rideId: rideId,
    );

    return {for (final item in attendance) item.studentId: item};
  }

  static Future<Map<String, dynamic>> getManagementDashboard({
    required int userId,
    required String role,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/management/dashboard'),
      headers: _authHeaders(userId: userId, role: role),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    return decoded is Map<String, dynamic> ? decoded : {};
  }

  static Future<List<Student>> getManagementStudents({
    required int userId,
    required String role,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/management/students'),
      headers: _authHeaders(userId: userId, role: role),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Student.fromJson)
          .toList();
    }

    return <Student>[];
  }

  static Future<List<RideRoute>> getManagementRoutes({
    int? userId,
    String? role,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/management/routes'),
      headers: _authHeaders(userId: userId, role: role),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RideRoute.fromJson)
          .toList();
    }

    return <RideRoute>[];
  }

  static Future<List<dynamic>> getManagementReports({
    int? userId,
    String? role,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/management/reports'),
      headers: _authHeaders(userId: userId, role: role),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    return decoded is List ? decoded : <dynamic>[];
  }

  static Future<List<dynamic>> getManagementAlerts({
    int? userId,
    String? role,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/management/alerts'),
      headers: _authHeaders(userId: userId, role: role),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    return decoded is List ? decoded : <dynamic>[];
  }

  static Future<Map<String, dynamic>> getOptimizedRoute({
    required int userId,
    required String role,
    required int routeId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/route/$routeId/optimize'),
      headers: _authHeaders(userId: userId, role: role),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    return decoded is Map<String, dynamic> ? decoded : {};
  }

  static Future<Map<String, dynamic>> updateRouteLocation({
    required int userId,
    required String role,
    required int routeId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/route/$routeId/location'),
      headers: _authHeaders(userId: userId, role: role),
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    return decoded is Map<String, dynamic> ? decoded : {};
  }

  static Future<Map<String, dynamic>> getLatestRouteLocation({
    required int userId,
    required String role,
    required int routeId,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/route/$routeId/location'),
      headers: _authHeaders(userId: userId, role: role),
    );

    _validateResponse(response);

    final decoded = _decodeResponse(response);

    return decoded is Map<String, dynamic> ? decoded : {};
  }
}
