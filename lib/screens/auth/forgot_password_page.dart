import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _mobileCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  int _step = 1;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.requestOtp(_mobileCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      setState(() => _step = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent! Check server console.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Failed'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.forgotPassword(_mobileCtrl.text.trim(), _otpCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset! Login now.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text('Forgot Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (_step == 1) ...[
                const Icon(Icons.lock_reset, size: 48, color: Color(0xFF1B1F3B)),
                const SizedBox(height: 16),
                const Text('Reset Password', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Enter your mobile number to receive OTP', style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 32),
                _field(_mobileCtrl, 'Mobile Number', Icons.phone_outlined, TextInputType.phone),
                const SizedBox(height: 24),
                _button('Send OTP', auth.isLoading, _sendOtp),
              ],
              if (_step == 2) ...[
                const Icon(Icons.lock_outline, size: 48, color: Color(0xFF1B1F3B)),
                const SizedBox(height: 16),
                const Text('Enter OTP & New Password', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 32),
                _field(_otpCtrl, 'OTP Code', Icons.pin_outlined, TextInputType.number),
                const SizedBox(height: 16),
                _field(_passCtrl, 'New Password', Icons.lock_outline, TextInputType.visiblePassword, obscure: true),
                const SizedBox(height: 16),
                _field(_confirmCtrl, 'Confirm Password', Icons.lock_outline, TextInputType.visiblePassword, obscure: true),
                const SizedBox(height: 24),
                _button('Reset Password', auth.isLoading, _resetPassword),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, TextInputType kb, {bool obscure = false}) {
    return TextFormField(
      controller: ctrl, keyboardType: kb, obscureText: obscure,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, size: 20),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _button(String label, bool loading, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B1F3B), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
