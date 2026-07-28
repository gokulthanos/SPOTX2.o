import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class TodayStatusPage extends StatefulWidget {
  const TodayStatusPage({super.key});
  @override
  State<TodayStatusPage> createState() => _TodayStatusPageState();
}

class _TodayStatusPageState extends State<TodayStatusPage> {
  bool _isLoading = true;
  int _totalVerified = 0;
  int _validTickets = 0;
  int _invalidTickets = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getTodayStats();
      final data = res['data'] ?? res;
      final verifications = data['verifications'] ?? {};
      if (mounted) {
        setState(() {
          _totalVerified = verifications['total_verified'] ?? 0;
          _validTickets = verifications['valid_count'] ?? 0;
          _invalidTickets = (verifications['invalid_count'] ?? 0) + (verifications['expired_count'] ?? 0);
          _totalRevenue = (data['total_revenue'] ?? 0).toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(title: const Text("Today's Status")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: _statCard('Total Verified', '$_totalVerified', AppTheme.primaryNavy)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Valid', '$_validTickets', AppTheme.success)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _statCard('Invalid', '$_invalidTickets', AppTheme.error)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Revenue', '₹${_totalRevenue.toStringAsFixed(0)}', AppTheme.accentOrange)),
                    ]),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.cardDecoration,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _row('Total Tickets Checked', '$_totalVerified'),
                        _row('Successfully Verified', '$_validTickets'),
                        _row('Invalid / Expired', '$_invalidTickets'),
                        const Divider(height: 24),
                        Row(children: [
                          const Text('Revenue Collected', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text('₹${_totalRevenue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentOrange)),
                        ]),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
