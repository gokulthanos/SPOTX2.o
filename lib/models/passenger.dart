class Passenger {
  final int? id;
  final String fullName;
  final String mobile;
  final String gender;
  final String? email;
  final String? dob;
  final String? emergencyContact;

  Passenger({
    this.id,
    required this.fullName,
    this.mobile = '',
    this.gender = 'Male',
    this.email,
    this.dob,
    this.emergencyContact,
  });

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      id: json['id'],
      fullName: json['full_name'] ?? json['name'] ?? '',
      mobile: json['mobile'] ?? '',
      gender: json['gender'] ?? 'Male',
      email: json['email'],
      dob: json['dob'],
      emergencyContact: json['emergency_contact'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'full_name': fullName,
      'mobile': mobile,
      'gender': gender,
      if (email != null) 'email': email,
      if (dob != null) 'dob': dob,
      if (emergencyContact != null) 'emergency_contact': emergencyContact,
    };
  }
}
