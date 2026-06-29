import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../models/bus.dart';
import 'book_ride_page.dart';
import 'live_tracking_page.dart';

class BusSearchPage extends StatefulWidget {
  const BusSearchPage({super.key});

  @override
  State<BusSearchPage> createState() => _BusSearchPageState();
}

class _BusSearchPageState extends State<BusSearchPage> {
  String _detectedCity = 'Chennai';
  bool _isLocating = true;
  bool _loading = true;
  List<Bus> _buses = [];
  String _selectedFrom = '';
  String _selectedTo = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final city = await LocationService.detectCity();
    if (mounted) setState(() { _detectedCity = city; _isLocating = false; });
    await _fetchBuses(city);
  }

  Future<void> _fetchBuses(String city) async {
    setState(() => _loading = true);
    try {
      final buses = await ApiService.fetchBuses(city: city);
      if (mounted) setState(() => _buses = buses);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _fromOptions {
    return _buses.map((b) => b.from).toSet().toList()..sort();
  }

  List<String> get _toOptions {
    if (_selectedFrom.isEmpty) return [];
    return _buses.where((b) => b.from == _selectedFrom).map((b) => b.to).toSet().toList()..sort();
  }

  List<Bus> get _filteredBuses {
    return _buses.where((b) {
      if (_selectedFrom.isNotEmpty && b.from != _selectedFrom) return false;
      if (_selectedTo.isNotEmpty && b.to != _selectedTo) return false;
      return true;
    }).toList();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Search Buses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
            Text(
              _isLocating ? 'Locating you...' : 'Routes in $_detectedCity',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filters
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
            ),
            child: Column(
              children: [
                _dropdownField(
                  label: 'Departure',
                  value: _selectedFrom.isEmpty ? null : _selectedFrom,
                  items: _fromOptions,
                  hint: 'Select Departure',
                  onChanged: (v) => setState(() { _selectedFrom = v ?? ''; _selectedTo = ''; }),
                ),
                const SizedBox(height: 10),
                _dropdownField(
                  label: 'Destination',
                  value: _selectedTo.isEmpty ? null : _selectedTo,
                  items: _toOptions,
                  hint: 'Select Destination',
                  enabled: _selectedFrom.isNotEmpty,
                  onChanged: (v) => setState(() => _selectedTo = v ?? ''),
                ),
              ],
            ),
          ),
          // Bus list
          Expanded(
            child: _loading
              ? const Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Scanning routes...', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                  ],
                ))
              : _filteredBuses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_bus_rounded, size: 60, color: Colors.grey[200]),
                        const SizedBox(height: 12),
                        Text('No buses found for this route.', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredBuses.length,
                    itemBuilder: (context, i) => _BusCard(bus: _filteredBuses[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required String hint,
    bool enabled = true,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(hint, style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              isExpanded: true,
              icon: const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.expand_more_rounded, color: Color(0xFF94A3B8))),
              borderRadius: BorderRadius.circular(16),
              onChanged: enabled ? onChanged : null,
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Text(item, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                ),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bus Card Widget ──────────────────────────────────────────────────────────

class _BusCard extends StatelessWidget {
  final Bus bus;
  const _BusCard({required this.bus});

  static const _typeColors = <String, Color>{
    'Deluxe': Color(0xFF9333EA),
    'Express': Color(0xFFEA580C),
    'Normal': Color(0xFF64748B),
    'Mofussil': Color(0xFFDC2626),
    'Town': Color(0xFF2563EB),
    'Mini': Color(0xFF16A34A),
  };

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColors[bus.busType] ?? const Color(0xFF4F46E5);
    final nextStops = bus.stops.length > bus.currentStopIndex + 1
        ? bus.stops.sublist(bus.currentStopIndex + 1, (bus.currentStopIndex + 3).clamp(0, bus.stops.length))
        : <BusStop>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Color accent top bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.directions_bus_rounded, color: typeColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('#${bus.busNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: typeColor.withOpacity(0.2)),
                                ),
                                child: Text(bus.busType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: typeColor, letterSpacing: 0.5)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('FARE', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        Text('₹${bus.fare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Time & Route
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(bus.arrivalTime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      const Spacer(),
                      const Icon(Icons.route_rounded, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Flexible(child: Text(bus.route, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
                    ],
                  ),
                ),
                // Next stops
                if (nextStops.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.navigation_rounded, size: 11, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 4),
                      const Text('NEXT STOPS ETA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...nextStops.map((stop) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Expanded(child: Text(stop.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                          Text('${stop.distance}KM', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                            child: Text(stop.arrival, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveTrackingPage(busId: bus.id))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Track Live', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookRidePage(bus: bus))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 4,
                          shadowColor: const Color(0xFF4F46E5).withOpacity(0.3),
                        ),
                        child: const Text('Book Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
