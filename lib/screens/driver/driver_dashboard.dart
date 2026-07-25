import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../../core/app_theme.dart';
import '../auth/landing_page.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _currentIndex = 0;
  Map<String, dynamic> _busData = {};
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  bool _tripActive = false;
  String _tripStatus = 'Not Started';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final busData = await _fetchMyBus();
      final stats = await _fetchStats();
      if (mounted) {
        setState(() {
          _busData = busData;
          _stats = stats;
          _tripActive = busData['travelStatus'] == 'Running';
          _tripStatus = busData['travelStatus'] ?? 'Not Started';
          _loading = false;
        });

        // Register for real-time updates
        if (busData['id'] != null) {
          RealtimeService.registerDriver(busData['id']);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>> _fetchMyBus() async {
    try {
      final response = await ApiService.fetchBuses(city: 'Chennai');
      if (response.isNotEmpty) {
        return {
          'id': response.first.id,
          'busNumber': response.first.busNumber,
          'busType': response.first.busType,
          'capacity': response.first.capacity,
          'travelStatus': response.first.travelStatus,
          'fromStop': response.first.from,
          'toStop': response.first.to,
          'route': response.first.route,
          'fare': response.first.fare,
          'lat': response.first.lat,
          'lon': response.first.lon,
        };
      }
    } catch (e) {
      debugPrint('[Driver] Failed to fetch bus: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    try {
      final response = await ApiService.fetchDashboard();
      return response;
    } catch (e) {
      return {};
    }
  }

  Future<void> _startTrip() async {
    // TODO: Call driver API to start trip
    setState(() {
      _tripActive = true;
      _tripStatus = 'Running';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip Started! GPS sharing active.'), backgroundColor: AppTheme.success),
      );
    }
  }

  Future<void> _pauseTrip() async {
    setState(() {
      _tripStatus = 'Delayed';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip paused.'), backgroundColor: AppTheme.warning),
      );
    }
  }

  Future<void> _endTrip() async {
    setState(() {
      _tripActive = false;
      _tripStatus = 'Arrived';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ended.'), backgroundColor: AppTheme.primaryBlue),
      );
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
      backgroundColor: AppTheme.surfaceWhite,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboardTab(auth),
            _buildBusInfoTab(),
            _buildStatsTab(),
            _buildProfileTab(auth),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDashboardTab(AuthProvider auth) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.directions_bus_rounded, color: AppTheme.primaryBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Driver: ${auth.officerName.isNotEmpty ? auth.officerName : "Driver"}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                    const Text('Driver Mode', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
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
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.logout_rounded, size: 18, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Trip Status Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _tripActive
                      ? [AppTheme.success, const Color(0xFF059669)]
                      : [AppTheme.primaryBlue, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(
                  color: (_tripActive ? AppTheme.success : AppTheme.primaryBlue).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TRIP STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Text(_tripStatus, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(_tripActive ? Icons.circle : Icons.pause_circle, size: 10, color: _tripActive ? const Color(0xFF86EFAC) : Colors.white70),
                            const SizedBox(width: 4),
                            Text(_tripActive ? 'LIVE' : 'IDLE',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_busData.isNotEmpty) ...[
                    Row(
                      children: [
                        _tripStatBlock('Bus', _busData['busNumber'] ?? 'N/A'),
                        const SizedBox(width: 8),
                        _tripStatBlock('Route', _busData['route'] ?? 'N/A'),
                        const SizedBox(width: 8),
                        _tripStatBlock('Type', _busData['busType'] ?? 'Normal'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _tripStatBlock('From', _busData['fromStop'] ?? 'N/A'),
                        const SizedBox(width: 8),
                        _tripStatBlock('To', _busData['toStop'] ?? 'N/A'),
                      ],
                    ),
                  ] else
                    const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Trip Control Buttons
            Row(
              children: [
                Expanded(
                  child: _controlButton(
                    label: _tripActive ? 'PAUSE TRIP' : 'START TRIP',
                    icon: _tripActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: _tripActive ? AppTheme.warning : AppTheme.success,
                    onTap: _tripActive ? _pauseTrip : _startTrip,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _controlButton(
                    label: 'END TRIP',
                    icon: Icons.stop_rounded,
                    color: AppTheme.error,
                    onTap: _tripActive ? _endTrip : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Actions
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [
                _quickAction(Icons.qr_code_scanner_rounded, 'Scan Ticket', AppTheme.primaryBlue),
                _quickAction(Icons.warning_amber_rounded, 'Report Delay', AppTheme.warning),
                _quickAction(Icons.emergency_rounded, 'Emergency', AppTheme.error),
                _quickAction(Icons.speed_rounded, 'Speed Check', AppTheme.success),
                _quickAction(Icons.people_rounded, 'Passengers', const Color(0xFF8B5CF6)),
                _quickAction(Icons.map_rounded, 'View Route', AppTheme.primaryBlue),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _tripStatBlock(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, color: Colors.white60, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({required String label, required IconData icon, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: onTap != null ? color : Colors.grey[300],
          borderRadius: BorderRadius.circular(18),
          boxShadow: onTap != null ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label — Coming soon')),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildBusInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bus Information', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _infoCard('Bus Number', _busData['busNumber'] ?? 'N/A', Icons.directions_bus_rounded),
          _infoCard('Bus Type', _busData['busType'] ?? 'N/A', Icons.star_rounded),
          _infoCard('Route', _busData['route'] ?? 'N/A', Icons.route_rounded),
          _infoCard('Capacity', '${_busData['capacity'] ?? 45} seats', Icons.people_rounded),
          _infoCard('From', _busData['fromStop'] ?? 'N/A', Icons.location_on_rounded),
          _infoCard('To', _busData['toStop'] ?? 'N/A', Icons.location_on_outlined),
          _infoCard('Fare', '₹${_busData['fare'] ?? 0}', Icons.currency_rupee_rounded),
          _infoCard('Status', _tripStatus, Icons.info_outline_rounded),
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today\'s Stats', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(
            children: [
              _statCard('Trips', '${_stats['today']?['totalTrips'] ?? 0}', Icons.directions_bus_rounded, AppTheme.primaryBlue),
              const SizedBox(width: 12),
              _statCard('Verified', '${_stats['today']?['verifications'] ?? 0}', Icons.check_circle_rounded, AppTheme.success),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard('Fines', '${_stats['today']?['finesIssued'] ?? 0}', Icons.gavel_rounded, AppTheme.warning),
              const SizedBox(width: 12),
              _statCard('GPS Points', 'Active', Icons.gps_fixed_rounded, const Color(0xFF8B5CF6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AppTheme.primaryBlue, size: 40),
          ),
          const SizedBox(height: 12),
          Text(auth.officerName.isNotEmpty ? auth.officerName : 'Driver',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(auth.officerId, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          _profileOption(Icons.person_outline_rounded, 'Edit Profile'),
          _profileOption(Icons.history_rounded, 'Trip History'),
          _profileOption(Icons.settings_outlined, 'Settings'),
          _profileOption(Icons.help_outline_rounded, 'Help & Support'),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.error)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileOption(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 22),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, 'Home', 0),
              _navItem(Icons.directions_bus_rounded, 'Bus', 1),
              _navItem(Icons.bar_chart_rounded, 'Stats', 2),
              _navItem(Icons.person_rounded, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final active = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: active ? AppTheme.primaryBlue : Colors.grey[400], size: 22),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? AppTheme.primaryBlue : Colors.grey[400])),
        ],
      ),
    );
  }
}
