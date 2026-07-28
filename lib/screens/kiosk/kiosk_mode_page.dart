import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/bus.dart';

class KioskModePage extends StatefulWidget {
  const KioskModePage({super.key});

  @override
  State<KioskModePage> createState() => _KioskModePageState();
}

class _KioskModePageState extends State<KioskModePage> {
  int _currentStep = 0;
  List<Bus> _buses = [];
  bool _loading = true;
  String _selectedFrom = '';
  String _selectedTo = '';
  Bus? _selectedBus;
  bool _isPaying = false;
  String? _bookedTicketNumber;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchBuses();
  }

  Future<void> _fetchBuses() async {
    setState(() => _loading = true);
    try {
      final buses = await ApiService.fetchBuses();
      if (mounted) setState(() => _buses = buses);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _allStops {
    final Set<String> stops = {};
    for (var bus in _buses) {
      for (var stop in bus.stops) {
        stops.add(stop.name);
      }
    }
    return stops.toList()..sort();
  }

  List<String> get _filteredStops {
    if (_searchQuery.isEmpty) return _allStops;
    return _allStops.where((s) => s.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  List<Bus> get _matchingBuses {
    if (_selectedFrom.isEmpty || _selectedTo.isEmpty) return [];
    return _buses.where((b) {
      final fromIdx = b.stops.indexWhere((s) => s.name.toLowerCase().contains(_selectedFrom.toLowerCase()));
      final toIdx = b.stops.indexWhere((s) => s.name.toLowerCase().contains(_selectedTo.toLowerCase()));
      return fromIdx != -1 && toIdx != -1 && toIdx > fromIdx;
    }).toList();
  }

  double _calcFare(Bus bus) {
    final fromIdx = bus.stops.indexWhere((s) => s.name.toLowerCase().contains(_selectedFrom.toLowerCase()));
    final toIdx = bus.stops.indexWhere((s) => s.name.toLowerCase().contains(_selectedTo.toLowerCase()));
    if (fromIdx == -1 || toIdx == -1) return bus.fare;
    final numStops = toIdx - fromIdx;
    final totalUnits = (bus.stops.length / 2).ceil();
    final farePerUnit = totalUnits > 0 ? bus.fare / totalUnits : 0;
    final units = (numStops / 2).ceil();
    return (units * farePerUnit).ceilToDouble();
  }

  Future<void> _bookTicket() async {
    if (_selectedBus == null) return;
    setState(() => _isPaying = true);

    try {
      final ticketId = await ApiService.bookTicket(
        busId: _selectedBus!.id,
        busNumber: _selectedBus!.busNumber,
        fromStop: _selectedFrom,
        toStop: _selectedTo,
        totalFare: _calcFare(_selectedBus!),
        passengers: [{'name': 'Kiosk Passenger', 'gender': 'Other'}],
        paymentMethod: 'razorpay',
      );
      setState(() {
        _bookedTicketNumber = ticketId;
        _isPaying = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Booking failed: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
      setState(() => _isPaying = false);
    }
  }

  void _reset() {
    setState(() {
      _currentStep = 0;
      _selectedFrom = '';
      _selectedTo = '';
      _selectedBus = null;
      _bookedTicketNumber = null;
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: _bookedTicketNumber != null
            ? _buildConfirmationView()
            : Column(
                children: [
                  _buildKioskHeader(),
                  Expanded(child: _buildCurrentStep()),
                  _buildStepIndicator(),
                ],
              ),
      ),
    );
  }

  Widget _buildKioskHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_bus_rounded, color: Color(0xFF3B82F6), size: 36),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SPOTX TRANSIT KIOSK', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              Text('Self-Service Ticketing Terminal', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          const Spacer(),
          if (_bookedTicketNumber == null)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('EXIT KIOSK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildSearchStep();
      case 1:
        return _buildSelectFromStop();
      case 2:
        return _buildSelectToStop();
      case 3:
        return _buildSelectBus();
      case 4:
        return _buildPaymentStep();
      default:
        return _buildSearchStep();
    }
  }

  Widget _buildSearchStep() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SELECT YOUR JOURNEY', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text('Choose your boarding stop to begin', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: 'Search stops...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 18),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF3B82F6), size: 28),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredStops.length,
                            itemBuilder: (context, i) => _kioskStopTile(_filteredStops[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kioskStopTile(String stopName) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _selectedFrom = stopName;
          _currentStep = 1;
          _searchQuery = '';
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: const Color(0xFF3B82F6), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(stopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectFromStop() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _kioskBackButton(),
              const SizedBox(width: 16),
              Text('FROM: $_selectedFrom', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Now select your destination', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: 'Search destination...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 18),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF3B82F6), size: 28),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filteredStops.where((s) => s != _selectedFrom).length,
                      itemBuilder: (context, i) {
                        final stops = _filteredStops.where((s) => s != _selectedFrom).toList();
                        return _kioskStopTile(stops[i]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectToStop() {
    return const SizedBox.shrink();
  }

  Widget _kioskStopTileSelectable(String stopName) {
    final hasRoute = _buses.any((b) {
      final fromIdx = b.stops.indexWhere((s) => s.name.toLowerCase().contains(_selectedFrom.toLowerCase()));
      final toIdx = b.stops.indexWhere((s) => s.name.toLowerCase().contains(stopName.toLowerCase()));
      return fromIdx != -1 && toIdx != -1 && toIdx > fromIdx;
    });

    return GestureDetector(
      onTap: hasRoute
          ? () {
              HapticFeedback.mediumImpact();
              setState(() {
                _selectedTo = stopName;
                _currentStep = 3;
                _searchQuery = '';
              });
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasRoute ? const Color(0xFF334155) : const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            Icon(
              hasRoute ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: hasRoute ? const Color(0xFF22C55E) : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(stopName, style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: hasRoute ? Colors.white : const Color(0xFF64748B),
              )),
            ),
            if (hasRoute) const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectBus() {
    final buses = _matchingBuses;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _kioskBackButton(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AVAILABLE BUSES', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                    Text('$_selectedFrom → $_selectedTo', style: const TextStyle(fontSize: 14, color: Color(0xFF3B82F6))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: buses.isEmpty
                ? const Center(child: Text('No buses found for this route', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 18)))
                : ListView.builder(
                    itemCount: buses.length,
                    itemBuilder: (context, i) => _kioskBusCard(buses[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kioskBusCard(Bus bus) {
    final fare = _calcFare(bus);
    final occupancy = bus.capacity > 0 ? (bus.currentOccupancy / bus.capacity * 100) : 0;
    final color = occupancy >= 80 ? AppTheme.error : (occupancy >= 50 ? AppTheme.warning : AppTheme.success);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _selectedBus = bus;
          _currentStep = 4;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF3B82F6), size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${bus.busNumber}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${bus.busType} • ${bus.arrivalTime}', style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text(occupancy >= 80 ? 'CROWDED' : (occupancy >= 50 ? 'MODERATE' : 'AVAILABLE'),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                      ),
                      if (bus.delayMinutes > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text('DELAYED ${bus.delayMinutes}m', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.error)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('FARE', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w800, letterSpacing: 1)),
                Text('₹${fare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF3B82F6))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStep() {
    final fare = _selectedBus != null ? _calcFare(_selectedBus!) : 0.0;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _kioskBackButton(),
              const SizedBox(width: 16),
              const Text('CONFIRM & PAY', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                const Icon(Icons.directions_bus_rounded, color: Color(0xFF3B82F6), size: 48),
                const SizedBox(height: 16),
                Text('#${_selectedBus?.busNumber ?? ''}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_selectedFrom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF3B82F6), size: 24),
                    ),
                    Text(_selectedTo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('TOTAL FARE', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.w800)),
                      const SizedBox(width: 16),
                      Text('₹${fare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF3B82F6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _kioskLargeButton(
                  label: 'PAY WITH UPI',
                  icon: Icons.qr_code_scanner_rounded,
                  color: const Color(0xFF16A34A),
                  onTap: _isPaying ? null : _bookTicket,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _kioskLargeButton(
                  label: 'PAY WITH CARD',
                  icon: Icons.credit_card_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: _isPaying ? null : _bookTicket,
                ),
              ),
            ],
          ),
          if (_isPaying) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
          ],
        ],
      ),
    );
  }

  Widget _kioskLargeButton({required String label, required IconData icon, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _kioskBackButton() {
    return GestureDetector(
      onTap: () => setState(() => _currentStep = (_currentStep - 1).clamp(0, 4)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildConfirmationView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 64),
            ),
            const SizedBox(height: 24),
            const Text('TICKET BOOKED!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text('Ticket #$_bookedTicketNumber', style: const TextStyle(fontSize: 20, color: Color(0xFF3B82F6), fontWeight: FontWeight.w700)),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: _bookedTicketNumber ?? '',
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text('$_selectedFrom → $_selectedTo', style: const TextStyle(fontSize: 18, color: Color(0xFF94A3B8))),
            const SizedBox(height: 8),
            Text('#${_selectedBus?.busNumber ?? ''}', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _reset,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('BOOK ANOTHER TICKET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(color: Color(0xFF1E293B), border: Border(top: BorderSide(color: Color(0xFF334155)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) {
          final isActive = i <= _currentStep;
          final isCurrent = i == _currentStep;
          final labels = ['Search', 'From', 'To', 'Bus', 'Pay'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isCurrent ? 40 : 32,
                  height: isCurrent ? 40 : 32,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF334155),
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: const Color(0xFF60A5FA), width: 3) : null,
                  ),
                  child: Center(
                    child: isActive && i < _currentStep
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                        : Text('${i + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isActive ? Colors.white : const Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? Colors.white : const Color(0xFF64748B))),
              ],
            ),
          );
        }),
      ),
    );
  }
}
