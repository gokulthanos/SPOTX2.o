class Ticket {
  final int id;
  final String pnr;
  final int busId;
  final String busNumber;
  final String boardingStopName;
  final String destinationStopName;
  final double fare;
  final double convenienceFee;
  final double platformFee;
  final double totalAmount;
  final String ticketStatus;
  final String paymentStatus;
  final String? passengerName;
  final String? journeyDate;
  final String? journeyTime;
  final String? qrData;
  final String createdAt;

  Ticket({
    required this.id,
    required this.pnr,
    required this.busId,
    required this.busNumber,
    required this.boardingStopName,
    required this.destinationStopName,
    this.fare = 0,
    this.convenienceFee = 0,
    this.platformFee = 0,
    this.totalAmount = 0,
    this.ticketStatus = 'active',
    this.paymentStatus = 'pending',
    this.passengerName,
    this.journeyDate,
    this.journeyTime,
    this.qrData,
    this.createdAt = '',
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return Ticket(
      id: json['id'] ?? 0,
      pnr: json['pnr'] ?? '',
      busId: json['bus_id'] ?? 0,
      busNumber: json['bus_number'] ?? '',
      boardingStopName: json['boarding_stop_name'] ?? '',
      destinationStopName: json['destination_stop_name'] ?? '',
      fare: toDouble(json['fare']),
      convenienceFee: toDouble(json['convenience_fee']),
      platformFee: toDouble(json['platform_fee']),
      totalAmount: toDouble(json['total_amount']),
      ticketStatus: json['ticket_status'] ?? 'active',
      paymentStatus: json['payment_status'] ?? 'pending',
      passengerName: json['passenger_name'],
      journeyDate: json['journey_date'],
      journeyTime: json['journey_time'],
      qrData: json['qr_data'],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pnr': pnr,
    'bus_id': busId,
    'bus_number': busNumber,
    'boarding_stop_name': boardingStopName,
    'destination_stop_name': destinationStopName,
    'fare': fare,
    'convenience_fee': convenienceFee,
    'platform_fee': platformFee,
    'total_amount': totalAmount,
    'ticket_status': ticketStatus,
    'payment_status': paymentStatus,
    'passenger_name': passengerName,
    'journey_date': journeyDate,
    'journey_time': journeyTime,
    'qr_data': qrData,
    'created_at': createdAt,
  };
}
