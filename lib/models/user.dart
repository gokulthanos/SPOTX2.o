class User {
  final String name;
  final String email; // Maps to Officer ID e.g. TN58XXXMDU
  final String role;  // ADMIN or STAFF
  final String token;

  User({
    required this.name,
    required this.email,
    required this.role,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'STAFF',
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'token': token,
    };
  }
}
