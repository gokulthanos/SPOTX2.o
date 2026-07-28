class PassengerUser {
  final String fullName;
  final String contact;
  final String token;

  PassengerUser({
    required this.fullName,
    required this.contact,
    required this.token,
  });

  factory PassengerUser.fromJson(Map<String, dynamic> json) {
    return PassengerUser(
      fullName: json['fullName'] ?? json['name'] ?? '',
      contact: json['contact'] ?? json['email'] ?? '',
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'contact': contact,
      'token': token,
    };
  }
}
