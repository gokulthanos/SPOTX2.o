class Stop {
  final int id;
  final String name;
  final double lat;
  final double lon;

  Stop({required this.id, required this.name, this.lat = 0, this.lon = 0});

  factory Stop.fromJson(Map<String, dynamic> j) => Stop(
        id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
        name: j['name'] ?? '',
        lat: (j['lat'] ?? 0).toDouble(),
        lon: (j['lon'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'lat': lat, 'lon': lon};
}
