import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import 'ticket_detail_page.dart';

class PaymentPage extends StatefulWidget {
  final int ticketId;
  final double totalAmount;
  final Map<String, dynamic> ticketData;

  const PaymentPage({
    super.key,
    required this.ticketId,
    required this.totalAmount,
    required this.ticketData,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedMethod = 'upi';
  String _selectedUpiApp = '';
  bool _isPaying = false;
  bool _paymentDone = false;

  Future<void> _pay() async {
    setState(() => _isPaying = true);
    try {
      final initiate = await ApiService.initiatePayment(widget.ticketId);
      final data = initiate['data'] ?? initiate;
      final paymentId = data['payment_id'] ?? 0;
      await ApiService.verifyPayment(widget.ticketId, paymentId);
      if (mounted) setState(() { _isPaying = false; _paymentDone = true; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => TicketDetailPage(ticketData: widget.ticketData),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentDone) {
      return Scaffold(
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 40)),
          const SizedBox(height: 20),
          const Text('Payment Successful!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Generating your ticket...', style: TextStyle(color: AppTheme.textSecondary)),
        ])),
      );
    }

    final boarding = widget.ticketData['boarding_stop_name'] ?? '';
    final destination = widget.ticketData['destination_stop_name'] ?? '';
    final busNumber = widget.ticketData['bus_number'] ?? '';

    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(title: const Text('Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _row('Passenger', widget.ticketData['passenger_name'] ?? ''),
                _row('Route', '$boarding → $destination'),
                _row('Bus', busNumber),
                const Divider(height: 20),
                Row(children: [
                  const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('₹${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentOrange)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Pay with', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _paymentOption('upi', 'UPI', Icons.qr_code),
            _paymentOption('wallet', 'Wallet', Icons.account_balance_wallet_outlined),
            if (_selectedMethod == 'upi') ...[
              const SizedBox(height: 16),
              const Text('Choose UPI App', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                _upiApp('Google Pay', Icons.payment),
                const SizedBox(width: 8),
                _upiApp('PhonePe', Icons.phone_android),
                const SizedBox(width: 8),
                _upiApp('Paytm', Icons.account_balance_wallet),
                const SizedBox(width: 8),
                _upiApp('BHIM', Icons.send),
              ]),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isPaying ? null : _pay,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _isPaying
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Pay ₹${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _paymentOption(String value, String label, IconData icon) {
    final selected = _selectedMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppTheme.primaryNavy : AppTheme.borderLight, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? AppTheme.primaryNavy : AppTheme.textMuted, size: 22),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? AppTheme.primaryNavy : AppTheme.textPrimary)),
          const Spacer(),
          if (selected) const Icon(Icons.check_circle, color: AppTheme.primaryNavy, size: 20),
        ]),
      ),
    );
  }

  Widget _upiApp(String name, IconData icon) {
    final selected = _selectedUpiApp == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedUpiApp = name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppTheme.primaryNavy : AppTheme.borderLight, width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 24, color: selected ? AppTheme.primaryNavy : AppTheme.textMuted),
          const SizedBox(height: 4),
          Text(name, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: selected ? AppTheme.primaryNavy : AppTheme.textSecondary)),
        ]),
      ),
    );
  }
}
