import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'select_bus_page.dart';
import 'check_ticket_page.dart';
import 'today_status_page.dart';

class ConductorDashboard extends StatefulWidget {
  final Map<String, dynamic> conductorData;
  const ConductorDashboard({super.key, required this.conductorData});
  @override
  State<ConductorDashboard> createState() => _ConductorDashboardState();
}

class _ConductorDashboardState extends State<ConductorDashboard> {
  Map<String, dynamic>? _selectedBus;
  String get _name => widget.conductorData['name'] ?? 'Conductor';

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(title: const Text('Conductor Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1B1F3B), Color(0xFF2D3250)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppTheme.primaryNavy.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Row(children: [
                CircleAvatar(radius: 24, backgroundColor: Colors.white.withValues(alpha: 0.2), child: Text(_name[0].toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Good ${_greeting()}!', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 2),
                  Text(_name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                ])),
              ]),
            ),
            if (_selectedBus != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.success.withValues(alpha: 0.2))),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.directions_bus_rounded, color: AppTheme.success, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('ACTIVE BUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.success, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text('${_selectedBus!['bus_number'] ?? ''}  •  ${_selectedBus!['route_number'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ])),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            const Text('QUICK ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _action('Select Bus Route', 'Choose a bus to start your shift', Icons.route_rounded, AppTheme.primaryNavy, () async {
              final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => const SelectBusPage()));
              if (result != null) setState(() => _selectedBus = result);
            }),
            const SizedBox(height: 12),
            _action('Check Ticket', 'Scan QR or enter PNR to verify', Icons.qr_code_scanner_rounded, AppTheme.success, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckTicketPage()));
            }),
            const SizedBox(height: 12),
            _action("Today's Status", 'View verified tickets & revenue', Icons.analytics_rounded, const Color(0xFF6C5CE7), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TodayStatusPage()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _action(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration,
        child: Row(children: [
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 28)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 24),
        ]),
      ),
    );
  }
}
