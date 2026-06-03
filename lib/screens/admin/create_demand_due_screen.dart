import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:gate_basic/config/app_config.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'package:gate_basic/utils/admin_dashboard_key.dart';

// ── Target type ──────────────────────────────────────────────────────────────
enum _TargetType { all, flatsOnly, housesOnly, split, specific }

extension _TargetLabel on _TargetType {
  String get label {
    switch (this) {
      case _TargetType.all:       return 'All Residents';
      case _TargetType.flatsOnly: return 'Flats Only';
      case _TargetType.housesOnly:return 'Houses Only';
      case _TargetType.split:     return 'Different Rates';
      case _TargetType.specific:  return 'Specific Members';
    }
  }

  String get subtitle {
    switch (this) {
      case _TargetType.all:       return 'Same amount for every resident';
      case _TargetType.flatsOnly: return 'Only flat owners get this due';
      case _TargetType.housesOnly:return 'Only independent house owners';
      case _TargetType.split:     return 'Set different amounts for flats & houses';
      case _TargetType.specific:  return 'Hand-pick individual residents';
    }
  }

  IconData get icon {
    switch (this) {
      case _TargetType.all:       return Icons.groups_rounded;
      case _TargetType.flatsOnly: return Icons.apartment_rounded;
      case _TargetType.housesOnly:return Icons.house_rounded;
      case _TargetType.split:     return Icons.call_split_rounded;
      case _TargetType.specific:  return Icons.person_search_rounded;
    }
  }

  String get apiValue {
    switch (this) {
      case _TargetType.all:       return 'ALL';
      case _TargetType.flatsOnly: return 'FLATS';
      case _TargetType.housesOnly:return 'HOUSES';
      case _TargetType.split:     return 'SPLIT';
      case _TargetType.specific:  return 'SPECIFIC';
    }
  }
}

class CreateDemandDueScreen extends StatefulWidget {
  const CreateDemandDueScreen({super.key});

  @override
  State<CreateDemandDueScreen> createState() => _CreateDemandDueScreenState();
}

class _CreateDemandDueScreenState extends State<CreateDemandDueScreen> {
  static final String _base = AppConfig.baseUrl;

  final _formKey        = GlobalKey<FormState>();
  final _titleCtrl      = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _amountCtrl     = TextEditingController(); // single amount
  final _flatAmtCtrl    = TextEditingController(); // for SPLIT
  final _houseAmtCtrl   = TextEditingController(); // for SPLIT

  String _category      = 'Maintenance';
  _TargetType _target   = _TargetType.all;
  DateTime _dueDate     = DateTime.now().add(const Duration(days: 15));
  bool _loading         = false;
  bool _loadingMembers  = false;

  // For SPECIFIC target
  List<Map<String, dynamic>> _allMembers = [];
  final Set<String> _selectedHouses = {};

  static const _categories = [
    'Maintenance', 'Repair', 'Renovation', 'Event', 'Utility', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _flatAmtCtrl.dispose();
    _houseAmtCtrl.dispose();
    super.dispose();
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
          'house_no':      data['house_no']?.toString() ?? '-',
          'name':          data['name']?.toString() ?? 'Unknown',
          'property_type': data['property_type']?.toString() ?? 'flat',
        };
      }).toList()
        ..sort((a, b) => a['house_no']!.compareTo(b['house_no']!));
    } catch (e) {
      debugPrint('Error fetching members: $e');
    }
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
          colorScheme:
              const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_target == _TargetType.specific && _selectedHouses.isEmpty) {
      _showSnack('Please select at least one resident.');
      return;
    }

    setState(() => _loading = true);
    try {
      final user  = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(true);

      final Map<String, dynamic> body = {
        'title':       _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category':    _category,
        'targetType':  _target.apiValue,
        'dueDateMs':   _dueDate.millisecondsSinceEpoch,
      };

      if (_target == _TargetType.split) {
        body['flatAmount']  = int.parse(_flatAmtCtrl.text.trim());
        body['houseAmount'] = int.parse(_houseAmtCtrl.text.trim());
      } else {
        body['amountPerUnit'] = int.parse(_amountCtrl.text.trim());
      }

      if (_target == _TargetType.specific) {
        body['targetHouses'] = _selectedHouses.toList();
      }

      final response = await http.post(
        Uri.parse('$_base/createDemandDueHttp'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final err = json['error'] as Map<String, dynamic>? ?? {};
        throw Exception(err['message'] ?? 'Failed to create due');
      }

      final count = json['invoicesCreated'] ?? 0;
      if (!mounted) return;
      _showSnack('✅ Due created for $count residents!', success: true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop(true);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Generate Due',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () =>
                    adminDashboardScaffoldKey.currentState?.openDrawer(),
              ),
        actions: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () =>
                  adminDashboardScaffoldKey.currentState?.openDrawer(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Due Details ──────────────────────────────────────
            _sectionLabel('Due Details'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: AppTheme.inputDecoration(
                        'Title  (e.g. Monthly Maintenance - June)',
                        Icons.title_rounded),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: AppTheme.inputDecoration(
                        'Description / Purpose',
                        Icons.description_outlined),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: AppTheme.inputDecoration(
                        'Category', Icons.category_outlined),
                    items: _categories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _category = v ?? 'Maintenance'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Due Date ─────────────────────────────────────────
            _sectionLabel('Due Date'),
            const SizedBox(height: 10),
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
                      child: const Icon(Icons.calendar_month_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Due By',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd MMMM yyyy').format(_dueDate),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textHint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Targeting ────────────────────────────────────────
            _sectionLabel('Who Should Pay?'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: _TargetType.values
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TargetOption(
                            type: t,
                            selected: _target == t,
                            onTap: () {
                              setState(() {
                                _target = t;
                                _selectedHouses.clear();
                              });
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Amount section ───────────────────────────────────
            _sectionLabel('Amount'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: _buildAmountFields(),
            ),
            const SizedBox(height: 20),

            // ── Specific member selector ─────────────────────────
            if (_target == _TargetType.specific) ...[
              _sectionLabel('Select Residents'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration,
                child: _loadingMembers
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMemberSelector(),
              ),
              const SizedBox(height: 20),
            ],

            // ── Preview summary ──────────────────────────────────
            _buildPreviewBanner(),
            const SizedBox(height: 20),

            // ── Submit ───────────────────────────────────────────
            AppTheme.gradientButton(
              label: _loading ? 'Creating...' : 'Generate Due',
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

  // ── Amount fields depending on target type ────────────────────────────────
  Widget _buildAmountFields() {
    if (_target == _TargetType.split) {
      return Column(
        children: [
          // Flat amount
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _flatAmtCtrl,
                  decoration: AppTheme.inputDecoration(
                      'Flat Amount (₹)', Icons.currency_rupee_rounded),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // House amount
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.house_rounded,
                    color: Color(0xFF059669), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _houseAmtCtrl,
                  decoration: AppTheme.inputDecoration(
                      'House Amount (₹)', Icons.currency_rupee_rounded),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Single amount field for all other target types
    final hint = _target == _TargetType.flatsOnly
        ? 'Amount per Flat (₹)'
        : _target == _TargetType.housesOnly
            ? 'Amount per House (₹)'
            : 'Amount per Unit (₹)';

    return TextFormField(
      controller: _amountCtrl,
      decoration:
          AppTheme.inputDecoration(hint, Icons.currency_rupee_rounded),
      keyboardType: TextInputType.number,
      validator: (v) {
        final n = int.tryParse(v ?? '');
        if (n == null || n <= 0) return 'Enter a valid amount';
        return null;
      },
    );
  }

  // ── Specific member selector ──────────────────────────────────────────────
  Widget _buildMemberSelector() {
    if (_allMembers.isEmpty) {
      return const Text('No residents found.',
          style: TextStyle(color: AppColors.textSecondary));
    }

    // Group by property type
    final flats =
        _allMembers.where((m) => (m['property_type'] ?? 'flat') == 'flat').toList();
    final houses =
        _allMembers.where((m) => m['property_type'] == 'house').toList();

    Widget chipGroup(String label, IconData icon, Color color,
        List<Map<String, dynamic>> members) {
      if (members.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(width: 6),
                Text('(${members.length})',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    final all = members.map((m) => m['house_no'] as String).toSet();
                    if (all.every((h) => _selectedHouses.contains(h))) {
                      _selectedHouses.removeAll(all);
                    } else {
                      _selectedHouses.addAll(all);
                    }
                  }),
                  child: Text('Select all',
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: members.map((m) {
              final house    = m['house_no'] as String;
              final name     = m['name'] as String;
              final selected = _selectedHouses.contains(house);
              return GestureDetector(
                onTap: () => setState(() => selected
                    ? _selectedHouses.remove(house)
                    : _selectedHouses.add(house)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected ? color : AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(icon,
                          size: 16,
                          color:
                              selected ? Colors.white : color),
                      const SizedBox(height: 3),
                      Text(house,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary)),
                      Text(
                        name.length > 10
                            ? '${name.substring(0, 10)}…'
                            : name,
                        style: TextStyle(
                            fontSize: 10,
                            color: selected
                                ? Colors.white70
                                : AppColors.textHint),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chipGroup('Flats', Icons.apartment_rounded, AppColors.primary, flats),
        chipGroup('Independent Houses', Icons.house_rounded,
            const Color(0xFF059669), houses),
        if (_selectedHouses.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_selectedHouses.length} resident${_selectedHouses.length != 1 ? 's' : ''} selected',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
      ],
    );
  }

  // ── Preview banner ────────────────────────────────────────────────────────
  Widget _buildPreviewBanner() {
    String targetLabel;
    switch (_target) {
      case _TargetType.all:
        targetLabel = 'All residents';
        break;
      case _TargetType.flatsOnly:
        targetLabel = 'Flat owners only';
        break;
      case _TargetType.housesOnly:
        targetLabel = 'House owners only';
        break;
      case _TargetType.split:
        final fa = _flatAmtCtrl.text.isNotEmpty ? '₹${_flatAmtCtrl.text}' : '—';
        final ha = _houseAmtCtrl.text.isNotEmpty ? '₹${_houseAmtCtrl.text}' : '—';
        targetLabel = 'Flats: $fa  ·  Houses: $ha';
        break;
      case _TargetType.specific:
        targetLabel = _selectedHouses.isEmpty
            ? 'No residents selected'
            : '${_selectedHouses.length} resident${_selectedHouses.length != 1 ? 's' : ''} selected';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Invoices will be created for: $targetLabel',
              style: const TextStyle(
                  color: AppColors.primary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary),
      );
}

// ── Target Option Widget ─────────────────────────────────────────────────────
class _TargetOption extends StatelessWidget {
  final _TargetType type;
  final bool selected;
  final VoidCallback onTap;

  const _TargetOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  Color get _accentColor {
    switch (type) {
      case _TargetType.housesOnly:
        return const Color(0xFF059669);
      case _TargetType.split:
        return const Color(0xFF7C3AED);
      case _TargetType.specific:
        return const Color(0xFFF59E0B);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = selected ? _accentColor : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _accentColor.withOpacity(0.07) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _accentColor : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected ? _accentColor : AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(type.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: selected ? _accentColor : AppColors.textPrimary)),
                  Text(type.subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: _accentColor, size: 20),
          ],
        ),
      ),
    );
  }
}
