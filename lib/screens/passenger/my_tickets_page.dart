import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../models/ticket.dart';
import 'ticket_confirmation_page.dart';
import 'live_tracking_page.dart';
import 'bus_search_page.dart';

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({super.key});

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Ticket> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadTickets();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _loading = true);
    try {
      // Try API first
      final apiTickets = await ApiService.fetchBuses(); // placeholder – will use fallback
    } catch (_) {}

    // Fallback: local storage
    final auth = context.read<AuthProvider>();
    final contact = auth.passengerContact;
    final raw = StorageService.getSavedTickets(contact);
    final tickets = raw.map((t) => Ticket.fromJson(t)).toList();
    tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) setState(() { _tickets = tickets; _loading = false; });
  }

  bool _isActive(Ticket t) {
    try {
      final created = DateTime.parse(t.createdAt);
      return DateTime.now().isBefore(created.add(const Duration(hours: 3)));
    } catch (_) {
      return false;
    }
  }

  String _timeLeft(Ticket t) {
    try {
      final expiry = DateTime.parse(t.createdAt).add(const Duration(hours: 3));
      final diff = expiry.difference(DateTime.now());
      if (diff.isNegative) return 'Expired';
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m left';
      return '${diff.inMinutes}m left';
    } catch (_) {
      return '';
    }
  }

  String _expiryTime(Ticket t) {
    try {
      final expiry = DateTime.parse(t.createdAt).add(const Duration(hours: 3));
      final h = expiry.hour, m = expiry.minute;
      final suffix = h >= 12 ? 'PM' : 'AM';
      return '${(h % 12 == 0 ? 12 : h % 12).toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _tickets.where(_isActive).toList();
    final past = _tickets.where((t) => !_isActive(t)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Journeys', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          indicatorColor: const Color(0xFF4F46E5),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: 'ACTIVE (${active.length})'),
            Tab(text: 'HISTORY (${past.length})'),
          ],
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2))
        : TabBarView(
            controller: _tabCtrl,
            children: [
              _buildTicketList(active, isActive: true),
              _buildTicketList(past, isActive: false),
            ],
          ),
    );
  }

  Widget _buildTicketList(List<Ticket> tickets, {required bool isActive}) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: const Icon(Icons.confirmation_num_rounded, size: 40, color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 16),
            Text(isActive ? 'No active tickets' : 'No past trips',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(isActive ? "You haven't booked any rides yet." : 'Your trip history will appear here.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            if (isActive) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusSearchPage())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Book a Ride', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTickets,
      color: const Color(0xFF4F46E5),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tickets.length,
        itemBuilder: (_, i) => _TicketCard(
          ticket: tickets[i],
          isActive: _isActive(tickets[i]),
          timeLeft: _timeLeft(tickets[i]),
          expiryTime: _expiryTime(tickets[i]),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final bool isActive;
  final String timeLeft;
  final String expiryTime;

  const _TicketCard({
    required this.ticket,
    required this.isActive,
    required this.timeLeft,
    required this.expiryTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
        border: isActive ? Border.all(color: const Color(0xFF4F46E5).withOpacity(0.15)) : null,
      ),
      child: Column(
        children: [
          // Status header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'Active Journey' : 'Trip Finished',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8), letterSpacing: 0.8),
                ),
                const Spacer(),
                Text('Until $expiryTime', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Ticket ID & time left
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TICKET ID', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 1)),
                        Text('#${ticket.ticketNumber}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('STATUS', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 1)),
                        Text(
                          timeLeft,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isActive ? const Color(0xFF4F46E5) : const Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Route visual
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF4F46E5), width: 2))),
                          Container(width: 2, height: 24, color: const Color(0xFF4F46E5).withOpacity(0.3)),
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle)),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FROM', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                            Text(ticket.fromStop, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                            const SizedBox(height: 8),
                            const Text('TO', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                            Text(ticket.toStop, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Time & Fare info
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [const Icon(Icons.access_time_rounded, size: 10, color: Color(0xFF94A3B8)), const SizedBox(width: 3), const Text('SLOT', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 0.8))]),
                            const SizedBox(height: 4),
                            Text(ticket.startTime.isNotEmpty ? ticket.startTime : '—', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('TOTAL PAID', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                            const SizedBox(height: 4),
                            Text('₹${ticket.totalFare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TicketConfirmationPage(ticketNumber: ticket.ticketNumber))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('VIEW PASS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveTrackingPage(busId: ticket.busId))),
                        icon: const Icon(Icons.navigation_rounded, size: 14),
                        label: const Text('TRACK BUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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
