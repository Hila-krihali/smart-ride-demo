class AppUser {
  final int id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String email;
  final String role;
  final String? pictureUrl;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.email,
    required this.role,
    this.pictureUrl,
  });

  String get fullName => '$firstName $lastName';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] ?? json['user_id']) as int,
      firstName: (json['first_name'] ?? '') as String,
      lastName: (json['last_name'] ?? '') as String,
      phoneNumber: (json['phone_number'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      role: (json['role'] ?? '') as String,
      pictureUrl: json['picture_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'email': email,
      'role': role,
      'picture_url': pictureUrl,
    };
  }
}
