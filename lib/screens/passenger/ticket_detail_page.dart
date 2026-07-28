import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class TicketDetailPage extends StatelessWidget {
  final Map<String, dynamic> ticketData;

  const TicketDetailPage({super.key, required this.ticketData});

  @override
  Widget build(BuildContext context) {
    final pnr = ticketData['pnr'] ?? 'N/A';
    final status = ticketData['ticket_status'] ?? 'active';
    final total = (ticketData['total_amount'] ?? 0).toDouble();
    final fare = (ticketData['fare'] ?? 0).toDouble();
    final convFee = (ticketData['convenience_fee'] ?? 0).toDouble();
    final platFee = (ticketData['platform_fee'] ?? 0).toDouble();
    final boarding = ticketData['boarding_stop_name'] ?? '';
    final destination = ticketData['destination_stop_name'] ?? '';
    final busNumber = ticketData['bus_number'] ?? '';
    final routeName = ticketData['route_name'] ?? '';
    final journeyDate = ticketData['journey_date'] ?? '';
    final journeyTime = ticketData['journey_time'] ?? '';

    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(title: const Text('Your Ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppTheme.primaryNavy.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF1B1F3B), Color(0xFF2D3250)]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        const Text('SPOTX', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 3)),
                        const SizedBox(height: 8),
                        Text(pnr.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: status == 'active' ? AppTheme.success : Colors.white70, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('FROM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(boarding, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ])),
                          Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.accentOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.accentOrange)),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            const Text('TO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(destination, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ])),
                        ]),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _info('BUS', busNumber),
                          _info('ROUTE', routeName),
                          _info('DATE', journeyDate),
                          _info('TIME', journeyTime),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (pnr.toString().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration,
                child: const Center(
                  child: Column(children: [
                    Icon(Icons.qr_code_2_rounded, size: 120, color: AppTheme.primaryNavy),
                    SizedBox(height: 8),
                    Text('Show this to conductor', style: TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fare Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _fareRow('Ticket Fare', '₹${fare.toStringAsFixed(2)}'),
                _fareRow('Convenience Fee', '₹${convFee.toStringAsFixed(2)}'),
                _fareRow('Platform Fee', '₹${platFee.toStringAsFixed(2)}'),
                const Divider(height: 20),
                Row(children: [
                  const Text('Total Paid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentOrange)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
  ]);

  Widget _fareRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}
