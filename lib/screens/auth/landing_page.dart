import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import '../passenger/passenger_dashboard.dart';
import '../officer/officer_dashboard.dart';
import '../admin/admin_panel.dart';
import '../admin/government_dashboard_page.dart';
import '../kiosk/kiosk_mode_page.dart';
import '../driver/driver_dashboard.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Passenger form
  final _passengerEmailCtrl = TextEditingController();
  final _passengerPassCtrl = TextEditingController();
  // Officer form
  final _officerIdCtrl = TextEditingController();
  final _officerPassCtrl = TextEditingController();

  bool _passengerLoading = false;
  bool _officerLoading = false;
  bool _passengerPassVisible = false;
  bool _officerPassVisible = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _error = '');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _passengerEmailCtrl.dispose();
    _passengerPassCtrl.dispose();
    _officerIdCtrl.dispose();
    _officerPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePassengerLogin() async {
    setState(() { _error = ''; _passengerLoading = true; });
    final contact = _passengerEmailCtrl.text.trim();
    final password = _passengerPassCtrl.text;

    if (contact.isEmpty || password.isEmpty) {
      setState(() { _error = 'Please enter email/phone and password'; _passengerLoading = false; });
      return;
    }
    try {
      final data = await ApiService.passengerLogin(contact, password);
      if (!mounted) return;
      await context.read<AuthProvider>().loginPassenger(
        name: data['fullName'] ?? '',
        contact: data['contact'] ?? contact,
        token: data['token'] ?? '',
        refreshToken: data['refreshToken'] ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PassengerDashboard()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _passengerLoading = false);
    }
  }

  Future<void> _handleOfficerLogin() async {
    setState(() { _error = ''; _officerLoading = true; });
    final govId = _officerIdCtrl.text.trim().toUpperCase();
    final password = _officerPassCtrl.text;

    if (govId.isEmpty) {
      setState(() { _error = 'Please enter Government ID'; _officerLoading = false; });
      return;
    }
    if (password.isEmpty) {
      setState(() { _error = 'Please enter your password'; _officerLoading = false; });
      return;
    }
    try {
      final data = await ApiService.officerLogin(govId, password);
      if (!mounted) return;
      await context.read<AuthProvider>().loginOfficer(
        officerId: govId,
        name: data['name'] ?? '',
        role: data['role'] ?? 'STAFF',
        token: data['token'] ?? '',
        refreshToken: data['refreshToken'] ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => data['role'] == 'ADMIN'
            ? const AdminPanel()
            : const OfficerDashboard()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _officerLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isInitialized && auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (auth.isPassenger) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PassengerDashboard()),
          );
        } else if (auth.isOfficer) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OfficerDashboard()),
          );
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo & Branding
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 16),
                const Text('SPOTX',
                  style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B), letterSpacing: 3,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Rural transit, Simplified.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),

                // Heading
                Text(
                  _tabController.index == 0 ? 'Hello Traveler 👋' : _tabController.index == 1 ? 'Officer Login' : 'Driver Login',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Text('Access your digital transit dashboard',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),

                // Tab switch
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
                      ],
                    ),
                    labelColor: const Color(0xFF4F46E5),
                    unselectedLabelColor: Colors.grey[500],
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                    tabs: const [
                      Tab(text: 'PASSENGER'),
                      Tab(text: 'GOVERNMENT'),
                      Tab(text: 'DRIVER'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Error Banner
                if (_error.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error,
                            style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Form based on tab
                SizedBox(
                  height: 360,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPassengerForm(),
                      _buildOfficerForm(),
                      _buildDriverForm(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Quick Access Buttons
                Row(
                  children: [
                    Expanded(
                      child: _quickAccessButton(
                        label: 'KIOSK MODE',
                        icon: Icons.touch_app_rounded,
                        color: const Color(0xFF16A34A),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KioskModePage())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickAccessButton(
                        label: 'GOV DASHBOARD',
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFF2563EB),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GovernmentDashboardPage())),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _quickAccessButton(
                        label: 'ADMIN PANEL',
                        icon: Icons.admin_panel_settings_rounded,
                        color: const Color(0xFF7C3AED),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickAccessButton(
                        label: 'SOS EMERGENCY',
                        icon: Icons.emergency_rounded,
                        color: const Color(0xFFDC2626),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerDashboard()));
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerForm() {
    return Column(
      children: [
        _inputLabel('Credentials'),
        const SizedBox(height: 6),
        _textField(
          controller: _passengerEmailCtrl,
          hint: 'Email or Phone',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 16),
        _inputLabel('Secret Key'),
        const SizedBox(height: 6),
        _textField(
          controller: _passengerPassCtrl,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          visible: _passengerPassVisible,
          onToggleVisibility: () => setState(() => _passengerPassVisible = !_passengerPassVisible),
          trailing: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
            child: const Text('Forgot?', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 24),
        _primaryButton(
          label: 'Explore Dashboard',
          loading: _passengerLoading,
          onPressed: _handlePassengerLogin,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Don't have an account? ", style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage())),
              child: const Text('Sign up now', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOfficerForm() {
    return Column(
      children: [
        _inputLabel('Officer ID'),
        const SizedBox(height: 6),
        _textField(
          controller: _officerIdCtrl,
          hint: 'TN58XXXMDU',
          icon: Icons.badge_outlined,
          upperCase: true,
        ),
        const SizedBox(height: 16),
        _inputLabel('Secure Pass'),
        const SizedBox(height: 6),
        _textField(
          controller: _officerPassCtrl,
          hint: '••••••••',
          icon: Icons.shield_outlined,
          isPassword: true,
          visible: _officerPassVisible,
          onToggleVisibility: () => setState(() => _officerPassVisible = !_officerPassVisible),
        ),
        const SizedBox(height: 24),
        _primaryButton(
          label: 'Access Officer Panel',
          loading: _officerLoading,
          onPressed: _handleOfficerLogin,
        ),
      ],
    );
  }

  Widget _buildDriverForm() {
    return Column(
      children: [
        _inputLabel('Employee ID'),
        const SizedBox(height: 6),
        _textField(
          controller: _officerIdCtrl,
          hint: 'DRIVER@SPOTX.IN',
          icon: Icons.directions_bus_rounded,
          upperCase: true,
        ),
        const SizedBox(height: 16),
        _inputLabel('Password'),
        const SizedBox(height: 6),
        _textField(
          controller: _officerPassCtrl,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          visible: _officerPassVisible,
          onToggleVisibility: () => setState(() => _officerPassVisible = !_officerPassVisible),
        ),
        const SizedBox(height: 24),
        _primaryButton(
          label: 'Start Driving',
          loading: _officerLoading,
          onPressed: _handleDriverLogin,
        ),
      ],
    );
  }

  Future<void> _handleDriverLogin() async {
    setState(() { _error = ''; _officerLoading = true; });
    final email = _officerIdCtrl.text.trim();
    final password = _officerPassCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() { _error = 'Please enter employee ID and password'; _officerLoading = false; });
      return;
    }
    try {
      final data = await ApiService.officerLogin(email, password);
      if (!mounted) return;
      await context.read<AuthProvider>().loginOfficer(
        officerId: email,
        name: data['name'] ?? '',
        role: data['role'] ?? 'STAFF',
        token: data['token'] ?? '',
        refreshToken: data['refreshToken'] ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DriverDashboard()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _officerLoading = false);
    }
  }

  Widget _inputLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text.toUpperCase(),
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 1.5),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool visible = false,
    bool upperCase = false,
    VoidCallback? onToggleVisibility,
    Widget? trailing,
  }) {
    return Column(
      children: [
        if (trailing != null)
          Align(alignment: Alignment.centerRight, child: trailing),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !visible,
            textCapitalization: upperCase ? TextCapitalization.characters : TextCapitalization.none,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[400], size: 18),
                    onPressed: onToggleVisibility,
                  )
                : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({required String label, required bool loading, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.3),
        ),
        child: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _quickAccessButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
