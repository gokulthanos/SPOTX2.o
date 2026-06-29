import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../passenger/passenger_dashboard.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

enum _Step { details, otp, password, success }

class _SignupPageState extends State<SignupPage> {
  _Step _step = _Step.details;
  bool _loading = false;

  // Step 1
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String _devOtp = '';

  // Step 2
  final _otpCtrl = TextEditingController();

  // Step 3
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _passVisible = false;

  bool _isEmail(String s) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
  bool _isPhone(String s) => RegExp(r'^\d{10}$').hasMatch(s);

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _handleRequestOtp() async {
    final name = _nameCtrl.text.trim();
    final contact = _contactCtrl.text.trim();
    if (name.isEmpty) { _showSnack('Enter your full name', error: true); return; }
    if (contact.isEmpty) { _showSnack('Enter email or phone number', error: true); return; }
    if (!_isEmail(contact) && !_isPhone(contact)) {
      _showSnack('Enter a valid email or 10-digit phone number', error: true); return;
    }
    setState(() => _loading = true);
    try {
      final data = await ApiService.requestOtp(name, contact);
      if (data['devOtp'] != null) setState(() => _devOtp = data['devOtp'].toString());
      _showSnack('OTP sent! Check your ${_isEmail(contact) ? "email" : "phone"}');
      setState(() => _step = _Step.otp);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) { _showSnack('Enter the 6-digit OTP', error: true); return; }
    setState(() => _loading = true);
    try {
      await ApiService.verifyOtp(_contactCtrl.text.trim(), otp);
      _showSnack('OTP Verified ✅ Now create your password');
      setState(() => _step = _Step.password);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSetPassword() async {
    final pass = _passCtrl.text;
    final confirm = _confirmPassCtrl.text;
    if (pass.length < 6) { _showSnack('At least 6 characters required', error: true); return; }
    if (pass != confirm) { _showSnack('Passwords do not match', error: true); return; }
    setState(() => _loading = true);
    try {
      final data = await ApiService.setPassword(_contactCtrl.text.trim(), pass);
      if (!mounted) return;
      await context.read<AuthProvider>().loginPassenger(
        name: data['fullName'] ?? _nameCtrl.text.trim(),
        contact: data['contact'] ?? _contactCtrl.text.trim(),
        token: data['token'] ?? '',
      );
      setState(() => _step = _Step.success);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PassengerDashboard()),
          );
        }
      });
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _contactCtrl.dispose(); _otpCtrl.dispose();
    _passCtrl.dispose(); _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepIndex = _step.index.clamp(0, 2);
    final steps = ['Your Details', 'Verify OTP', 'Set Password'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Back / header
              if (_step != _Step.success)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () {
                      if (_step == _Step.details) Navigator.pop(context);
                      else if (_step == _Step.otp) setState(() => _step = _Step.details);
                      else setState(() => _step = _Step.otp);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded, size: 16, color: Color(0xFF64748B)),
                    ),
                  ),
                ),

              // Icon
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Create Account',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
              Text('Join SPOTX to start your smart travel',
                style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              // Progress steps
              if (_step != _Step.success) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(steps.length, (i) {
                    final done = i < stepIndex;
                    final current = i == stepIndex;
                    return Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: done ? const Color(0xFF22C55E) : current ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: current ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 12)] : [],
                          ),
                          child: Center(
                            child: done
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                              : Text('${i + 1}', style: TextStyle(
                                  color: current ? Colors.white : Colors.grey[400],
                                  fontWeight: FontWeight.w900, fontSize: 13)),
                          ),
                        ),
                        if (i < steps.length - 1)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 28, height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: done ? const Color(0xFF22C55E) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 28),
              ],

              // Form body
              _buildStepContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _Step.details:
        return _buildDetailsStep();
      case _Step.otp:
        return _buildOtpStep();
      case _Step.password:
        return _buildPasswordStep();
      case _Step.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildDetailsStep() {
    return Column(
      children: [
        _inputField(ctrl: _nameCtrl, label: 'Full Name', hint: 'Enter full name', icon: Icons.person_outline_rounded),
        const SizedBox(height: 16),
        _inputField(ctrl: _contactCtrl, label: 'Contact Info', hint: 'Email or phone', icon: Icons.contact_phone_outlined),
        const SizedBox(height: 24),
        _primaryBtn('GET STARTED', _handleRequestOtp),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account? ', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text('Sign In', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text('Verify contact', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(_contactCtrl.text, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
            ],
          ),
        ),
        if (_devOtp.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Text('DEV SYSTEM OVERRIDE — OTP', style: TextStyle(fontSize: 9, color: Colors.indigo[300], letterSpacing: 2, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(_devOtp, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 12)),
                const SizedBox(height: 4),
                Text('Visible only in testing mode', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _inputField(
          ctrl: _otpCtrl, label: 'Verification Code', hint: '0  0  0  0  0  0',
          icon: Icons.shield_outlined,
          keyboardType: TextInputType.number,
          maxLength: 6,
          centered: true,
          largeFont: true,
        ),
        const SizedBox(height: 24),
        _primaryBtn('CONFIRM OTP', _handleVerifyOtp),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      children: [
        _inputField(ctrl: _passCtrl, label: 'New Password', hint: '••••••••', icon: Icons.lock_outline_rounded, isPassword: true, visible: _passVisible, onToggle: () => setState(() => _passVisible = !_passVisible)),
        const SizedBox(height: 16),
        _inputField(ctrl: _confirmPassCtrl, label: 'Confirm Password', hint: '••••••••', icon: Icons.lock_outline_rounded, isPassword: true, visible: _passVisible, onToggle: () => setState(() => _passVisible = !_passVisible)),
        const SizedBox(height: 24),
        _primaryBtn('CREATE ACCOUNT', _handleSetPassword),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 60),
        ),
        const SizedBox(height: 20),
        const Text('Welcome to SPOTX!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text('Account created successfully', style: TextStyle(color: Colors.grey[400])),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2),
        const SizedBox(height: 8),
        Text('Entering dashboard...', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool visible = false,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    bool centered = false,
    bool largeFont = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 1.5),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: isPassword && !visible,
            keyboardType: keyboardType,
            maxLength: maxLength,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: largeFont ? 24 : 14,
              color: const Color(0xFF4F46E5),
              letterSpacing: largeFont ? 8 : 0,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[300], fontSize: largeFont ? 20 : 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              counterText: '',
              suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[400], size: 18),
                    onPressed: onToggle,
                  )
                : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryBtn(String label, VoidCallback action) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : action,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          shadowColor: const Color(0xFF4F46E5).withOpacity(0.3),
        ),
        child: _loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
    );
  }
}
