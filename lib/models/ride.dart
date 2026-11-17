class Ride {
  final int id;
  final int routeId;
  final DateTime rideDate;
  DateTime? startTime;
  DateTime? endTime;
  String status; // planned / active / completed / cancelled

  Ride({
    required this.id,
    required this.routeId,
    required this.rideDate,
    this.startTime,
    this.endTime,
    this.status = 'planned',
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] as int,
      routeId: json['route_id'] as int,
      rideDate: DateTime.parse(json['ride_date'] as String),
      startTime: json['start_time'] == null
          ? null
          : DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] == null
          ? null
          : DateTime.parse(json['end_time'] as String),
      status: (json['status'] ?? 'planned') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_id': routeId,
      'ride_date': rideDate.toIso8601String().split('T').first,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status,
    };
  }
}
