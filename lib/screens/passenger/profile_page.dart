import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  String _gender = 'Male';
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final auth = context.read<AuthProvider>();
    final p = auth.passenger;
    _nameCtrl.text = p?.fullName ?? '';
    _emailCtrl.text = p?.email ?? '';
    _emergencyCtrl.text = p?.emergencyContact ?? '';
    _gender = p?.gender ?? 'Male';
  }

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _emergencyCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile({
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'gender': _gender,
      'emergency_contact': _emergencyCtrl.text.trim(),
    });
    setState(() { _isSaving = false; _isEditing = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Profile updated' : 'Failed to update'),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final p = auth.passenger;

    return Scaffold(
      backgroundColor: AppTheme.surfaceGray,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isEditing)
            TextButton(onPressed: _isSaving ? null : _save, child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.accentOrange))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration,
              child: Column(children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                  child: Text((p?.fullName ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
                ),
                const SizedBox(height: 12),
                Text(p?.fullName ?? 'User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('+91 ${p?.mobile ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('Personal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _isEditing = !_isEditing),
                      child: Icon(_isEditing ? Icons.close : Icons.edit_outlined, size: 20, color: AppTheme.primaryNavy),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _field(_nameCtrl, 'Full Name', Icons.person_outline, _isEditing),
                  const SizedBox(height: 12),
                  _field(_emailCtrl, 'Email', Icons.email_outlined, _isEditing),
                  const SizedBox(height: 12),
                  _field(_emergencyCtrl, 'Emergency Contact', Icons.phone_outlined, _isEditing),
                  const SizedBox(height: 12),
                  if (_isEditing)
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: InputDecoration(
                        labelText: 'Gender', filled: true, fillColor: AppTheme.surfaceGray,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setState(() => _gender = v ?? _gender),
                    )
                  else
                    _readOnly('Gender', _gender),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 48,
              child: OutlinedButton(
                onPressed: () {
                  auth.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                },
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, bool enabled) {
    return TextField(
      controller: ctrl, enabled: enabled,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, size: 20), filled: true, fillColor: AppTheme.surfaceGray,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
      ),
    );
  }

  Widget _readOnly(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surfaceGray, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
