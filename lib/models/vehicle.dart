class Vehicle {
  final int id;
  final String vehicleNumber;
  final String? vehicleType;
  final int? seatsCount;
  final bool hasAccessibility;
  final String? notes;

  Vehicle({
    required this.id,
    required this.vehicleNumber,
    this.vehicleType,
    this.seatsCount,
    this.hasAccessibility = false,
    this.notes,
  });
}
