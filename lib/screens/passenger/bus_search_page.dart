import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
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
  
  List<String> _recentSearches = [];
  List<String> _favoriteRoutes = [];

  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _fromFocusNode = FocusNode();
  final _toFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _init();
    _loadRecentAndFavorites();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final city = await LocationService.detectCity();
    if (mounted) setState(() { _detectedCity = city; _isLocating = false; });
    await _fetchBuses(city);
  }

  Future<void> _fetchBuses(String city) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final buses = await ApiService.fetchBuses(city: city);
      if (mounted) setState(() => _buses = buses);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadRecentAndFavorites() {
    // Load from StorageService / Hive boxes
    final contact = StorageService.getString('passengerContact') ?? 'guest';
    final savedRecent = StorageService.getWalletTransactions('${contact}_recent_searches'); // Borrow key
    final savedFavs = StorageService.getWalletTransactions('${contact}_favorite_routes'); // Borrow key
    
    setState(() {
      _recentSearches = savedRecent.map((e) => e['query'] as String).toList();
      _favoriteRoutes = savedFavs.map((e) => e['route'] as String).toList();
    });
  }

  Future<void> _saveSearch(String from, String to) async {
    if (from.isEmpty || to.isEmpty) return;
    final queryStr = '$from to $to';
    if (_recentSearches.contains(queryStr)) return;

    final contact = StorageService.getString('passengerContact') ?? 'guest';
    final current = _recentSearches.map((e) => {'query': e}).toList();
    current.insert(0, {'query': queryStr});
    if (current.length > 5) current.removeLast();

    await StorageService.saveWalletTransactions('${contact}_recent_searches', current);
    _loadRecentAndFavorites();
  }

  Future<void> _toggleFavorite(String from, String to) async {
    final routeStr = '$from to $to';
    final contact = StorageService.getString('passengerContact') ?? 'guest';
    final current = _favoriteRoutes.map((e) => {'route': e}).toList();

    if (_favoriteRoutes.contains(routeStr)) {
      current.removeWhere((e) => e['route'] == routeStr);
    } else {
      current.insert(0, {'route': routeStr});
    }

    await StorageService.saveWalletTransactions('${contact}_favorite_routes', current);
    _loadRecentAndFavorites();
  }

  List<String> get _allUniqueStops {
    final Set<String> stops = {};
    for (var bus in _buses) {
      for (var stop in bus.stops) {
        stops.add(stop.name);
      }
    }
    return stops.toList()..sort();
  }

  List<Bus> get _filteredBuses {
    return _buses.where((b) {
      if (_selectedFrom.isNotEmpty) {
        final fromIdx = b.stops.indexWhere((s) => s.name.toLowerCase().contains(_selectedFrom.toLowerCase()));
        if (fromIdx == -1) return false;

        if (_selectedTo.isNotEmpty) {
          final toIdx = b.stops.indexWhere((s) => s.name.toLowerCase().contains(_selectedTo.toLowerCase()));
          if (toIdx == -1 || toIdx <= fromIdx) return false;
        }
      }
      return true;
    }).toList();
  }

  void _applySearch(String from, String to) {
    setState(() {
      _selectedFrom = from;
      _selectedTo = to;
      _fromController.text = from;
      _toController.text = to;
    });
    _saveSearch(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBuses;
    final isFav = _selectedFrom.isNotEmpty && _selectedTo.isNotEmpty && _favoriteRoutes.contains('$_selectedFrom to $_selectedTo');

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
          // Filter Form
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
            ),
            child: Column(
              children: [
                _buildAutocompleteField(
                  label: 'Boarding Stop',
                  controller: _fromController,
                  focusNode: _fromFocusNode,
                  hint: 'e.g. Chennai CMBT',
                  icon: Icons.my_location_rounded,
                  onSelected: (val) {
                    setState(() {
                      _selectedFrom = val;
                    });
                    if (_selectedTo.isNotEmpty) {
                      _saveSearch(val, _selectedTo);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildAutocompleteField(
                  label: 'Destination Stop',
                  controller: _toController,
                  focusNode: _toFocusNode,
                  hint: 'e.g. Madurai Mattuthavani',
                  icon: Icons.pin_drop_rounded,
                  onSelected: (val) {
                    setState(() {
                      _selectedTo = val;
                    });
                    if (_selectedFrom.isNotEmpty) {
                      _saveSearch(_selectedFrom, val);
                    }
                  },
                ),
                if (_selectedFrom.isNotEmpty && _selectedTo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _toggleFavorite(_selectedFrom, _selectedTo),
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? Colors.red : Colors.grey,
                          size: 16,
                        ),
                        label: Text(
                          isFav ? 'Favorited' : 'Add to Favorites',
                          style: TextStyle(color: isFav ? Colors.red : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedFrom = '';
                            _selectedTo = '';
                            _fromController.clear();
                            _toController.clear();
                          });
                        },
                        icon: const Icon(Icons.clear_all_rounded, size: 16, color: Color(0xFF64748B)),
                        label: const Text('Reset', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ]
              ],
            ),
          ),

          // Show Favorites or Recent Searches if search is empty
          if (_selectedFrom.isEmpty && _selectedTo.isEmpty) ...[
            if (_favoriteRoutes.isNotEmpty) _buildSectionHeader('FAVORITE ROUTES', Icons.favorite_rounded, Colors.red),
            if (_favoriteRoutes.isNotEmpty) _buildFavoriteList(),
            if (_recentSearches.isNotEmpty) _buildSectionHeader('RECENT SEARCHES', Icons.history_rounded, const Color(0xFF4F46E5)),
            if (_recentSearches.isNotEmpty) _buildRecentSearchesList(),
          ],

          // Bus List
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2),
                        SizedBox(height: 12),
                        Text('Scanning routes...', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : filtered.isEmpty
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
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: ListView.builder(
                          key: ValueKey<int>(filtered.length),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _BusCard(
                            bus: filtered[i],
                            boardingStop: _selectedFrom,
                            destStop: _selectedTo,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutocompleteField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return _allUniqueStops.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: onSelected,
          fieldViewBuilder: (context, fieldController, fieldFocusNode, onFieldSubmitted) {
            // Keep controllers in sync
            if (controller.text != fieldController.text && !fieldFocusNode.hasFocus) {
              fieldController.text = controller.text;
            }
            fieldController.addListener(() {
              controller.text = fieldController.text;
            });
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: fieldController,
                focusNode: fieldFocusNode,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
                  hintText: hint,
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteList() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _favoriteRoutes.length,
        itemBuilder: (context, i) {
          final parts = _favoriteRoutes[i].split(' to ');
          if (parts.length < 2) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => _applySearch(parts[0], parts[1]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  Text(parts[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                  const Icon(Icons.arrow_right_alt_rounded, size: 14, color: Color(0xFFDC2626)),
                  Text(parts[1], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentSearchesList() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _recentSearches.length,
        itemBuilder: (context, i) {
          final parts = _recentSearches[i].split(' to ');
          if (parts.length < 2) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => _applySearch(parts[0], parts[1]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  Text(parts[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
                  const Icon(Icons.arrow_right_alt_rounded, size: 14, color: Color(0xFF4F46E5)),
                  Text(parts[1], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  final Bus bus;
  final String boardingStop;
  final String destStop;

  const _BusCard({
    required this.bus,
    required this.boardingStop,
    required this.destStop,
  });

  static const _typeColors = <String, Color>{
    'Deluxe': Color(0xFF9333EA),
    'Express': Color(0xFFEA580C),
    'Normal': Color(0xFF64748B),
    'Mofussil': Color(0xFFDC2626),
    'Town': Color(0xFF2563EB),
    'Mini': Color(0xFF16A34A),
  };

  /// Compute occupancy crowding indicator
  Widget _buildCrowdingChip() {
    final capacity = bus.capacity > 0 ? bus.capacity : 45;
    final occupancy = bus.currentOccupancy;
    final percent = (occupancy / capacity) * 100;

    String text = 'Seating Available';
    Color color = Colors.green;
    if (percent >= 80) {
      text = 'Crowded';
      color = Colors.red;
    } else if (percent >= 50) {
      text = 'Moderate Standing';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(
            text.toUpperCase(),
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColors[bus.busType] ?? const Color(0xFF4F46E5);
    final nextStops = bus.stops.length > bus.currentStopIndex + 1
        ? bus.stops.sublist(bus.currentStopIndex + 1, (bus.currentStopIndex + 3).clamp(0, bus.stops.length))
        : <BusStop>[];

    // Compute delay indicator
    final delayText = bus.delayMinutes > 0 ? 'Delayed by ${bus.delayMinutes} mins' : 'On Time';
    final delayColor = bus.delayMinutes > 0 ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
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
                      child: Hero(
                        tag: 'bus_icon_${bus.id}',
                        child: Icon(Icons.directions_bus_rounded, color: typeColor, size: 22),
                      ),
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
                                  color: typeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                                ),
                                child: Text(bus.busType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: typeColor, letterSpacing: 0.5)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildCrowdingChip(),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: delayColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: delayColor.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  delayText.toUpperCase(),
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: delayColor, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          )
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
                  const Row(
                    children: [
                      Icon(Icons.navigation_rounded, size: 11, color: Color(0xFF4F46E5)),
                      SizedBox(width: 4),
                      Text('NEXT STOPS ETA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
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
                          shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.3),
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
