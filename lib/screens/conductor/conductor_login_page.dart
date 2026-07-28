import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import 'conductor_dashboard.dart';

class ConductorLoginPage extends StatefulWidget {
  const ConductorLoginPage({super.key});
  @override
  State<ConductorLoginPage> createState() => _ConductorLoginPageState();
}

class _ConductorLoginPageState extends State<ConductorLoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() { _userCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter username and password'), backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.conductorLogin(_userCtrl.text.trim(), _passCtrl.text);
      final conductorData = data['data'] ?? data;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConductorDashboard(conductorData: conductorData['conductor'] ?? conductorData),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppTheme.primaryNavy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.badge_outlined, size: 40, color: AppTheme.primaryNavy),
              ),
              const SizedBox(height: 20),
              const Text('SpotX Conductor', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('Sign in to your conductor account', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              const SizedBox(height: 40),
              _field(_userCtrl, 'Username', Icons.person_outline, false),
              const SizedBox(height: 16),
              _field(_passCtrl, 'Password', Icons.lock_outline, true),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Demo: conductor1 / pass123', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, bool isPassword) {
    return TextFormField(
      controller: ctrl, obscureText: isPassword && _obscure,
      onFieldSubmitted: isPassword ? (_) => _login() : null,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, size: 20),
        suffixIcon: isPassword ? IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), onPressed: () => setState(() => _obscure = !_obscure)) : null,
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 2)),
      ),
    );
  }
}
