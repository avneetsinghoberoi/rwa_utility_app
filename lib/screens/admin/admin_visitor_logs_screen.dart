import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'package:gate_basic/utils/admin_dashboard_key.dart';

// ── Date preset options ──────────────────────────────────────────────────────
enum _DatePreset { today, yesterday, week, month, custom, all }

extension _DatePresetLabel on _DatePreset {
  String get label {
    switch (this) {
      case _DatePreset.today:     return 'Today';
      case _DatePreset.yesterday: return 'Yesterday';
      case _DatePreset.week:      return 'This Week';
      case _DatePreset.month:     return 'This Month';
      case _DatePreset.custom:    return 'Custom';
      case _DatePreset.all:       return 'All Time';
    }
  }
}

class AdminVisitorLogsScreen extends StatefulWidget {
  const AdminVisitorLogsScreen({super.key});

  @override
  State<AdminVisitorLogsScreen> createState() =>
      _AdminVisitorLogsScreenState();
}

class _AdminVisitorLogsScreenState extends State<AdminVisitorLogsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Filters
  _DatePreset _datePreset = _DatePreset.all;
  DateTime? _customDate; // only used when preset == custom
  String _typeFilter = 'all'; // 'all' | 'qr_scan' | 'manual'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Date range from preset ──────────────────────────────────────
  ({DateTime? start, DateTime? end}) get _dateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_datePreset) {
      case _DatePreset.today:
        return (start: today, end: today.add(const Duration(days: 1)));
      case _DatePreset.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return (start: y, end: today);
      case _DatePreset.week:
        return (
          start: today.subtract(Duration(days: today.weekday - 1)),
          end: today.add(const Duration(days: 1))
        );
      case _DatePreset.month:
        return (start: DateTime(now.year, now.month, 1), end: today.add(const Duration(days: 1)));
      case _DatePreset.custom:
        if (_customDate == null) return (start: null, end: null);
        final d = DateTime(_customDate!.year, _customDate!.month, _customDate!.day);
        return (start: d, end: d.add(const Duration(days: 1)));
      case _DatePreset.all:
        return (start: null, end: null);
    }
  }

  // ── Firestore query ─────────────────────────────────────────────
  Query<Map<String, dynamic>> get _query {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('visitor_logs')
        .orderBy('entry_time', descending: true);

    final range = _dateRange;
    if (range.start != null) {
      q = q.where('entry_time',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start!));
    }
    if (range.end != null) {
      q = q.where('entry_time',
          isLessThan: Timestamp.fromDate(range.end!));
    }
    if (_typeFilter != 'all') {
      q = q.where('entry_type', isEqualTo: _typeFilter);
    }
    return q;
  }

  // ── Client-side search ──────────────────────────────────────────
  List<QueryDocumentSnapshot> _applySearch(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    final q = _searchQuery.toLowerCase();
    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return (d['visitor_name']?.toString() ?? '').toLowerCase().contains(q) ||
          (d['apartment']?.toString() ?? '').toLowerCase().contains(q) ||
          (d['vehicle_no']?.toString() ?? '').toLowerCase().contains(q);
    }).toList();
  }

  // ── Group docs by date ──────────────────────────────────────────
  Map<String, List<QueryDocumentSnapshot>> _groupByDate(
      List<QueryDocumentSnapshot> docs) {
    final groups = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final ts = d['entry_time'];
      final date = ts is Timestamp ? ts.toDate() : DateTime.now();
      final key = _dateGroupKey(date);
      groups.putIfAbsent(key, () => []).add(doc);
    }
    return groups;
  }

  String _dateGroupKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _customDate = picked;
        _datePreset = _DatePreset.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
        title: const Text(
          'Visitor Logs',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search by name, apartment, vehicle…',
                hintStyle:
                    const TextStyle(color: AppColors.textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textHint),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),

          // ── Date preset chips ──────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final preset in _DatePreset.values)
                    if (preset != _DatePreset.custom)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: preset.label,
                          selected: _datePreset == preset,
                          onTap: () => setState(() => _datePreset = preset),
                        ),
                      ),
                  // Custom date chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: _datePreset == _DatePreset.custom &&
                              _customDate != null
                          ? DateFormat('dd MMM').format(_customDate!)
                          : 'Pick Date',
                      selected: _datePreset == _DatePreset.custom,
                      icon: Icons.calendar_today_rounded,
                      onTap: _pickCustomDate,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Type filter chips ──────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                const Text('Type:',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'All',
                  selected: _typeFilter == 'all',
                  onTap: () => setState(() => _typeFilter = 'all'),
                  small: true,
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'QR Scan',
                  selected: _typeFilter == 'qr_scan',
                  onTap: () => setState(() => _typeFilter = 'qr_scan'),
                  small: true,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Manual',
                  selected: _typeFilter == 'manual',
                  onTap: () => setState(() => _typeFilter = 'manual'),
                  small: true,
                  color: AppColors.success,
                ),
              ],
            ),
          ),

          Container(height: 1, color: AppColors.border),

          // ── Log list ───────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _query.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snap.data?.docs ?? [];
                final filtered = _applySearch(allDocs);

                if (allDocs.isEmpty) {
                  return _EmptyState(
                    icon: Icons.no_accounts_outlined,
                    message: 'No visitor logs found\nfor this filter.',
                  );
                }
                if (filtered.isEmpty) {
                  return _EmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'No results for "$_searchQuery"',
                  );
                }

                final groups = _groupByDate(filtered);
                final groupKeys = groups.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: groupKeys.length + 1,
                  itemBuilder: (_, i) {
                    // Summary card
                    if (i == 0) {
                      return _StatsRow(docs: filtered);
                    }
                    final key = groupKeys[i - 1];
                    final dayDocs = groups[key]!;
                    return _DateGroup(label: key, docs: dayDocs);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ──────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool small;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.small = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
            horizontal: small ? 12 : 14, vertical: small ? 6 : 8),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppColors.gray50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? activeColor : AppColors.border, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: small ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;

  const _StatsRow({required this.docs});

  @override
  Widget build(BuildContext context) {
    final qrCount =
        docs.where((d) => (d['entry_type'] ?? '') == 'qr_scan').length;
    final manualCount = docs.length - qrCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _statItem(Icons.people_alt_rounded, '${docs.length}', 'Total'),
          _divider(),
          _statItem(Icons.qr_code_scanner_rounded, '$qrCount', 'QR Scan'),
          _divider(),
          _statItem(Icons.edit_note_rounded, '$manualCount', 'Manual'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 36, color: Colors.white.withOpacity(0.25));
}

// ── Date Group ───────────────────────────────────────────────────────────────
class _DateGroup extends StatelessWidget {
  final String label;
  final List<QueryDocumentSnapshot> docs;

  const _DateGroup({required this.label, required this.docs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${docs.length} entr${docs.length == 1 ? 'y' : 'ies'}',
                style: const TextStyle(
                    color: AppColors.textHint, fontSize: 12),
              ),
            ],
          ),
        ),
        // Cards for this date
        ...docs.map((doc) =>
            _VisitorLogCard(data: doc.data() as Map<String, dynamic>)),
        const SizedBox(height: 6),
      ],
    );
  }
}

// ── Visitor Log Card ─────────────────────────────────────────────────────────
class _VisitorLogCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _VisitorLogCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['visitor_name']?.toString() ?? '-';
    final apartment = data['apartment']?.toString() ?? '-';
    final vehicle = data['vehicle_no']?.toString() ?? '';
    final phone = data['phone']?.toString() ?? '';
    final type = data['entry_type']?.toString() ?? 'manual';
    final ts = data['entry_time'];
    final dateTime = ts is Timestamp ? ts.toDate() : null;
    final isQr = type == 'qr_scan';
    final color = isQr ? AppColors.primary : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isQr
                    ? Icons.qr_code_scanner_rounded
                    : Icons.edit_note_rounded,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badge row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isQr ? 'QR Scan' : 'Manual',
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Apartment
                  _infoRow(Icons.home_outlined, apartment),

                  // Vehicle
                  if (vehicle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    _infoRow(Icons.directions_car_outlined, vehicle),
                  ],

                  // Phone (from QR)
                  if (phone.isNotEmpty && phone != '-') ...[
                    const SizedBox(height: 3),
                    _infoRow(Icons.phone_outlined, phone),
                  ],

                  // Time
                  if (dateTime != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('hh:mm a').format(dateTime),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 12, color: AppColors.textHint),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      );
}

// ── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
