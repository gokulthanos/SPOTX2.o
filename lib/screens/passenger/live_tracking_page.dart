import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_service.dart';
import '../../models/bus.dart';

class LiveTrackingPage extends StatefulWidget {
  final int busId;
  const LiveTrackingPage({super.key, required this.busId});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  Bus? _bus;
  bool _loading = true;
  String _error = '';
  Timer? _pollingTimer;

  // Google Maps controllers
  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadBus(initial: true);
    // Poll the backend every 8 seconds for real-time coordinates / ETA changes
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadBus(initial: false));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBus({required bool initial}) async {
    if (initial && mounted) {
      setState(() => _loading = true);
    }
    try {
      final bus = await ApiService.fetchBusDetails(widget.busId);
      if (!mounted) return;
      setState(() {
        _bus = bus;
        _loading = false;
        _updateMapData(bus);
      });
    } catch (e) {
      if (initial && mounted) {
        setState(() {
          _error = 'Failed to load live bus position';
          _loading = false;
        });
      }
    }
  }

  void _updateMapData(Bus bus) async {
    // Default fallback coordinates if GPS coordinate is zero
    double busLat = bus.lat != 0 ? bus.lat : 13.0674;
    double busLon = bus.lon != 0 ? bus.lon : 80.2078;

    final busPos = LatLng(busLat, busLon);

    setState(() {
      _markers.clear();
      _polylines.clear();

      // 1. Add Live Bus Marker
      _markers.add(
        Marker(
          markerId: const MarkerId('live_bus'),
          position: busPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Bus #${bus.busNumber}', snippet: '${bus.travelStatus} - Delay: ${bus.delayMinutes}m'),
        ),
      );

      // 2. Add Stop Markers and draw route polyline
      final List<LatLng> polylinePoints = [];
      for (int i = 0; i < bus.stops.length; i++) {
        final stop = bus.stops[i];
        
        // Mocking coordinates along a linear path from Chennai (13.08) to Madurai (9.92) for visual feedback
        double stopLat = 13.0827 - (i * 0.7);
        double stopLon = 80.2707 - (i * 0.5);
        final stopPos = LatLng(stopLat, stopLon);
        polylinePoints.add(stopPos);

        final isCurrent = i == bus.currentStopIndex;

        _markers.add(
          Marker(
            markerId: MarkerId('stop_$i'),
            position: stopPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isCurrent ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen
            ),
            infoWindow: InfoWindow(title: stop.name, snippet: 'Arrival: ${stop.arrival}'),
          ),
        );
      }

      // Draw polyline connecting stops
      if (polylinePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route_path'),
            points: polylinePoints,
            color: const Color(0xFF4F46E5),
            width: 4,
          ),
        );
      }
    });

    // Move map camera to focus on live bus position
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(busPos, 11));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Live Tracking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20)),
            child: const Row(
              children: [
                Icon(Icons.circle, size: 6, color: Color(0xFFEF4444)),
                SizedBox(width: 4),
                Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFEF4444), letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2))
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 60, color: Color(0xFFEF4444)),
                      const SizedBox(height: 12),
                      Text(_error, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadBus(initial: true),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _bus == null
                  ? const Center(child: Text('Bus not found'))
                  : _buildSplitView(),
    );
  }

  Widget _buildSplitView() {
    final bus = _bus!;
    
    double defaultLat = bus.lat != 0 ? bus.lat : 13.0674;
    double defaultLon = bus.lon != 0 ? bus.lon : 80.2707;

    return Stack(
      children: [
        // 1. Google Map View
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(defaultLat, defaultLon),
            zoom: 12.0,
          ),
          onMapCreated: (GoogleMapController controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
          markers: _markers,
          polylines: _polylines,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),

        // 2. Floating Live Info Card
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _buildEtaOverlayCard(),
        ),

        // 3. Collapsible Stops Panel BottomSheet
        _buildCollapsibleStopsPanel(),
      ],
    );
  }

  Widget _buildEtaOverlayCard() {
    final bus = _bus!;
    final stops = bus.stops;
    
    final nextStop = (stops.isNotEmpty && bus.currentStopIndex + 1 < stops.length)
        ? stops[bus.currentStopIndex + 1]
        : null;

    final travelStatusColor = bus.travelStatus == 'Running' ? Colors.green : Colors.grey[700]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.airport_shuttle_rounded, color: Color(0xFF4F46E5), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('#${bus.busNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E293B))),
                    const SizedBox(width: 8),
                    Text(
                      bus.travelStatus.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: travelStatusColor),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (nextStop != null)
                  Text(
                    'Next Stop: ${nextStop.name}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  )
                else
                  const Text('Approaching final destination', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (nextStop != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('ETA', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    nextStop.arrival,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF4F46E5)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleStopsPanel() {
    final bus = _bus!;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.15,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
          ),
          child: Column(
            children: [
              // Drag Indicator bar
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text('TIMELINE & STOPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1)),
                    const Spacer(),
                    Text('${bus.stops.length} Stops', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 20),
              
              // Timeline List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: bus.stops.length,
                  itemBuilder: (context, i) {
                    final stop = bus.stops[i];
                    final isPast = i < bus.currentStopIndex;
                    final isCurrent = i == bus.currentStopIndex;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline visual node
                        Column(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isPast ? const Color(0xFF22C55E) : isCurrent ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isPast ? Icons.check_rounded : Icons.circle,
                                size: isPast ? 14 : 8,
                                color: (isPast || isCurrent) ? Colors.white : const Color(0xFFCBD5E1),
                              ),
                            ),
                            if (i < bus.stops.length - 1)
                              Container(
                                width: 2,
                                height: 40,
                                color: isPast ? const Color(0xFF86EFAC) : const Color(0xFFF1F5F9),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        
                        // Stop Name details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stop.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isCurrent ? const Color(0xFF4F46E5) : isPast ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text('Arr: ${stop.arrival}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 10),
                                  Text('${stop.distance} KM', style: const TextStyle(fontSize: 9, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w700)),
                                ],
                              ),
                              if (isCurrent)
                                Container(
                                  margin: const EdgeInsets.only(top: 6, bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('ARRIVED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
