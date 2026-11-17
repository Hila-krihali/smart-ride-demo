class RideRoute {
  final int id;
  final String routeName;
  final int schoolId;
  final int? escortId;
  final int? driverId;
  final int? vehicleId;
  final String direction; // morning / afternoon
  String status; // planned / active / delayed / completed

  RideRoute({
    required this.id,
    required this.routeName,
    required this.schoolId,
    this.escortId,
    this.driverId,
    this.vehicleId,
    required this.direction,
    this.status = 'planned',
  });

  factory RideRoute.fromJson(Map<String, dynamic> json) {
    return RideRoute(
      id: json['id'] as int,
      routeName: (json['route_name'] ?? json['name'] ?? '') as String,
      schoolId: (json['school_id'] as int?) ?? 0,
      escortId: json['escort_id'] as int?,
      driverId: json['driver_id'] as int?,
      vehicleId: json['vehicle_id'] as int?,
      direction: (json['direction'] ?? '') as String,
      status: (json['status'] ?? 'planned') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_name': routeName,
      'school_id': schoolId,
      'escort_id': escortId,
      'driver_id': driverId,
      'vehicle_id': vehicleId,
      'direction': direction,
      'status': status,
    };
  }
}
