import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class GovernmentDashboardPage extends StatefulWidget {
  const GovernmentDashboardPage({super.key});

  @override
  State<GovernmentDashboardPage> createState() => _GovernmentDashboardPageState();
}

class _GovernmentDashboardPageState extends State<GovernmentDashboardPage> {
  Map<String, dynamic> _dashboard = {};
  List<dynamic> _liveBuses = [];
  List<dynamic> _recentComplaints = [];
  final List<dynamic> _revenueReport = [];
  bool _loading = true;
  final int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService.fetchDashboard();
      if (mounted) {
        setState(() {
          _dashboard = response['overview'] ?? {};
          _liveBuses = response['liveBuses'] ?? [];
          _recentComplaints = response['recentComplaints'] ?? [];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Government Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchDashboard,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewCards(),
                  const SizedBox(height: 20),
                  _buildLiveBusesSection(),
                  const SizedBox(height: 20),
                  _buildComplaintsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    final totalBuses = _dashboard['totalBuses'] ?? 0;
    final activeBuses = _dashboard['activeBuses'] ?? 0;
    final totalPassengers = _dashboard['totalPassengers'] ?? 0;
    final todayRevenue = _dashboard['todayRevenue'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SYSTEM OVERVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _overviewCard('TOTAL BUSES', '$totalBuses', Icons.directions_bus_rounded, AppTheme.primaryBlue),
            _overviewCard('ACTIVE BUSES', '$activeBuses', Icons.play_circle_rounded, AppTheme.success),
            _overviewCard('PASSENGERS', '$totalPassengers', Icons.people_rounded, const Color(0xFF8B5CF6)),
            _overviewCard('REVENUE', '₹${(todayRevenue as num).toStringAsFixed(0)}', Icons.currency_rupee_rounded, AppTheme.warning),
          ],
        ),
      ],
    );
  }

  Widget _overviewCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBusesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LIVE BUSES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        if (_liveBuses.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecoration,
            child: const Center(child: Text('No live buses currently', style: TextStyle(color: AppTheme.textMuted))),
          )
        else
          ..._liveBuses.map((bus) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.directions_bus_rounded, color: AppTheme.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${bus['bus_number'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      Text('${bus['bus_type'] ?? ''} • ${bus['city'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (bus['delay_minutes'] ?? 0) > 0 ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (bus['delay_minutes'] ?? 0) > 0 ? 'DELAYED ${bus['delay_minutes']}m' : 'ON TIME',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                          color: (bus['delay_minutes'] ?? 0) > 0 ? AppTheme.error : AppTheme.success),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )),
      ],
    );
  }

  Widget _buildComplaintsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RECENT COMPLAINTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        if (_recentComplaints.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecoration,
            child: const Center(child: Text('No recent complaints', style: TextStyle(color: AppTheme.textMuted))),
          )
        else
          ..._recentComplaints.map((c) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.report_problem_rounded, color: AppTheme.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['subject'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      Text(c['created_at'] ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (c['status'] == 'resolved' ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text((c['status'] ?? 'open').toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                      color: (c['status'] == 'resolved') ? AppTheme.success : AppTheme.warning)),
                ),
              ],
            ),
          )),
      ],
    );
  }
}
