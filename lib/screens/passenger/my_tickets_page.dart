import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/ticket.dart';
import '../../services/api_service.dart';
import 'ticket_detail_page.dart';

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({super.key});
  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Ticket> _allTickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadTickets();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final tickets = await ApiService.getMyTickets();
      if (mounted) setState(() { _allTickets = tickets; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Ticket> get _active => _allTickets.where((t) => t.ticketStatus == 'active').toList();
  List<Ticket> get _past => _allTickets.where((t) => t.ticketStatus != 'active').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(
        title: const Text('My Tickets'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primaryNavy,
          labelColor: AppTheme.primaryNavy,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: [Tab(text: 'Active (${_active.length})'), Tab(text: 'Past (${_past.length})')],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _active.isEmpty ? _emptyState('No active tickets') : _list(_active),
                _past.isEmpty ? _emptyState('No past tickets') : _list(_past),
              ],
            ),
    );
  }

  Widget _emptyState(String msg) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.confirmation_num_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
    const SizedBox(height: 12),
    Text(msg, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
  ]));

  Widget _list(List<Ticket> tickets) => RefreshIndicator(
    onRefresh: _loadTickets,
    child: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _ticketCard(tickets[i]),
    ),
  );

  Widget _ticketCard(Ticket t) {
    final statusColor = t.ticketStatus == 'active' ? AppTheme.success : t.ticketStatus == 'verified' ? AppTheme.primaryNavy : AppTheme.error;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => TicketDetailPage(ticketData: t.toJson()),
      )),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(t.pnr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(t.ticketStatus.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(t.boardingStopName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.textMuted),
            Expanded(child: Text(t.destinationStopName, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text(t.busNumber, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const Spacer(),
            Text('₹${t.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentOrange)),
          ]),
        ]),
      ),
    );
  }
}
