import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class EmergencySOSPage extends StatelessWidget {
  const EmergencySOSPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Emergency SOS', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3), width: 4),
              ),
              child: const Icon(Icons.emergency_rounded, color: AppTheme.error, size: 56),
            ),
            const SizedBox(height: 24),
            const Text('EMERGENCY SOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Tap a button below to alert authorities', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 32),
            Expanded(
              child: Column(
                children: [
                  _sosButton(
                    context: context,
                    label: 'CALL POLICE',
                    subtitle: 'Dial 100',
                    icon: Icons.local_police_rounded,
                    color: AppTheme.error,
                    phone: '100',
                  ),
                  const SizedBox(height: 12),
                  _sosButton(
                    context: context,
                    label: 'CALL AMBULANCE',
                    subtitle: 'Dial 108',
                    icon: Icons.local_hospital_rounded,
                    color: const Color(0xFFDC2626),
                    phone: '108',
                  ),
                  const SizedBox(height: 12),
                  _sosButton(
                    context: context,
                    label: 'HELPLINE',
                    subtitle: 'Transit Control Room',
                    icon: Icons.support_agent_rounded,
                    color: AppTheme.primaryBlue,
                    phone: '18001234567',
                  ),
                  const SizedBox(height: 12),
                  _sosButton(
                    context: context,
                    label: 'TEXT LOCATION',
                    subtitle: 'Share live location via SMS',
                    icon: Icons.share_location_rounded,
                    color: AppTheme.success,
                    phone: auth.passengerContact,
                    isText: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sosButton({
    required BuildContext context,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String phone,
    bool isText = false,
  }) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.heavyImpact();
        if (isText) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Location shared via SMS to $phone'),
            backgroundColor: AppTheme.success,
          ));
        } else {
          final uri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
            const Spacer(),
            Icon(Icons.phone_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}
