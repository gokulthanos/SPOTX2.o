import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class CheckTicketPage extends StatefulWidget {
  const CheckTicketPage({super.key});
  @override
  State<CheckTicketPage> createState() => _CheckTicketPageState();
}

class _CheckTicketPageState extends State<CheckTicketPage> {
  final _pnrCtrl = TextEditingController();
  bool _isVerifying = false;
  bool _showScanner = false;
  Map<String, dynamic>? _result;
  String? _resultType; // 'valid', 'invalid', 'expired'
  String? _error;

  @override
  void dispose() { _pnrCtrl.dispose(); super.dispose(); }

  Future<void> _verify(String pnr) async {
    if (pnr.trim().isEmpty) {
      setState(() { _error = 'Enter a PNR number'; _result = null; _resultType = null; });
      return;
    }
    setState(() { _isVerifying = true; _error = null; _result = null; _resultType = null; });
    try {
      final res = await ApiService.verifyTicket(pnr.trim());
      final data = res['data'] ?? res;
      final result = data['result'] ?? data['verification'] ?? 'invalid';
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _result = data;
          _resultType = result.toString();
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isVerifying = false; _error = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  void _onQrScanned(String barcode) {
    if (barcode.isNotEmpty && !_isVerifying) {
      setState(() => _showScanner = false);
      _pnrCtrl.text = barcode;
      _verify(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(title: const Text('Check Ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_showScanner) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 280,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final barcode = capture.barcodes.firstOrNull?.rawValue ?? '';
                      _onQrScanned(barcode);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => setState(() => _showScanner = false), child: const Text('Cancel Scanner')),
              const SizedBox(height: 16),
            ],
            if (!_showScanner) ...[
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showScanner = true),
                  icon: const Icon(Icons.qr_code_scanner, size: 22),
                  label: const Text('Scan QR Code', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _pnrCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter PNR Number', filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : () => _verify(_pnrCtrl.text),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _isVerifying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Verify'),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 24),
            if (_isVerifying)
              const CircularProgressIndicator(color: AppTheme.primaryNavy)
            else if (_error != null)
              _errorCard(_error!)
            else if (_result != null)
              _resultCard(),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.error.withValues(alpha: 0.2))),
      child: Column(children: [
        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
        const SizedBox(height: 12),
        Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.error)),
      ]),
    );
  }

  Widget _resultCard() {
    final isValid = _resultType == 'valid';
    final color = isValid ? AppTheme.success : AppTheme.error;
    final icon = isValid ? Icons.check_circle_outline : Icons.cancel_outlined;
    final text = isValid ? 'VALID TICKET' : 'INVALID OR EXPIRED';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3), width: 2)),
      child: Column(children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 12),
        Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
        if (_result?['passenger_name'] != null) ...[
          const SizedBox(height: 16),
          _info('Passenger', _result!['passenger_name']),
          _info('Route', '${_result!['boarding_stop_name'] ?? ''} → ${_result!['destination_stop_name'] ?? ''}'),
          _info('PNR', _result!['pnr'] ?? ''),
          _info('Bus', _result!['bus_number'] ?? ''),
        ],
      ]),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
