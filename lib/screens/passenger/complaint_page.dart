import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class ComplaintPage extends StatefulWidget {
  const ComplaintPage({super.key});

  @override
  State<ComplaintPage> createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  List<Map<String, dynamic>> _complaints = [];
  bool _loading = true;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() => _loading = true);
    try {
      _complaints = await ApiService.fetchComplaints();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_subjectController.text.isEmpty || _descriptionController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Subject required and description must be 10+ chars'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.submitComplaint(
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      _subjectController.clear();
      _descriptionController.clear();
      setState(() => _showForm = false);
      await _fetchComplaints();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complaint submitted successfully'),
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Complaints'),
        actions: [
          IconButton(
            icon: Icon(_showForm ? Icons.list_rounded : Icons.add_rounded),
            onPressed: () => setState(() => _showForm = !_showForm),
          ),
        ],
      ),
      body: _showForm ? _buildForm() : _buildList(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTheme.sectionLabel('SUBMIT COMPLAINT'),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(hintText: 'Subject'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'Describe your issue in detail...'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SUBMIT COMPLAINT'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));

    if (_complaints.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.feedback_outlined, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 12),
            Text('No complaints yet', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _complaints.length,
      itemBuilder: (context, i) {
        final c = _complaints[i];
        final statusColor = c['status'] == 'resolved' ? AppTheme.success : (c['status'] == 'open' ? AppTheme.warning : AppTheme.primaryBlue);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(c['subject'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text((c['status'] ?? 'open').toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(c['description'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Text(c['created_at'] ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        );
      },
    );
  }
}
