import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/api_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _amountCtrl = TextEditingController();
  late Razorpay _razorpay;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWallet();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _refreshWallet() {
    final auth = context.read<AuthProvider>();
    context.read<WalletProvider>().loadWallet(auth.passengerContact);
  }

  void _addMoney() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackbar('Enter a valid amount', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final auth = context.read<AuthProvider>();
      
      // 1. Request server to create Razorpay Order
      final orderData = await ApiService.initiatePayment(amount, 'wallet_topup');
      final bool isMockOrder = orderData['mock'] == true;

      if (isMockOrder) {
        // Razorpay is not configured on backend. Show simulated test mode dialog.
        _showSimulatedPaymentDialog(amount, orderData['orderId']);
      } else {
        // Launch standard Razorpay Checkout Gateway
        final options = {
          'key': orderData['keyId'],
          'amount': orderData['amount'], // paise
          'name': 'SpotX Digital Transit',
          'description': 'Wallet Top-up',
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
      _showSnackbar(e.toString().replaceAll('Exception: ', ''), isError: true);
      setState(() => _isProcessing = false);
    }
  }

  // Simulated payment dialog for mock mode when Razorpay keys are not provided on backend
  void _showSimulatedPaymentDialog(double amount, String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.payment_rounded, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Text('Simulated Payment', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text(
            'This is SpotX Razorpay Test Mode. Simulating a payment of ₹${amount.toStringAsFixed(0)} for Order: $orderId.',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() => _isProcessing = false);
              },
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // Simulate success payload
                final mockPaymentId = 'pay_mock_${DateTime.now().millisecondsSinceEpoch}';
                final mockSignature = 'sig_mock_${DateTime.now().millisecondsSinceEpoch}';
                await _verifyServerPayment(orderId, mockPaymentId, mockSignature);
              },
              child: const Text('PAY SUCCESS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verifyServerPayment(String orderId, String paymentId, String signature) async {
    try {
      final auth = context.read<AuthProvider>();
      
      // 2. Request server signature verification and credit
      final verifyResult = await ApiService.verifyPaymentSignature(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
        purpose: 'wallet_topup',
      );

      // Sync backend wallet state with local provider
      final double newBalance = (verifyResult['walletBalance'] as num?)?.toDouble() ?? 0.0;
      await context.read<WalletProvider>().addMoney(newBalance - context.read<WalletProvider>().balance, 'UPI/Razorpay Gateway');
      
      _amountCtrl.clear();
      _showSnackbar('₹${(newBalance - context.read<WalletProvider>().balance).toStringAsFixed(0)} added to wallet successfully!');
      _refreshWallet();
    } catch (e) {
      _showSnackbar('Verification failed: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ─── Razorpay Event Handlers ────────────────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('[PAYMENT] Razorpay success: ${response.orderId}');
    _verifyServerPayment(response.orderId ?? '', response.paymentId ?? '', response.signature ?? '');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('[PAYMENT] Razorpay error: ${response.message}');
    _showSnackbar('Payment failed: ${response.message}', isError: true);
    setState(() => _isProcessing = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('[PAYMENT] External wallet selected: ${response.walletName}');
    _showSnackbar('External wallet not supported in test mode.', isError: true);
    setState(() => _isProcessing = false);
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      behavior: SnackBarBehavior.floating,
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
        title: const Text('Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AVAILABLE BALANCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFBFD3FC), letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text('₹${wallet.balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Add money form
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOP UP WALLET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.currency_rupee, color: Colors.grey[400], size: 18),
                              hintText: 'Enter amount',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isProcessing ? null : _addMoney,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _isProcessing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('ADD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transactions list
            const Text('TRANSACTIONS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5)),
            const SizedBox(height: 12),
            if (wallet.transactions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No transactions yet', style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            else
              ...wallet.transactions.map((tx) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: tx.type == 'credit' ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        tx.type == 'credit' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: tx.type == 'credit' ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                          const SizedBox(height: 2),
                          Text(tx.timestamp.split('T').first, style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Text(
                      '${tx.type == 'credit' ? '+' : '-'}₹${tx.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900,
                        color: tx.type == 'credit' ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}
