import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/bus.dart';
import '../../services/api_service.dart';

class SelectBusPage extends StatefulWidget {
  const SelectBusPage({super.key});
  @override
  State<SelectBusPage> createState() => _SelectBusPageState();
}

class _SelectBusPageState extends State<SelectBusPage> {
  List<Bus> _buses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    try {
      final stops = await ApiService.getAllStops();
      if (stops.isNotEmpty) {
        final buses = await ApiService.searchBuses(stops.first.id, stops.last.id);
        if (mounted) setState(() { _buses = buses; _isLoading = false; });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(title: const Text('Select Bus Route')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buses.isEmpty
              ? const Center(child: Text('No buses available', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _buses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final bus = _buses[i];
                    final typeColor = bus.busType == 'AC' ? AppTheme.primaryNavy : bus.busType == 'Express' ? AppTheme.accentOrange : AppTheme.success;
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, {'id': bus.id, 'bus_number': bus.busNumber, 'route_number': bus.routeNumber, 'route_name': bus.routeName}),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.cardDecoration,
                        child: Row(children: [
                          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.primaryNavy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.directions_bus_rounded, color: AppTheme.primaryNavy, size: 24)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(bus.busNumber, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(bus.busType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: typeColor))),
                            ]),
                            const SizedBox(height: 4),
                            Text('${bus.routeNumber} • ${bus.routeName}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ])),
                          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
