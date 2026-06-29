import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../../models/bus.dart';
import '../auth/landing_page.dart';
import 'bus_search_page.dart';
import 'my_tickets_page.dart';
import 'wallet_page.dart';

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({super.key});

  @override
  State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  String _detectedCity = 'Chennai';
  bool _isLocating = true;
  bool _loading = true;
  int _busCount = 0;
  int _routeCount = 0;
  int _ticketCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final city = await LocationService.detectCity();
    if (mounted) setState(() { _detectedCity = city; _isLocating = false; });
    await _fetchData(city);
  }

  Future<void> _fetchData(String city) async {
    setState(() => _loading = true);
    try {
      final buses = await ApiService.fetchBuses(city: city);
      final uniqueRoutes = buses.map((b) => b.route).toSet();
      final auth = context.read<AuthProvider>();
      final contact = auth.passengerContact;
      final tickets = StorageService.getSavedTickets(contact);
      if (mounted) {
        setState(() {
          _busCount = buses.length;
          _routeCount = uniqueRoutes.length;
          _ticketCount = tickets.length;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LandingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchData(_detectedCity),
          color: const Color(0xFF4F46E5),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(auth),
                _buildWelcomeSection(auth),
                _buildStatsCard(),
                _buildQuickActions(),
                _buildFeatureBanner(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF4F46E5), size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SpotX Transit',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), letterSpacing: 1),
              ),
              Row(
                children: [
                  const Icon(Icons.my_location_rounded, size: 10, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 3),
                  Text(
                    _isLocating ? 'Locating...' : '$_detectedCity Region',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back,',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text('${auth.passengerName.isNotEmpty ? auth.passengerName : "Traveler"} 👋',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10, top: -10,
              child: Icon(Icons.directions_bus_rounded, size: 120, color: Colors.white.withOpacity(0.07)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isLocating ? 'Live Statistics' : 'Live $_detectedCity Statistics',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFBFD3FC), letterSpacing: 0.8),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: Color(0xFF86EFAC)),
                            SizedBox(width: 4),
                            Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _statBlock('Buses', _loading ? '…' : '$_busCount'),
                      const SizedBox(width: 12),
                      _statBlock('Routes', _loading ? '…' : '$_routeCount'),
                      const SizedBox(width: 12),
                      _statBlock('Booked', _loading ? '…' : '$_ticketCount'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBlock(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFFBFD3FC), fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'title': 'Find & Book a Bus',
        'subtitle': 'Browse available routes and book instantly.',
        'icon': Icons.search_rounded,
        'color': const Color(0xFF4F46E5),
        'shadow': const Color(0xFF4F46E5),
        'page': const BusSearchPage(),
      },
      {
        'title': 'My Tickets',
        'subtitle': 'View active passes and trip history.',
        'icon': Icons.confirmation_num_rounded,
        'color': const Color(0xFF0F172A),
        'shadow': const Color(0xFF0F172A),
        'page': const MyTicketsPage(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text("What would you like to do today?", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          const SizedBox(height: 14),
          ...actions.map((action) => _actionCard(
            title: action['title'] as String,
            subtitle: action['subtitle'] as String,
            icon: action['icon'] as IconData,
            color: action['color'] as Color,
            page: action['page'] as Widget,
          )),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget page,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PREMIUM TRANSIT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF818CF8), letterSpacing: 1.5)),
                  const SizedBox(height: 6),
                  const Text('Secure, Fast\n& Regional.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Open Wallet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF818CF8), size: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, 'Home', true, () {}),
              _navItem(Icons.search_rounded, 'Search', false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusSearchPage()))),
              _navItem(Icons.confirmation_num_rounded, 'Tickets', false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsPage()))),
              _navItem(Icons.account_balance_wallet_rounded, 'Wallet', false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage()))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: active ? const Color(0xFF4F46E5) : Colors.grey[400], size: 22),
          ),
          const SizedBox(height: 2),
          Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF4F46E5) : Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
