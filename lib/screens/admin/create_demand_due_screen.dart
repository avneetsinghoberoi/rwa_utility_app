import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rms_app/config/app_config.dart';
import 'package:rms_app/theme/app_theme.dart';

class CreateDemandDueScreen extends StatefulWidget {
  const CreateDemandDueScreen({super.key});

  @override
  State<CreateDemandDueScreen> createState() => _CreateDemandDueScreenState();
}

class _CreateDemandDueScreenState extends State<CreateDemandDueScreen> {
  static final String _base = AppConfig.baseUrl;

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _category = 'Maintenance';
  String _targetType = 'ALL';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  bool _loading = false;
  bool _loadingMembers = false;

  // For SPECIFIC target
  List<Map<String, dynamic>> _allMembers = [];
  final Set<String> _selectedHouses = {};

  static const _categories = ['Maintenance', 'Repair', 'Renovation', 'Event', 'Utility', 'Other'];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .get();
      _allMembers = snap.docs.map((d) {
        final data = d.data();
        return {
          'house_no': data['house_no']?.toString() ?? '-',
          'name': data['name']?.toString() ?? 'Unknown',
        };
      }).toList()
        ..sort((a, b) => a['house_no']!.compareTo(b['house_no']!));
    } catch (_) {}
    if (mounted) setState(() => _loadingMembers = false);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetType == 'SPECIFIC' && _selectedHouses.isEmpty) {
      _showSnack('Select at least one house for specific targeting.');
      return;
    }

    setState(() => _loading = true);
    try {
      final user  = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(true);

      final response = await http.post(
        Uri.parse('$_base/createDemandDueHttp'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title':         _titleCtrl.text.trim(),
          'description':   _descCtrl.text.trim(),
          'category':      _category,
          'amountPerUnit': int.parse(_amountCtrl.text.trim()),
          'targetType':    _targetType,
          'targetHouses':  _targetType == 'SPECIFIC' ? _selectedHouses.toList() : [],
          'dueDateMs':     _dueDate.millisecondsSinceEpoch,
        }),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final err = json['error'] as Map<String, dynamic>? ?? {};
        throw Exception(err['message'] ?? 'Failed to create demand due');
      }

      final count = json['invoicesCreated'] ?? 0;
      if (!mounted) return;
      _showSnack('✅ Demand due created for $count residents!', success: true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop(true); // signal refresh
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Demand Due', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Info banner ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'This will create individual invoices for all targeted residents instantly.',
                      style: TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Section: Due Details ─────────────────────────────────
            _sectionLabel('Due Details'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: AppTheme.inputDecoration('Title (e.g. Society Painting Q2 2026)', Icons.title_rounded),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: AppTheme.inputDecoration('Description / Purpose', Icons.description_outlined),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),

                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: AppTheme.inputDecoration('Category', Icons.category_outlined),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v ?? 'Maintenance'),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _amountCtrl,
                    decoration: AppTheme.inputDecoration('Amount per Flat (₹)', Icons.currency_rupee_rounded),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Section: Due Date ────────────────────────────────────
            _sectionLabel('Due Date'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDueDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Due By', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd MMMM yyyy').format(_dueDate),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Section: Target ──────────────────────────────────────
            _sectionLabel('Target Residents'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _targetOption('ALL', 'All Residents', 'Charge every flat in the society', Icons.groups_rounded),
                  const SizedBox(height: 8),
                  _targetOption('SPECIFIC', 'Specific Flats', 'Choose which flats to charge', Icons.home_rounded),

                  if (_targetType == 'SPECIFIC') ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 14),
                    const Text('Select flats to charge:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    _loadingMembers
                        ? const Center(child: CircularProgressIndicator())
                        : _buildHouseSelector(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Submit ───────────────────────────────────────────────
            AppTheme.gradientButton(
              label: _loading ? 'Creating...' : 'Create Demand Due',
              onTap: _loading ? null : _submit,
              height: 54,
              icon: Icons.add_task_rounded,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
    );
  }

  Widget _targetOption(String value, String title, String subtitle, IconData icon) {
    final selected = _targetType == value;
    return GestureDetector(
      onTap: () => setState(() => _targetType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selected ? AppColors.primary : AppColors.textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseSelector() {
    if (_allMembers.isEmpty) {
      return const Text('No residents found.', style: TextStyle(color: AppColors.textSecondary));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allMembers.map((m) {
        final house = m['house_no']!;
        final selected = _selectedHouses.contains(house);
        return FilterChip(
          label: Text('$house\n${m['name']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
          selected: selected,
          onSelected: (v) => setState(() => v ? _selectedHouses.add(house) : _selectedHouses.remove(house)),
          selectedColor: AppColors.primaryLight,
          checkmarkColor: AppColors.primary,
          backgroundColor: Colors.white,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
          labelStyle: TextStyle(color: selected ? AppColors.primary : AppColors.textSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
        );
      }).toList(),
    );
  }
}
