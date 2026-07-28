import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/stop.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'search_results_page.dart';
import 'my_tickets_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  List<Stop> _stops = [];
  Stop? _fromStop;
  Stop? _toStop;

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    try {
      final stops = await ApiService.getAllStops();
      if (mounted) setState(() => _stops = stops);
    } catch (e) {
      debugPrint('[Home] Failed to load stops: $e');
    }
  }

  void _searchBuses() {
    if (_fromStop == null || _toStop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both boarding and destination stops'), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (_fromStop!.id == _toStop!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Boarding and destination must be different'), backgroundColor: AppTheme.error),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SearchResultsPage(fromStop: _fromStop!, toStop: _toStop!),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.passenger?.fullName ?? 'Traveller';

    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(name),
          const MyTicketsPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))]),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
          height: 70,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primaryNavy), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.confirmation_num_outlined), selectedIcon: Icon(Icons.confirmation_num_rounded, color: AppTheme.primaryNavy), label: 'Tickets'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primaryNavy), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(String name) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B1F3B), Color(0xFF2D3250)]),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello, ${name.split(' ').first}', style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          const Text('Where are you going?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      )),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    _buildStopSelector('FROM', Icons.circle_outlined, Colors.green, _fromStop, (s) => setState(() { _fromStop = s; if (_toStop?.id == s?.id) _toStop = null; })),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () { final t = _fromStop; setState(() { _fromStop = _toStop; _toStop = t; }); },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppTheme.primaryNavy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.swap_vert_rounded, size: 18, color: AppTheme.primaryNavy),
                        ),
                      ),
                    ),
                    _buildStopSelector('TO', Icons.place, Colors.red, _toStop, (s) => setState(() { _toStop = s; if (_fromStop?.id == s?.id) _fromStop = null; })),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: _searchBuses,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.search_rounded, size: 20), SizedBox(width: 8),
                          Text('Search Buses', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text('OFFERS & UPDATES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.textPrimary.withValues(alpha: 0.6), letterSpacing: 1.2)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final promos = [
                {'title': 'First Ride Free!', 'subtitle': 'Get 100% off on your first digital ticket', 'icon': Icons.card_giftcard_rounded, 'color': AppTheme.primaryNavy},
                {'title': 'Refer & Earn', 'subtitle': 'Invite friends and earn ₹20 wallet credit', 'icon': Icons.group_add_rounded, 'color': AppTheme.success},
                {'title': 'Weekend Special', 'subtitle': 'Flat 15% off on all Express routes this weekend', 'icon': Icons.local_offer_rounded, 'color': AppTheme.warning},
              ];
              final p = promos[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: (p['color'] as Color).withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (p['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(p['icon'] as IconData, color: p['color'] as Color, size: 24)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['title'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text(p['subtitle'] as String, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStopSelector(String label, IconData icon, Color color, Stop? selected, ValueChanged<Stop?> onChanged) {
    return GestureDetector(
      onTap: () => _showStopPicker(onChanged, selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: AppTheme.borderLight), borderRadius: BorderRadius.circular(14), color: AppTheme.surfaceGray),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text(selected?.name ?? 'Select stop', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected != null ? AppTheme.textPrimary : AppTheme.textMuted)),
            ],
          )),
          const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
        ]),
      ),
    );
  }

  void _showStopPicker(ValueChanged<Stop?> onChanged, Stop? current) {
    String query = '';
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = _stops.where((s) => s.name.toLowerCase().contains(query.toLowerCase())).toList();
          return DraggableScrollableSheet(
            initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.9, expand: false,
            builder: (context, scrollController) => Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Align(alignment: Alignment.centerLeft, child: Text('Select Stop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)))),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (v) => setModalState(() => query = v),
                    decoration: InputDecoration(hintText: 'Search stops...', prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true, fillColor: AppTheme.surfaceGray,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final stop = filtered[i];
                      final isSelected = stop.id == current?.id;
                      return ListTile(
                        tileColor: isSelected ? AppTheme.primaryNavy.withValues(alpha: 0.05) : null,
                        leading: Icon(Icons.location_on_rounded, size: 18, color: isSelected ? AppTheme.primaryNavy : AppTheme.textMuted),
                        title: Text(stop.name, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryNavy, size: 18) : null,
                        onTap: () { onChanged(stop); Navigator.pop(context); },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
