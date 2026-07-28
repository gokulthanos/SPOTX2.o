import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/bus.dart';
import '../../models/stop.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'payment_page.dart';

class BookTicketPage extends StatefulWidget {
  final Bus bus;
  final Stop boardingStop;
  final Stop destinationStop;
  const BookTicketPage({super.key, required this.bus, required this.boardingStop, required this.destinationStop});
  @override
  State<BookTicketPage> createState() => _BookTicketPageState();
}

class _BookTicketPageState extends State<BookTicketPage> {
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String _gender = 'Male';
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameCtrl.text = auth.passenger?.fullName ?? '';
    if (auth.passenger?.dob != null && auth.passenger!.dob!.isNotEmpty) _dobCtrl.text = auth.passenger!.dob!;
    if (auth.passenger?.gender != null && auth.passenger!.gender.isNotEmpty) _gender = auth.passenger!.gender;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _dobCtrl.dispose(); super.dispose(); }

  double get _fare => widget.bus.fare;
  double get _convenienceFee => (_fare * 0.05).ceilToDouble();
  double get _platformFee => 1.0;
  double get _total => _fare + _convenienceFee + _platformFee;

  Future<void> _book() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter passenger name'), backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _isBooking = true);
    try {
      final result = await ApiService.bookTicket(widget.bus.id, widget.boardingStop.id, widget.destinationStop.id);
      final data = result['data'] ?? result;
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => PaymentPage(
          ticketId: data['id'] ?? 0,
          totalAmount: _total,
          ticketData: data,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(title: const Text('Book Ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.directions_bus, size: 20, color: AppTheme.primaryNavy),
                    const SizedBox(width: 8),
                    Text(widget.bus.busNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(widget.bus.busType, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.boardingStop.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(widget.bus.departureTime, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ])),
                    const Icon(Icons.arrow_forward, color: AppTheme.textMuted),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(widget.destinationStop.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(widget.bus.arrivalTime, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ])),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Passenger Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  _field(_nameCtrl, 'Full Name', Icons.person_outline),
                  const SizedBox(height: 12),
                  _field(_dobCtrl, 'Date of Birth (DD/MM/YYYY)', Icons.calendar_today_outlined),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: InputDecoration(
                      labelText: 'Gender', filled: true, fillColor: AppTheme.surfaceGray,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setState(() => _gender = v ?? _gender),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fare Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _fareRow('Ticket Fare', '₹${_fare.toStringAsFixed(2)}'),
                  _fareRow('Convenience Fee (5%)', '₹${_convenienceFee.toStringAsFixed(2)}'),
                  _fareRow('Platform Fee', '₹${_platformFee.toStringAsFixed(2)}'),
                  const Divider(height: 24),
                  Row(children: [
                    const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('₹${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentOrange)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _book,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _isBooking
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Pay ₹${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, size: 20), filled: true, fillColor: AppTheme.surfaceGray,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
      ),
    );
  }

  Widget _fareRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
