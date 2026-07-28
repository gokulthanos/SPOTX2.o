import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/bus.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _officers = [];
  List<Map<String, dynamic>> _stops = [];
  List<Map<String, dynamic>> _cities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.fetchBuses(),
        ApiService.fetchRoutes(),
        ApiService.fetchOfficers(),
        ApiService.fetchStops(),
        ApiService.fetchCities(),
      ]);
      if (mounted) {
        setState(() {
          _buses = (results[0] as List<Bus>).map((b) => b.toJson()).toList();
          _routes = (results[1] as List).cast<Map<String, dynamic>>();
          _officers = (results[2] as List).cast<Map<String, dynamic>>();
          _stops = (results[3] as List).cast<Map<String, dynamic>>();
          _cities = (results[4] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAll),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
          tabs: const [
            Tab(text: 'BUSES'),
            Tab(text: 'ROUTES'),
            Tab(text: 'OFFICERS'),
            Tab(text: 'STOPS'),
            Tab(text: 'CITIES'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('ADD NEW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBusTab(),
                _buildRouteTab(),
                _buildOfficerTab(),
                _buildStopTab(),
                _buildCityTab(),
              ],
            ),
    );
  }

  void _showAddDialog() {
    final tab = _tabController.index;
    switch (tab) {
      case 0:
        _showAddBusDialog();
        break;
      case 1:
        _showAddRouteDialog();
        break;
      case 2:
        _showAddOfficerDialog();
        break;
      case 3:
        _showAddStopDialog();
        break;
      case 4:
        _showAddCityDialog();
        break;
    }
  }

  Widget _buildBusTab() {
    if (_buses.isEmpty) return _emptyState('No buses registered');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _buses.length,
      itemBuilder: (context, i) {
        final bus = _buses[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.directions_bus_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${bus['busNumber'] ?? bus['bus_number'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    Text('${bus['busType'] ?? bus['bus_type'] ?? ''} • ${bus['city'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                onPressed: () async {
                  final id = bus['id'];
                  if (id != null) {
                    try {
                      await ApiService.deleteBus(id);
                      _loadAll();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.error));
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteTab() {
    if (_routes.isEmpty) return _emptyState('No routes defined');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _routes.length,
      itemBuilder: (context, i) {
        final r = _routes[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.route_rounded, color: AppTheme.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['route_number'] ?? ''} - ${r['name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text('${r['distance_km'] ?? 0}km • ₹${r['base_fare'] ?? 0}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfficerTab() {
    if (_officers.isEmpty) return _emptyState('No officers registered');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _officers.length,
      itemBuilder: (context, i) {
        final o = _officers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: (o['role'] == 'ADMIN' ? AppTheme.primaryBlue : AppTheme.success).withValues(alpha: 0.1),
                child: Text((o['name'] ?? '?')[0].toString().toUpperCase(),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: o['role'] == 'ADMIN' ? AppTheme.primaryBlue : AppTheme.success)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(o['email'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (o['role'] == 'ADMIN' ? AppTheme.primaryBlue : AppTheme.success).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(o['role'] ?? '', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: o['role'] == 'ADMIN' ? AppTheme.primaryBlue : AppTheme.success)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStopTab() {
    if (_stops.isEmpty) return _emptyState('No stops added');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stops.length,
      itemBuilder: (context, i) {
        final s = _stops[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              Text(s['city_name'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCityTab() {
    if (_cities.isEmpty) return _emptyState('No cities added');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cities.length,
      itemBuilder: (context, i) {
        final c = _cities[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.location_city_rounded, color: AppTheme.primaryBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(c['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
              Text(c['state'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[200]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showAddBusDialog() {
    final busNumCtrl = TextEditingController();
    String busType = 'Normal';
    String city = 'Chennai';
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add New Bus', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: busNumCtrl, decoration: const InputDecoration(hintText: 'Bus Number (e.g. TN01N1234)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: 'Normal',
              items: ['Normal', 'Deluxe', 'Express', 'Mofussil', 'Town', 'Mini']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => busType = v ?? 'Normal',
              decoration: const InputDecoration(hintText: 'Bus Type'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _cities.isNotEmpty ? _cities.first['name']?.toString() ?? 'Chennai' : 'Chennai',
              items: _cities.map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c['name'].toString(), child: Text(c['name'].toString()))).toList(),
              onChanged: (v) => city = v ?? 'Chennai',
              decoration: const InputDecoration(hintText: 'City'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: () async {
            if (busNumCtrl.text.isNotEmpty) {
              try {
                await ApiService.addBus(busNumber: busNumCtrl.text, busType: busType, city: city);
                Navigator.pop(context);
                _loadAll();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
              }
            }
          },
          child: const Text('ADD'),
        ),
      ],
    ));
  }

  void _showAddRouteDialog() {
    final numCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final fareCtrl = TextEditingController();
    final distCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add New Route', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: numCtrl, decoration: const InputDecoration(hintText: 'Route Number')),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Route Name')),
            const SizedBox(height: 12),
            TextField(controller: distCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Distance (km)')),
            const SizedBox(height: 12),
            TextField(controller: fareCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Base Fare (₹)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: () async {
            if (numCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
              try {
                await ApiService.addRoute(
                  routeNumber: numCtrl.text,
                  name: nameCtrl.text,
                  distanceKm: double.tryParse(distCtrl.text) ?? 0,
                  baseFare: double.tryParse(fareCtrl.text) ?? 0,
                );
                Navigator.pop(context);
                _loadAll();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
              }
            }
          },
          child: const Text('ADD'),
        ),
      ],
    ));
  }

  void _showAddOfficerDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'STAFF';
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Register Officer', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Full Name')),
            const SizedBox(height: 12),
            TextField(controller: emailCtrl, decoration: const InputDecoration(hintText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Password')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: 'STAFF',
              items: const [
                DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
              ],
              onChanged: (v) => role = v ?? 'STAFF',
              decoration: const InputDecoration(hintText: 'Role'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
              try {
                await ApiService.registerStaff(name: nameCtrl.text, email: emailCtrl.text, password: passCtrl.text, role: role);
                Navigator.pop(context);
                _loadAll();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
              }
            }
          },
          child: const Text('REGISTER'),
        ),
      ],
    ));
  }

  void _showAddStopDialog() {
    final nameCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add New Stop', style: TextStyle(fontWeight: FontWeight.w900)),
      content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Stop Name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.isNotEmpty) {
              try {
                await ApiService.addStop(name: nameCtrl.text);
                Navigator.pop(context);
                _loadAll();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
              }
            }
          },
          child: const Text('ADD'),
        ),
      ],
    ));
  }

  void _showAddCityDialog() {
    final nameCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add New City', style: TextStyle(fontWeight: FontWeight.w900)),
      content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'City Name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.isNotEmpty) {
              try {
                await ApiService.addCity(name: nameCtrl.text);
                Navigator.pop(context);
                _loadAll();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
              }
            }
          },
          child: const Text('ADD'),
        ),
      ],
    ));
  }
}
