import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../models/ticket.dart';
import 'live_tracking_page.dart';

class TicketConfirmationPage extends StatefulWidget {
  final String ticketNumber;
  const TicketConfirmationPage({super.key, required this.ticketNumber});

  @override
  State<TicketConfirmationPage> createState() => _TicketConfirmationPageState();
}

class _TicketConfirmationPageState extends State<TicketConfirmationPage> {
  Ticket? _ticket;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchTicket();
  }

  Future<void> _fetchTicket() async {
    try {
      final t = await ApiService.verifyTicket(widget.ticketNumber);
      if (mounted) setState(() { _ticket = t; _loading = false; });
      return;
    } catch (_) {}

    // Fallback to local storage
    final auth = context.read<AuthProvider>();
    final raw = StorageService.getSavedTickets(auth.passengerContact);
    final local = raw.firstWhere(
      (t) => t['ticketId'] == widget.ticketNumber || t['ticketNumber'] == widget.ticketNumber,
      orElse: () => <String, dynamic>{},
    );
    if (mounted) {
      setState(() {
        if (local.isNotEmpty) _ticket = Ticket.fromJson(local);
        _loading = false;
      });
    }
  }

  bool get _isExpired {
    if (_ticket == null) return false;
    try {
      final exp = DateTime.parse(_ticket!.createdAt).add(const Duration(hours: 3));
      return DateTime.now().isAfter(exp);
    } catch (_) { return false; }
  }

  String get _timeLeft {
    if (_ticket == null) return '';
    try {
      final exp = DateTime.parse(_ticket!.createdAt).add(const Duration(hours: 3));
      final diff = exp.difference(DateTime.now());
      if (diff.isNegative) return 'Expired';
      if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m left';
      return '${diff.inMinutes}m left';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _isExpired;
    final headerColor = expired ? const Color(0xFF1E293B) : const Color(0xFF4F46E5);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
        : _ticket == null
          ? _buildNotFound()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(headerColor, expired)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList(delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    _buildBoardingPass(expired),
                    const SizedBox(height: 14),
                    _buildPassengerManifest(),
                    const SizedBox(height: 14),
                    _buildQRCard(),
                    const SizedBox(height: 14),
                    _buildActionButtons(expired),
                    if (_ticket!.bus?.stops != null && _ticket!.bus!.stops.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildTimeline(),
                    ],
                  ])),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(Color color, bool expired) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(right: 10, top: 0, child: Opacity(opacity: 0.05, child: Icon(Icons.directions_bus_rounded, size: 160, color: Colors.white))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            const Text('BOOKING PASS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 1)),
                            Text('#${widget.ticketNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: expired ? Colors.white.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20)],
                    ),
                    child: Icon(
                      expired ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                      size: 44,
                      color: expired ? Colors.grey[400] : const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    expired ? 'TRIP ENDED' : 'RIDE CONFIRMED',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    expired ? 'Journey validity expired' : 'Scanning ready for boarding',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _headerStat('Status', expired ? 'Invalid' : 'Active', expired ? const Color(0xFFFF8080) : const Color(0xFF86EFAC)),
                      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.15), margin: const EdgeInsets.symmetric(horizontal: 20)),
                      _headerStat('Expires', _timeLeft, Colors.white),
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

  Widget _headerStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.5), letterSpacing: 1)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: valueColor)),
      ],
    );
  }

  Widget _buildBoardingPass(bool expired) {
    final t = _ticket!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.navigation_rounded, color: Color(0xFF4F46E5), size: 16)),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Journey Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                ]),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: _infoBlock('From Station', t.fromStop)),
                Expanded(child: _infoBlock('To Station', t.toStop, align: CrossAxisAlignment.end)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _infoBlock('Bus Number', '#${t.busNumber}')),
                Expanded(child: _infoBlock('Total Fare', '₹${t.totalFare.toStringAsFixed(0)}', align: CrossAxisAlignment.end)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBlock(String label, String value, {CrossAxisAlignment align = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildPassengerManifest() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PASSENGER MANIFEST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
          const SizedBox(height: 12),
          ...List.generate(_ticket!.passengers.length, (i) {
            final p = _ticket!.passengers[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
                    child: Center(child: Text('0${i+1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1E293B))),
                    Text(p.gender, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  ])),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('Verified', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF16A34A), letterSpacing: 0.8)),
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQRCard() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)]),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('TOTAL FARE PAID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹${_ticket!.totalFare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(10)), child: const Text('Paid', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white))),
            ],
          ),
          const SizedBox(height: 20),
          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: QrImageView(
              data: widget.ticketNumber,
              version: QrVersions.auto,
              size: 140,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text('Ticket Code: ${widget.ticketNumber}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.ticketNumber));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Ticket code copied!', style: TextStyle(fontWeight: FontWeight.w700)),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Color(0xFF22C55E),
              ));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.copy_rounded, color: Colors.white, size: 15),
                  SizedBox(width: 6),
                  Text('COPY CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool expired) {
    return Column(
      children: [
        if (!expired)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveTrackingPage(busId: _ticket!.busId))),
              icon: const Icon(Icons.navigation_rounded, size: 16),
              label: const Text('FULL TRACKER VIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimeline() {
    final stops = _ticket!.bus!.stops;
    final currentIdx = _ticket!.bus!.currentStopIndex;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TIMELINE STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ...List.generate(stops.length, (i) {
            final done = i < currentIdx;
            final current = i == currentIdx;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: done ? const Color(0xFF22C55E) : current ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: current ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 8)] : [],
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : Icons.circle,
                        size: done ? 14 : 8,
                        color: (done || current) ? Colors.white : const Color(0xFFCBD5E1),
                      ),
                    ),
                    if (i < stops.length - 1)
                      Container(width: 2, height: 50, color: done ? const Color(0xFF86EFAC) : const Color(0xFFF1F5F9)),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stops[i].name,
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900,
                            color: current ? const Color(0xFF4F46E5) : done ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                          ),
                        ),
                        Row(
                          children: [
                            Text('Arr: ${stops[i].arrival}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                            const SizedBox(width: 10),
                            Text('${stops[i].distance}KM', style: const TextStyle(fontSize: 9, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w700)),
                          ],
                        ),
                        if (current)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(8)),
                            child: const Text('ARRIVED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 60, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text('Ticket Not Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
