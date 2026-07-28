class BusStop {
  final String name;
  final String arrival;
  final String departure;
  final double distance;

  BusStop({
    required this.name,
    this.arrival = '',
    this.departure = '',
    this.distance = 0.0,
  });

  factory BusStop.fromJson(dynamic json) {
    if (json is String) {
      return BusStop(name: json);
    }
    return BusStop(
      name: json['name'] ?? json['stop_name'] ?? '',
      arrival: json['arrival'] ?? '',
      departure: json['departure'] ?? '',
      distance: (json['distance'] is num) ? (json['distance'] as num).toDouble() : 0.0,
    );
  }
}

class Bus {
  final int id;
  final String busNumber;
  final String busType;
  final double fare;
  final int routeId;
  final String routeNumber;
  final String routeName;
  final String departureTime;
  final String arrivalTime;
  final int capacity;
  final String travelStatus;
  final String? boardingStop;
  final String? destinationStop;

  Bus({
    required this.id,
    required this.busNumber,
    this.busType = 'Normal',
    this.fare = 0,
    this.routeId = 0,
    this.routeNumber = '',
    this.routeName = '',
    this.departureTime = '',
    this.arrivalTime = '',
    this.capacity = 45,
    this.travelStatus = 'Not Started',
    this.boardingStop,
    this.destinationStop,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['bus_id'] ?? json['id'] ?? 0,
      busNumber: json['bus_number'] ?? json['busNumber'] ?? '',
      busType: json['bus_type'] ?? json['busType'] ?? 'Normal',
      fare: (json['fare'] is num) ? (json['fare'] as num).toDouble() : 0.0,
      routeId: json['route_id'] ?? 0,
      routeNumber: json['route_number'] ?? '',
      routeName: json['route_name'] ?? '',
      departureTime: json['departure_time'] ?? json['arrivalTime'] ?? '',
      arrivalTime: json['arrival_time'] ?? '',
      capacity: json['capacity'] ?? 45,
      travelStatus: json['travel_status'] ?? 'Not Started',
      boardingStop: json['boarding_stop'],
      destinationStop: json['destination_stop'],
    );
  }
}
