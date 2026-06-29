class BusStop {
  final String name;
  final String arrival;
  final String departure;
  final double distance;

  BusStop({
    required this.name,
    required this.arrival,
    required this.departure,
    required this.distance,
  });

  factory BusStop.fromJson(dynamic json) {
    if (json is String) {
      return BusStop(
        name: json,
        arrival: '',
        departure: '',
        distance: 0.0,
      );
    }
    return BusStop(
      name: json['name'] ?? '',
      arrival: json['arrival'] ?? '',
      departure: json['departure'] ?? '',
      distance: (json['distance'] is num) ? (json['distance'] as num).toDouble() : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'arrival': arrival,
      'departure': departure,
      'distance': distance,
    };
  }
}

class Bus {
  final int id;
  final String busNumber;
  final String arrivalTime;
  final double fare;
  final String route;
  final String from;
  final String to;
  final String busType; // Deluxe, Express, Normal, Mini, Mofussil, Town
  final List<BusStop> stops;
  final int currentStopIndex;
  final String travelStatus; // Not Started, Running, Arrived, Delayed
  final int delayMinutes;
  final String city;

  Bus({
    required this.id,
    required this.busNumber,
    required this.arrivalTime,
    required this.fare,
    required this.route,
    required this.from,
    required this.to,
    required this.busType,
    required this.stops,
    required this.currentStopIndex,
    required this.travelStatus,
    required this.delayMinutes,
    required this.city,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    var rawStops = json['stops'];
    List<BusStop> stopsList = [];
    if (rawStops is List) {
      stopsList = rawStops.map((s) => BusStop.fromJson(s)).toList();
    } else if (rawStops is String) {
      stopsList = rawStops.split(',').map((s) => BusStop(
        name: s.trim(),
        arrival: '',
        departure: '',
        distance: 0.0,
      )).toList();
    }

    return Bus(
      id: json['id'] ?? 0,
      busNumber: json['busNumber'] ?? '',
      arrivalTime: json['arrivalTime'] ?? '',
      fare: (json['fare'] is num) ? (json['fare'] as num).toDouble() : 0.0,
      route: json['route'] ?? '',
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      busType: json['busType'] ?? 'Normal',
      stops: stopsList,
      currentStopIndex: json['currentStopIndex'] ?? 0,
      travelStatus: json['travelStatus'] ?? 'Not Started',
      delayMinutes: json['delayMinutes'] ?? 0,
      city: json['city'] ?? 'Chennai',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'busNumber': busNumber,
      'arrivalTime': arrivalTime,
      'fare': fare,
      'route': route,
      'from': from,
      'to': to,
      'busType': busType,
      'stops': stops.map((s) => s.toJson()).toList(),
      'currentStopIndex': currentStopIndex,
      'travelStatus': travelStatus,
      'delayMinutes': delayMinutes,
      'city': city,
    };
  }
}
