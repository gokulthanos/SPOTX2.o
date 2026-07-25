import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../auth/landing_page.dart';
import 'package:provider/provider.dart';

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _todayVerifications = 0;
  int _todayFines = 0;
  List<Map<String, dynamic>> _fineHistory = [];
  List<Map<String, dynamic>> _scanHistory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      _scanHistory = StorageService.getCheckedTickets();
      _todayVerifications = _scanHistory.where((t) {
        final date = t['checkedAt'] ?? '';
        return date.startsWith(DateTime.now().toIso8601String().substring(0, 10));
      }).length;

      _fineHistory = await ApiService.fetchFines();
      _todayFines = _fineHistory.where((f) {
        final date = f['created_at'] ?? '';
        return date.startsWith(DateTime.now().toIso8601String().substring(0, 10));
      }).length;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Officer Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text('${auth.officerName} • ${auth.officerRole}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await auth.logout();
              if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandingPage()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          tabs: const [
            Tab(text: 'DASHBOARD', icon: Icon(Icons.dashboard_rounded, size: 18)),
            Tab(text: 'SCAN', icon: Icon(Icons.qr_code_scanner_rounded, size: 18)),
            Tab(text: 'FINES', icon: Icon(Icons.gavel_rounded, size: 18)),
            Tab(text: 'SEARCH', icon: Icon(Icons.search_rounded, size: 18)),
            Tab(text: 'ADMIN', icon: Icon(Icons.admin_panel_settings_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildScanTab(),
          _buildFinesTab(),
          _buildSearchTab(),
          _buildAdminTab(auth),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TODAY'S PERFORMANCE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('VERIFICATIONS', '$_todayVerifications', Icons.qr_code_scanner_rounded, AppTheme.primaryBlue)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('FINES ISSUED', '$_todayFines', Icons.gavel_rounded, AppTheme.warning)),
            ],
          ),
          const SizedBox(height: 20),
          AppTheme.sectionLabel('SCAN HISTORY'),
          const SizedBox(height: 12),
          if (_scanHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration,
              child: const Center(child: Text('No scans today', style: TextStyle(color: AppTheme.textMuted))),
            )
          else
            ...(_scanHistory.take(5).map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration,
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s['ticketNumber'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
                  Text(s['checkedAt'] ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ))),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  String _manualTicketId = '';

  Widget _buildScanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryBlue, size: 64),
                SizedBox(height: 12),
                Text('Tap to Scan QR Code', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                Text('Point camera at ticket QR', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppTheme.sectionLabel('MANUAL TICKET LOOKUP'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => _manualTicketId = v,
                  decoration: const InputDecoration(hintText: 'Enter Ticket ID'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _verifyTicket(_manualTicketId),
                child: const Text('VERIFY'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _verifyTicket(String ticketId) async {
    if (ticketId.isEmpty) return;
    try {
      final ticket = await ApiService.verifyTicket(ticketId);
      if (ticket != null && mounted) {
        await StorageService.addCheckedTicket(ticketId);
        _loadStats();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 48),
                const SizedBox(height: 12),
                Text('Ticket #$ticketId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${ticket.fromStop} → ${ticket.toStop}', style: const TextStyle(color: AppTheme.textSecondary)),
                Text('₹${ticket.totalFare.toStringAsFixed(0)} • ${ticket.status}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  String _finePassenger = '';
  String _fineReason = '';
  double _fineAmount = 500;

  Widget _buildFinesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTheme.sectionLabel('ISSUE FINE'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecoration,
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => _finePassenger = v,
                  decoration: const InputDecoration(hintText: 'Passenger mobile number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => _fineReason = v,
                  decoration: const InputDecoration(hintText: 'Reason for fine'),
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _fineAmount = double.tryParse(v) ?? 500,
                  decoration: const InputDecoration(hintText: 'Amount (default: 500)'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _issueFine,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
                    child: const Text('ISSUE FINE'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppTheme.sectionLabel('FINE HISTORY'),
          const SizedBox(height: 12),
          ..._fineHistory.map((f) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecoration,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.gavel_rounded, color: AppTheme.warning, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f['passenger_contact'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(f['reason'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${f['amount'] ?? 0}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.error)),
                    Text(f['status'] ?? 'unpaid', style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _issueFine() async {
    if (_finePassenger.isEmpty || _fineReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Passenger contact and reason are required'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    try {
      await ApiService.issueFine(
        passengerContact: _finePassenger,
        reason: _fineReason,
        amount: _fineAmount,
      );
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fine issued successfully'),
          backgroundColor: AppTheme.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  Widget _buildSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTheme.sectionLabel('PASSENGER SEARCH'),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search by contact or ticket number...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onSubmitted: (v) async {
              if (v.isNotEmpty) {
                try {
                  final ticket = await ApiService.verifyTicket(v);
                  if (ticket != null && mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text('Ticket #${ticket.ticketNumber}'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Route: ${ticket.fromStop} → ${ticket.toStop}'),
                            Text('Fare: ₹${ticket.totalFare.toStringAsFixed(0)}'),
                            Text('Status: ${ticket.status}'),
                            Text('Passengers: ${ticket.passengers.length}'),
                          ],
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Not found: $e'),
                      backgroundColor: AppTheme.error,
                    ));
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTab(AuthProvider auth) {
    if (!auth.isAdmin) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('Admin access required', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTheme.sectionLabel('REGISTER STAFF'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecoration,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Full Name'),
                  onChanged: (v) => _regName = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(hintText: 'Email'),
                  onChanged: (v) => _regEmail = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Password'),
                  onChanged: (v) => _regPassword = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: 'STAFF',
                  items: const [
                    DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                  ],
                  onChanged: (v) => _regRole = v ?? 'STAFF',
                  decoration: const InputDecoration(hintText: 'Role'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _registerStaff,
                    child: const Text('REGISTER'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _regName = '';
  String _regEmail = '';
  String _regPassword = '';
  String _regRole = 'STAFF';

  Future<void> _registerStaff() async {
    if (_regName.isEmpty || _regEmail.isEmpty || _regPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All fields are required'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    try {
      await ApiService.registerStaff(name: _regName, email: _regEmail, password: _regPassword, role: _regRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Staff registered successfully'),
          backgroundColor: AppTheme.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
      }
    }
  }
}
