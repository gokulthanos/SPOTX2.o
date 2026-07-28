import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../core/app_theme.dart';

class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  Map<String, dynamic> _analytics = {};
  bool _loading = true;
  int _selectedPeriod = 7;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      final overview = await _fetchAnalyticsOverview();
      final dashboard = await ApiService.fetchDashboard();
      if (mounted) {
        setState(() {
          _analytics = {
            ...overview,
            'dashboard': dashboard,
          };
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>> _fetchAnalyticsOverview() async {
    try {
      // Use the admin dashboard endpoint for now
      return await ApiService.fetchDashboard();
    } catch (e) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Analytics Dashboard', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<int>(
            onSelected: (v) {
              setState(() => _selectedPeriod = v);
              _loadAnalytics();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 7, child: Text('Last 7 Days')),
              const PopupMenuItem(value: 14, child: Text('Last 14 Days')),
              const PopupMenuItem(value: 30, child: Text('Last 30 Days')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCards(),
                    const SizedBox(height: 20),
                    _buildRevenueChart(),
                    const SizedBox(height: 20),
                    _buildBusStatusChart(),
                    const SizedBox(height: 20),
                    _buildPopularRoutes(),
                    const SizedBox(height: 20),
                    _buildOccupancyChart(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    final dashboard = _analytics['dashboard'] ?? {};
    final overview = dashboard['overview'] ?? {};
    final today = dashboard['today'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Row(
          children: [
            _overviewCard('Total Buses', '${overview['totalBuses'] ?? 0}', Icons.directions_bus_rounded, AppTheme.primaryBlue),
            const SizedBox(width: 12),
            _overviewCard('Active Now', '${overview['activeBuses'] ?? 0}', Icons.play_circle_rounded, AppTheme.success),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _overviewCard('Today\'s Tickets', '${today['tickets'] ?? 0}', Icons.confirmation_num_rounded, const Color(0xFF8B5CF6)),
            const SizedBox(width: 12),
            _overviewCard('Revenue', '₹${today['revenue'] ?? 0}', Icons.currency_rupee_rounded, AppTheme.warning),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _overviewCard('Passengers', '${overview['totalPassengers'] ?? 0}', Icons.people_rounded, const Color(0xFF06B6D4)),
            const SizedBox(width: 12),
            _overviewCard('Officers', '${overview['totalOfficers'] ?? 0}', Icons.badge_rounded, AppTheme.primaryDark),
          ],
        ),
      ],
    );
  }

  Widget _overviewCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    // Generate sample revenue data
    final revenueData = List.generate(_selectedPeriod, (i) {
      final date = DateTime.now().subtract(Duration(days: _selectedPeriod - 1 - i));
      return FlSpot(i.toDouble(), (100 + (i * 50) + (i % 3) * 100).toDouble());
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Last $_selectedPeriod days', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: revenueData,
                    isCurved: true,
                    color: AppTheme.primaryBlue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
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

  Widget _buildBusStatusChart() {
    final dashboard = _analytics['dashboard'] ?? {};
    final overview = dashboard['overview'] ?? {};

    final running = (overview['activeBuses'] ?? 10).toDouble();
    const notStarted = 5.0;
    const arrived = 3.0;
    final delayed = (overview['delayedBuses'] ?? 2).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bus Status Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(value: running, color: AppTheme.success, title: 'Running', radius: 60, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                  PieChartSectionData(value: notStarted, color: Colors.grey[300]!, title: 'Idle', radius: 60, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                  PieChartSectionData(value: arrived, color: AppTheme.primaryBlue, title: 'Arrived', radius: 60, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                  PieChartSectionData(value: delayed, color: AppTheme.warning, title: 'Delayed', radius: 60, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularRoutes() {
    final dashboard = _analytics['dashboard'] ?? {};
    final liveBuses = (dashboard['liveBuses'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live Buses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (liveBuses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No live buses', style: TextStyle(color: Colors.grey[400])),
              ),
            )
          else
            ...liveBuses.take(5).map((bus) => _liveBusRow(bus)),
        ],
      ),
    );
  }

  Widget _liveBusRow(dynamic bus) {
    final delay = bus['delay_minutes'] ?? 0;
    final occupancy = bus['current_occupancy'] ?? 0;
    final capacity = bus['capacity'] ?? 45;
    final percent = capacity > 0 ? (occupancy / capacity * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: delay > 0 ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              delay > 0 ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: delay > 0 ? AppTheme.warning : AppTheme.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bus['bus_number'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                Text('${bus['bus_type'] ?? ''} • $occupancy/$capacity seats', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
          if (delay > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('+$delay min', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.warning)),
            ),
          const SizedBox(width: 8),
          Text('$percent%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: percent > 80 ? AppTheme.error : AppTheme.primaryBlue)),
        ],
      ),
    );
  }

  Widget _buildOccupancyChart() {
    final barData = List.generate(24, (i) {
      final value = (i >= 6 && i <= 20) ? (30 + (i % 4) * 15 + (i % 3) * 10).toDouble() : (5 + i % 3).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: value,
            color: value > 80 ? AppTheme.error : value > 50 ? AppTheme.warning : AppTheme.primaryBlue,
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hourly Occupancy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Average occupancy by hour', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: barData,
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        if (hour % 4 == 0) {
                          return Text('${hour}h', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
