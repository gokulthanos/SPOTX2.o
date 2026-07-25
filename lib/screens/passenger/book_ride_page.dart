import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../models/bus.dart';
import 'ticket_confirmation_page.dart';

class BookRidePage extends StatefulWidget {
  final Bus bus;
  const BookRidePage({super.key, required this.bus});

  @override
  State<BookRidePage> createState() => _BookRidePageState();
}

class _PassengerEntry {
  String name = '';
  String gender = '';
}

class _BookRidePageState extends State<BookRidePage> {
  final List<_PassengerEntry> _passengers = [_PassengerEntry()];
  String _fromStop = '';
  String _toStop = '';
  bool _isPaying = false;
  String _selectedPaymentMethod = 'wallet'; // 'wallet' or 'razorpay'
  late Razorpay _razorpay;

  Bus get _bus => widget.bus;

  List<String> get _busStopNames => _bus.stops.map((s) => s.name).toList();

  List<String> get _toStopOptions {
    if (_fromStop.isEmpty) return _busStopNames;
    final idx = _busStopNames.indexOf(_fromStop);
    return idx >= 0 ? _busStopNames.sublist(idx + 1) : _busStopNames;
  }

  int get _numStops {
    if (_fromStop.isEmpty || _toStop.isEmpty) return 0;
    final fromIdx = _busStopNames.indexOf(_fromStop);
    final toIdx = _busStopNames.indexOf(_toStop);
    return toIdx > fromIdx ? toIdx - fromIdx : 0;
  }

  double get _farePerTwoStops {
    final totalUnits = (_busStopNames.length / 2).ceil();
    return totalUnits > 0 ? _bus.fare / totalUnits : 0;
  }

  double get _calculatedFare {
    if (_numStops == 0) return _bus.fare;
    final units = (_numStops / 2).ceil();
    return (units * _farePerTwoStops).ceilToDouble();
  }

  double get _totalFare => (_calculatedFare * _passengers.length).roundToDouble();

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<WalletProvider>().loadWallet(auth.passengerContact);
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _addPassenger() => setState(() => _passengers.add(_PassengerEntry()));

  void _removePassenger(int idx) {
    if (_passengers.length > 1) setState(() => _passengers.removeAt(idx));
  }

  // ─── Razorpay Event Handlers ────────────────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('[BOOKING] Razorpay gateway payment success: ${response.orderId}');
    await _completeBookingWithRazorpay(
      orderId: response.orderId ?? '',
      paymentId: response.paymentId ?? '',
      signature: response.signature ?? '',
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _snack('Payment failed: ${response.message}', error: true);
    setState(() => _isPaying = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _snack('Wallet not supported', error: true);
    setState(() => _isPaying = false);
  }

  // ─── Booking Trigger ────────────────────────────────────────────────

  Future<void> _handleBooking() async {
    final incomplete = _passengers.any((p) => p.name.trim().isEmpty || p.gender.isEmpty);
    if (incomplete || _fromStop.isEmpty || _toStop.isEmpty) {
      _snack('Please fill all passenger names, genders, and stops.', error: true);
      return;
    }
    if (_fromStop == _toStop) {
      _snack('From and To stops cannot be the same.', error: true);
      return;
    }

    setState(() => _isPaying = true);

    if (_selectedPaymentMethod == 'wallet') {
      await _bookWithWallet();
    } else {
      await _bookWithRazorpay();
    }
  }

  // ─── Wallet Booking Flow ───────────────────────────────────────────

  Future<void> _bookWithWallet() async {
    final wallet = context.read<WalletProvider>();
    if (wallet.balance < _totalFare) {
      _snack('Insufficient wallet balance! Top up or pay with UPI/Card.', error: true);
      setState(() => _isPaying = false);
      return;
    }

    try {
      final auth = context.read<AuthProvider>();
      
      // Call booking endpoint (triggers wallet deduction on server)
      final ticketId = await ApiService.bookTicket(
        busId: _bus.id,
        busNumber: _bus.busNumber,
        fromStop: _fromStop,
        toStop: _toStop,
        totalFare: _totalFare,
        passengers: _passengers.map((p) => {'name': p.name.trim(), 'gender': p.gender}).toList(),
        paymentMethod: 'wallet',
      );

      // Deduct locally
      await wallet.deduct(_totalFare, 'Booked ticket for $_fromStop to $_toStop');

      await _saveTicketToLocalCache(ticketId);
      _completeBookingView(ticketId);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
      setState(() => _isPaying = false);
    }
  }

  // ─── Razorpay Booking Flow ─────────────────────────────────────────

  Future<void> _bookWithRazorpay() async {
    try {
      final auth = context.read<AuthProvider>();

      // 1. Create order on server
      final orderData = await ApiService.initiatePayment(_totalFare, 'ticket');
      final bool isMockOrder = orderData['mock'] == true;

      if (isMockOrder) {
        _showSimulatedPaymentDialog(orderData['orderId']);
      } else {
        // Launch Razorpay Checkout sheet
        final options = {
          'key': orderData['keyId'],
          'amount': orderData['amount'], // paise
          'name': 'SpotX Ride App',
          'description': 'Ticket Payment',
          'order_id': orderData['orderId'],
          'prefill': {
            'contact': auth.passengerContact,
            'email': '${auth.passengerContact}@spotx.com',
          },
          'timeout': 300,
        };
        _razorpay.open(options);
      }
    } catch (e) {
      _snack('Failed to initiate payment gateway: $e', error: true);
      setState(() => _isPaying = false);
    }
  }

  void _showSimulatedPaymentDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Simulated UPI / Gateway Payment', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Text(
            'Razorpay simulated transaction of ₹${_totalFare.toStringAsFixed(0)} for order: $orderId.',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() => _isPaying = false);
              },
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final mockPayId = 'pay_mock_${DateTime.now().millisecondsSinceEpoch}';
                final mockSig = 'sig_mock_${DateTime.now().millisecondsSinceEpoch}';
                await _completeBookingWithRazorpay(orderId: orderId, paymentId: mockPayId, signature: mockSig);
              },
              child: const Text('PAY SUCCESS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeBookingWithRazorpay({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      // 2. Verify payment on server
      await ApiService.verifyPaymentSignature(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
        purpose: 'ticket',
      );

      // 3. Create ticket record on server
      final ticketId = await ApiService.bookTicket(
        busId: _bus.id,
        busNumber: _bus.busNumber,
        fromStop: _fromStop,
        toStop: _toStop,
        totalFare: _totalFare,
        passengers: _passengers.map((p) => {'name': p.name.trim(), 'gender': p.gender}).toList(),
        paymentMethod: 'razorpay',
        paymentId: paymentId,
      );

      await _saveTicketToLocalCache(ticketId);
      _completeBookingView(ticketId);
    } catch (e) {
      _snack('Verification/Booking failed: $e', error: true);
      setState(() => _isPaying = false);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  Future<void> _saveTicketToLocalCache(String ticketId) async {
    final auth = context.read<AuthProvider>();
    final email = auth.passengerContact;
    await StorageService.addTicket(email, {
      'ticketId': ticketId,
      'ticketNumber': ticketId,
      'busId': _bus.id.toString(),
      'busNumber': _bus.busNumber,
      'fromStop': _fromStop,
      'toStop': _toStop,
      'totalFare': _totalFare,
      'fare': _totalFare.toString(),
      'startTime': _bus.arrivalTime,
      'timestamp': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'passengers': _passengers.map((p) => {'name': p.name.trim(), 'gender': p.gender}).toList(),
    });
  }

  void _completeBookingView(String ticketId) {
    setState(() => _isPaying = false);
    _snack('Booking confirmed! Ticket #$ticketId');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TicketConfirmationPage(ticketNumber: ticketId)),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Book Ride', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
            Text('Bus #${_bus.busNumber}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Stop selection card
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Route Selection'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Column(
                        children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF4F46E5), width: 3))),
                          Container(width: 2, height: 30, color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                          Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle)),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          children: [
                            _dropDown(
                              value: _fromStop.isEmpty ? null : _fromStop,
                              hint: 'Select Departure Stop',
                              items: _busStopNames,
                              onChanged: (v) => setState(() { _fromStop = v ?? ''; _toStop = ''; }),
                            ),
                            const SizedBox(height: 8),
                            _dropDown(
                              value: _toStop.isEmpty ? null : _toStop,
                              hint: 'Select Destination Stop',
                              items: _toStopOptions,
                              enabled: _fromStop.isNotEmpty,
                              onChanged: (v) => setState(() => _toStop = v ?? ''),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Passengers card
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _sectionLabel('Passengers (${_passengers.length})')),
                      GestureDetector(
                        onTap: _addPassenger,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                          child: const Row(
                            children: [
                              Icon(Icons.add_rounded, color: Color(0xFF4F46E5), size: 16),
                              SizedBox(width: 4),
                              Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(_passengers.length, (i) => _passengerRow(i)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Payment Option Card
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Payment Mode'),
                  const SizedBox(height: 14),
                  
                  // Wallet Payment option
                  RadioListTile<String>(
                    activeColor: const Color(0xFF4F46E5),
                    contentPadding: EdgeInsets.zero,
                    value: 'wallet',
                    groupValue: _selectedPaymentMethod,
                    title: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF4F46E5), size: 20),
                        const SizedBox(width: 8),
                        const Text('SpotX Digital Wallet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const Spacer(),
                        Text('(Balance: ₹${wallet.balance.toStringAsFixed(2)})', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                      ],
                    ),
                    onChanged: (val) {
                      setState(() {
                        _selectedPaymentMethod = val!;
                      });
                    },
                  ),
                  
                  // Gateway payment option
                  RadioListTile<String>(
                    activeColor: const Color(0xFF4F46E5),
                    contentPadding: EdgeInsets.zero,
                    value: 'razorpay',
                    groupValue: _selectedPaymentMethod,
                    title: const Row(
                      children: [
                        Icon(Icons.payment_rounded, color: Color(0xFF6366F1), size: 20),
                        SizedBox(width: 8),
                        Text('UPI / Cards / NetBanking (Razorpay)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    onChanged: (val) {
                      setState(() {
                        _selectedPaymentMethod = val!;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Fare summary
            _card(
              child: Column(
                children: [
                  _sectionLabel('Fare Summary'),
                  const SizedBox(height: 14),
                  _fareRow('Base Fare', '₹${_bus.fare.toStringAsFixed(0)}'),
                  if (_numStops > 0) _fareRow('Stops Traveled', '$_numStops stops'),
                  _fareRow('Per Passenger', '₹${_calculatedFare.toStringAsFixed(0)}'),
                  _fareRow('Passengers', '×${_passengers.length}'),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL FARE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1)),
                      Text('₹${_totalFare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPaying ? null : _handleBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                ),
                child: _isPaying
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Processing...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                        ],
                      )
                    : Text('PAY ₹${_totalFare.toStringAsFixed(0)} & BOOK', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _passengerRow(int idx) {
    final p = _passengers[idx];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
            child: Center(child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1E293B)))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _passengers[idx].name = v),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Passenger name',
                hintStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: p.gender.isEmpty ? null : p.gender,
              hint: const Text('Gender', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
              isDense: true,
              items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(
                value: g,
                child: Text(g, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              )).toList(),
              onChanged: (v) => setState(() => _passengers[idx].gender = v ?? ''),
            ),
          ),
          if (_passengers.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
              onPressed: () => _removePassenger(idx),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _dropDown({String? value, required String hint, required List<String> items, bool enabled = true, required ValueChanged<String?> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Padding(padding: const EdgeInsets.only(left: 12), child: Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
          isExpanded: true,
          icon: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.expand_more_rounded, color: Color(0xFF94A3B8), size: 18)),
          borderRadius: BorderRadius.circular(14),
          onChanged: enabled ? onChanged : null,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(item, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
          )).toList(),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2));

  Widget _fareRow(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      ],
    ),
  );

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
      ),
      child: child,
    );
  }
}
