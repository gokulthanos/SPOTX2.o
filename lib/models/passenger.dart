class Passenger {
  final String name;
  final String gender; // Male, Female, Other

  Passenger({
    required this.name,
    required this.gender,
  });

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      name: json['name'] ?? '',
      gender: json['gender'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender,
    };
  }
}
