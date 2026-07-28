import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_mobileCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, '/passenger/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Login failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1F3B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.directions_bus_filled, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text('Welcome Back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 6),
                  Text('Sign in to your SpotX account', style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 36),
                  _buildField(_mobileCtrl, 'Mobile Number', Icons.phone_outlined, keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.length < 10) ? 'Enter valid mobile' : null),
                  const SizedBox(height: 16),
                  _buildField(_passwordCtrl, 'Password', Icons.lock_outline, obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    validator: (v) => (v == null || v.length < 4) ? 'Enter password' : null),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? true),
                        activeColor: const Color(0xFF1B1F3B),
                      ),
                      const Text('Remember Me', style: TextStyle(fontSize: 13)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/auth/forgot-password'),
                        child: const Text('Forgot Password?', style: TextStyle(fontSize: 13, color: Color(0xFFFF6B35))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B1F3B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/auth/register'),
                        child: const Text('Register', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFF6B35))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/auth/otp', arguments: {'flow': 'login'}),
                    child: const Text('Login with OTP', style: TextStyle(fontSize: 13, color: Color(0xFF1B1F3B))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false, Widget? suffix, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
