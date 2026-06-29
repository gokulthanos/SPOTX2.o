import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  bool _submitted = false;

  void _handleReset() {
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your email to proceed.', style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitted = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            // Background decorations
            Positioned(
              top: -60, right: -60,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -80, left: -80,
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text('RETURN TO LOGIN',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey[500], letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Center card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: _submitted ? _buildSuccessView() : _buildFormView(),
                  ),
                  const Spacer(),
                  Center(
                    child: Text('Automated security system by SPOTX',
                      style: TextStyle(fontSize: 9, color: Colors.grey[300], fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.key_rounded, color: Color(0xFF4F46E5), size: 40),
        ),
        const SizedBox(height: 20),
        const Text('Recovery',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        Text('Enter your registered email to receive a temporary reset link.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w500, height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.mail_outline_rounded, color: Colors.grey[400], size: 20),
              hintText: 'Email Address',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 8,
              shadowColor: const Color(0xFF4F46E5).withOpacity(0.3),
            ),
            child: const Text('SEND RESET LINK',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 40),
        ),
        const SizedBox(height: 20),
        const Text('Sent!',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        Text('Recovery instructions have been dispatched to your inbox.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[400], height: 1.5),
        ),
        const SizedBox(height: 16),
        const CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2),
        const SizedBox(height: 8),
        Text('Redirecting...', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      ],
    );
  }
}
