import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../models/ticket.dart';

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  final _ticketCtrl = TextEditingController();
  bool _loading = false;
  Ticket? _ticketDetails;
  String _error = '';
  double _dailyGoalProgress = 0.45; // mock progress 45%

  @override
  void dispose() {
    _ticketCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyTicket() async {
    final ticketNumber = _ticketCtrl.text.trim();
    if (ticketNumber.isEmpty) {
      setState(() => _error = 'Enter ticket number');
      return;
    }
    setState(() { _loading = true; _error = ''; _ticketDetails = null; });
    try {
      final ticket = await ApiService.verifyTicket(ticketNumber);
      if (!mounted) return;
      setState(() => _ticketDetails = ticket);
      // Record check for analytics (optional)
      await StorageService.addCheckedTicket(ticketNumber);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _issueFine() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fine issued (mock)')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        title: const Text('Officer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await auth.logout();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _goalGauge(),
              const SizedBox(height: 24),
              _ticketSection(),
              const SizedBox(height: 24),
              _finePanel(),
              const SizedBox(height: 24),
              if (auth.isAdmin) _adminPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalGauge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Check Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: _dailyGoalProgress,
                strokeWidth: 12,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            ),
            Text('\${(_dailyGoalProgress * 100).toInt()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _ticketSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ticket Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        TextField(
          controller: _ticketCtrl,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.confirmation_number_rounded),
            hintText: 'Enter 4‑digit Ticket ID',
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _loading ? null : _verifyTicket,
          icon: const Icon(Icons.search_rounded),
          label: const Text('VERIFY'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
        if (_ticketDetails != null) _ticketDetailsCard(),
      ],
    );
  }

  Widget _ticketDetailsCard() {
    final t = _ticketDetails!;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ticket #: ${t.ticketNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('From ${t.fromStop} → ${t.toStop}'),
            const SizedBox(height: 4),
            Text('Status: ${t.status}'),
            const SizedBox(height: 4),
            Text('Fare: ₹${t.totalFare.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _finePanel() {
    final _fineCtrl = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Issue Fine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        TextField(
          controller: _fineCtrl,
          decoration: const InputDecoration(
            hintText: 'Enter fine amount (₹)',
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            if (_fineCtrl.text.trim().isEmpty) return;
            _issueFine();
            _fineCtrl.clear();
          },
          child: const Text('ISSUE FINE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _adminPanel() {
    final _emailCtrl = TextEditingController();
    final _nameCtrl = TextEditingController();
    final _roleCtrl = TextEditingController(text: 'STAFF');
    final _passwordCtrl = TextEditingController();

    Future<void> _registerStaff() async {
      final email = _emailCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      final role = _roleCtrl.text.trim().toUpperCase();
      final password = _passwordCtrl.text;
      if (email.isEmpty || name.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All fields required')));
        return;
      }
      try {
        await ApiService.registerStaff(name: name, email: email, password: password, role: role);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff registered (mock)')));
        _emailCtrl.clear();
        _nameCtrl.clear();
        _passwordCtrl.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Admin Panel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
        const SizedBox(height: 8),
        TextField(controller: _emailCtrl, decoration: const InputDecoration(hintText: 'Officer Email', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 8),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),),
        const SizedBox(height: 8),
        TextField(controller: _roleCtrl, decoration: const InputDecoration(hintText: 'Role (ADMIN/STAFF)', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),),
        const SizedBox(height: 8),
        TextField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _registerStaff,
          child: const Text('REGISTER STAFF'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ],
    );
  }
}
