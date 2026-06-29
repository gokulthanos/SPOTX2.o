import 'passenger.dart';
import 'bus.dart';

class Ticket {
  final String ticketNumber; // also maps to ticketId
  final int? userId;
  final int busId;
  final String busNumber;
  final String fromStop;
  final String toStop;
  final double totalFare; // also maps to fare
  final String status;
  final String createdAt; // also maps to timestamp
  final String startTime;
  final String endTime;
  final List<Passenger> passengers;
  final Bus? bus;

  Ticket({
    required this.ticketNumber,
    this.userId,
    required this.busId,
    required this.busNumber,
    required this.fromStop,
    required this.toStop,
    required this.totalFare,
    required this.status,
    required this.createdAt,
    required this.startTime,
    required this.endTime,
    required this.passengers,
    this.bus,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    // Support database response formatting as well as local storage backups
    String ticketNo = json['ticketNumber'] ?? json['ticketId'] ?? '';
    
    var passengersRaw = json['passengers'];
    List<Passenger> passengersList = [];
    if (passengersRaw is List) {
      passengersList = passengersRaw.map((p) => Passenger.fromJson(p)).toList();
    }

    double fareVal = 0.0;
    if (json['totalFare'] is num) {
      fareVal = (json['totalFare'] as num).toDouble();
    } else if (json['fare'] is num) {
      fareVal = (json['fare'] as num).toDouble();
    } else if (json['fare'] is String) {
      fareVal = double.tryParse(json['fare']) ?? 0.0;
    }

    int bId = 0;
    if (json['busId'] is num) {
      bId = (json['busId'] as num).toInt();
    } else if (json['busId'] is String) {
      bId = int.tryParse(json['busId']) ?? 0;
    }

    String startT = json['startTime'] ?? json['arrivalTime'] ?? '';
    String endT = json['endTime'] ?? '';
    if (endT.isEmpty && startT.isNotEmpty) {
      // Calculate end time (3 hours later by default)
      try {
        final parts = startT.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          final minParts = parts[1].split(' ');
          int min = int.parse(minParts[0]);
          bool isPm = minParts.length > 1 && minParts[1].toUpperCase() == 'PM';
          
          if (isPm && hour < 12) hour += 12;
          if (!isPm && hour == 12) hour = 0;
          
          hour = (hour + 3) % 24;
          final suffix = hour >= 12 ? 'PM' : 'AM';
          final displayHour = hour % 12 == 0 ? 12 : hour % 12;
          endT = '${displayHour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} $suffix';
        }
      } catch (_) {
        endT = '03 Hours Later';
      }
    }

    return Ticket(
      ticketNumber: ticketNo,
      userId: json['userId'],
      busId: bId,
      busNumber: json['busNumber'] ?? '',
      fromStop: json['fromStop'] ?? '',
      toStop: json['toStop'] ?? '',
      totalFare: fareVal,
      status: json['status'] ?? 'booked',
      createdAt: json['createdAt'] ?? json['timestamp'] ?? DateTime.now().toIso8601String(),
      startTime: startT,
      endTime: endT,
      passengers: passengersList,
      bus: json['bus'] != null ? Bus.fromJson(json['bus']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticketNumber': ticketNumber,
      'ticketId': ticketNumber,
      'userId': userId,
      'busId': busId,
      'busNumber': busNumber,
      'fromStop': fromStop,
      'toStop': toStop,
      'totalFare': totalFare,
      'fare': totalFare.toString(),
      'status': status,
      'createdAt': createdAt,
      'timestamp': createdAt,
      'startTime': startTime,
      'endTime': endTime,
      'passengers': passengers.map((p) => p.toJson()).toList(),
      if (bus != null) 'bus': bus!.toJson(),
    };
  }
}
