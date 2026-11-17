class Alert {
  final int id;
  final int? rideId;
  final String alertType; // delay / route_deviation / long_stop / parent_report / emergency
  final String message;
  final String severity; // low / medium / high
  String status; // open / handled
  final DateTime createdAt;

  Alert({
    required this.id,
    this.rideId,
    required this.alertType,
    required this.message,
    this.severity = 'medium',
    this.status = 'open',
    required this.createdAt,
  });
}
