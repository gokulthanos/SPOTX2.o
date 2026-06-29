import 'dart:math';
import 'package:geolocator/geolocator.dart';

class CityConfig {
  final String name;
  final double lat;
  final double lon;

  CityConfig({required this.name, required this.lat, required this.lon});
}

class LocationService {
  static final List<CityConfig> cities = [
    CityConfig(name: 'Chennai', lat: 13.0827, lon: 80.2707),
    CityConfig(name: 'Madurai', lat: 9.9252, lon: 78.1198),
    CityConfig(name: 'Coimbatore', lat: 11.0168, lon: 76.9558),
    CityConfig(name: 'Trichy', lat: 10.7905, lon: 78.7047),
    CityConfig(name: 'Salem', lat: 11.6643, lon: 78.1460),
    CityConfig(name: 'Tirunelveli', lat: 8.7139, lon: 77.7567),
  ];

  static double _deg2rad(double deg) {
    return deg * (pi / 180.0);
  }

  static double getDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0; // Radius of Earth in KM
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static String getClosestCity(double lat, double lon) {
    CityConfig closest = cities[0];
    double minDistance = getDistance(lat, lon, cities[0].lat, cities[0].lon);

    for (var city in cities) {
      final d = getDistance(lat, lon, city.lat, city.lon);
      if (d < minDistance) {
        minDistance = d;
        closest = city;
      }
    }
    return closest.name;
  }

  static Future<String> detectCity() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Chennai'; // Default fallback
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Chennai';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return 'Chennai';
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 1000,
        ),
      );
      
      return getClosestCity(position.latitude, position.longitude);
    } catch (_) {
      return 'Chennai'; // Safe fallback
    }
  }
}
