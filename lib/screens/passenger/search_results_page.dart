import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/bus.dart';
import '../../models/stop.dart';
import '../../services/api_service.dart';
import 'book_ticket_page.dart';

class SearchResultsPage extends StatefulWidget {
  final Stop fromStop;
  final Stop toStop;
  const SearchResultsPage({super.key, required this.fromStop, required this.toStop});
  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  List<Bus> _buses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchBuses();
  }

  Future<void> _searchBuses() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final buses = await ApiService.searchBuses(widget.fromStop.id, widget.toStop.id);
      if (mounted) setState(() { _buses = buses; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(
        title: Text('${widget.fromStop.name} → ${widget.toStop.name}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppTheme.error)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _searchBuses, child: const Text('Retry')),
                ]))
              : _buses.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.directions_bus_filled, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text('No buses found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      const Text('Try different stops', style: TextStyle(color: AppTheme.textMuted)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _searchBuses,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _buses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _buildBusCard(_buses[i]),
                      ),
                    ),
    );
  }

  Widget _buildBusCard(Bus bus) {
    final typeColor = bus.busType == 'AC' ? AppTheme.primaryNavy : bus.busType == 'Express' ? AppTheme.accentOrange : AppTheme.success;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(bus.busNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(bus.busType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: typeColor)),
            ),
            const Spacer(),
            Text(bus.routeNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          ]),
          const SizedBox(height: 8),
          Text(bus.routeName, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DEPARTURE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(bus.departureTime, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ]),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.textMuted)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ARRIVAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(bus.arrivalTime, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('FARE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text('₹${bus.fare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentOrange)),
            ]),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BookTicketPage(bus: bus, boardingStop: widget.fromStop, destinationStop: widget.toStop),
              )),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
