import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadBus();
  }

  Future<void> _loadBus() async {
    setState(() => _loading = true);
    try {
      final bus = await ApiService.fetchBusDetails(widget.busId);
      if (mounted) setState(() { _bus = bus; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
                    onPressed: _loadBus,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _bus == null
            ? const Center(child: Text('Bus not found'))
            : _buildContent(),
    );
  }

  Widget _buildContent() {
    final bus = _bus!;
    final currentStop = bus.stops.isNotEmpty && bus.currentStopIndex < bus.stops.length
        ? bus.stops[bus.currentStopIndex]
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bus info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF4F46E5), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#${bus.busNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                          Text(bus.busType, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: bus.travelStatus == 'Running' ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(bus.travelStatus, style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w900,
                        color: bus.travelStatus == 'Running' ? const Color(0xFF22C55E) : const Color(0xFF64748B),
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.route_rounded, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(bus.route, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      const Spacer(),
                      const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(bus.arrivalTime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    ],
                  ),
                ),
                if (bus.delayMinutes > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        Text('Delayed by ${bus.delayMinutes} min', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Current location
          if (currentStop != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.navigation_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CURRENT LOCATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFBFD3FC), letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Text(currentStop.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Stops timeline
          if (bus.stops.isNotEmpty) ...[
            const Text('ALL STOPS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
            const SizedBox(height: 12),
            ...List.generate(bus.stops.length, (i) {
              final stop = bus.stops[i];
              final isPast = i < bus.currentStopIndex;
              final isCurrent = i == bus.currentStopIndex;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: isPast ? const Color(0xFF22C55E) : isCurrent ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isCurrent ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 8)] : [],
                        ),
                        child: Icon(
                          isPast ? Icons.check_rounded : Icons.circle,
                          size: isPast ? 14 : 8,
                          color: (isPast || isCurrent) ? Colors.white : const Color(0xFFCBD5E1),
                        ),
                      ),
                      if (i < bus.stops.length - 1)
                        Container(width: 2, height: 40, color: isPast ? const Color(0xFF86EFAC) : const Color(0xFFF1F5F9)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop.name, style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900,
                            color: isCurrent ? const Color(0xFF4F46E5) : isPast ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                          )),
                          Row(
                            children: [
                              Text('Arr: ${stop.arrival}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                              const SizedBox(width: 10),
                              Text('${stop.distance}KM', style: const TextStyle(fontSize: 9, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w700)),
                            ],
                          ),
                          if (isCurrent)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(8)),
                              child: const Text('ARRIVED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
