import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class DigitalPassPage extends StatelessWidget {
  const DigitalPassPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contact = auth.passengerContact;
    final name = auth.passengerName.isNotEmpty ? auth.passengerName : 'Transit Pass';
    final passId = 'SPX-$contact';

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(title: const Text('Digital Pass')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primaryBlue, AppTheme.primaryLight],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30, top: -30,
                    child: Icon(Icons.directions_bus_rounded, size: 140, color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SPOTX DIGITAL PASS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                                Text('Tamil Nadu Transit Authority', style: TextStyle(fontSize: 10, color: Color(0xFFBFDBFE))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(contact, style: const TextStyle(fontSize: 14, color: Color(0xFFBFDBFE), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _passInfo('PASS ID', passId),
                            const SizedBox(width: 24),
                            _passInfo('VALID', 'Active'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  const Text('SCAN AT TURNSTILE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: passId,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: passId));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Pass ID copied to clipboard'),
                        backgroundColor: AppTheme.success,
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: AppTheme.surfaceWhite, borderRadius: BorderRadius.circular(10)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary),
                          SizedBox(width: 6),
                          Text('Copy Pass ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTheme.sectionLabel('PASS DETAILS'),
                  const SizedBox(height: 12),
                  _detailRow('Passenger Name', name),
                  _detailRow('Contact', contact),
                  _detailRow('Pass Type', 'General Transit'),
                  _detailRow('Coverage', 'All TNSTC Routes'),
                  _detailRow('Status', 'Active'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFBFDBFE), letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
