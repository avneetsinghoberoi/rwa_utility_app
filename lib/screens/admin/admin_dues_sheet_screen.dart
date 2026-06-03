import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'package:gate_basic/utils/admin_dashboard_key.dart';

// ════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ════════════════════════════════════════════════════════════════════════════

class _DueGroup {
  final String id;
  final String title;
  final String type; // 'DEMAND' | 'MAINTENANCE'
  final DateTime sortDate;

  int totalBilled    = 0;
  int totalCollected = 0;
  int paidCount      = 0;
  int partialCount   = 0;
  int unpaidCount    = 0;

  int    get totalOutstanding => totalBilled - totalCollected;
  int    get invoiceCount     => paidCount + partialCount + unpaidCount;
  double get collectionRate   => totalBilled > 0 ? totalCollected / totalBilled : 0;

  _DueGroup({required this.id, required this.title, required this.type, required this.sortDate});
}

class _InvoiceSummary {
  final String invoiceId;
  final String status;
  final int    amount;
  final int    paidAmount;

  int  get balance   => (amount - paidAmount).clamp(0, amount);
  bool get isPaid    => status == 'PAID';
  bool get isPartial => status == 'PARTIAL';
  bool get isUnpaid  => status == 'UNPAID' || status == 'SUBMITTED';

  const _InvoiceSummary({required this.invoiceId, required this.status, required this.amount, required this.paidAmount});
}

class _MemberRow {
  final String uid;
  final String houseNo;
  final String name;
  final String propertyType;
  final Map<String, _InvoiceSummary> byGroup;

  _MemberRow({required this.uid, required this.houseNo, required this.name, required this.propertyType, required this.byGroup});

  int  get totalBilled  => byGroup.values.fold(0, (s, i) => s + i.amount);
  int  get totalPaid    => byGroup.values.fold(0, (s, i) => s + i.paidAmount);
  int  get totalBalance => (totalBilled - totalPaid).clamp(0, totalBilled);
  bool get isFullyClear => byGroup.values.every((i) => i.isPaid);
  bool get hasAnyUnpaid => byGroup.values.any((i) => i.isUnpaid);

  String get overallStatus {
    if (isFullyClear) return 'CLEAR';
    if (hasAnyUnpaid) return 'DEFAULTER';
    return 'PARTIAL';
  }
}

class _SheetData {
  final List<_DueGroup>  groups;
  final List<_MemberRow> members;

  const _SheetData({required this.groups, required this.members});

  int get totalBilled    => members.fold(0, (s, m) => s + m.totalBilled);
  int get totalCollected => members.fold(0, (s, m) => s + m.totalPaid);
  int get totalBalance   => (totalBilled - totalCollected).clamp(0, totalBilled);
  int get clearCount     => members.where((m) => m.isFullyClear).length;
  int get defaulterCount => members.where((m) => m.hasAnyUnpaid).length;
  int get partialCount   => members.where((m) => !m.isFullyClear && !m.hasAnyUnpaid).length;

  List<_MemberRow> get defaulters => members.where((m) => m.hasAnyUnpaid).toList();
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ════════════════════════════════════════════════════════════════════════════

class AdminDuesSheetScreen extends StatefulWidget {
  const AdminDuesSheetScreen({super.key});

  @override
  State<AdminDuesSheetScreen> createState() => _AdminDuesSheetScreenState();
}

class _AdminDuesSheetScreenState extends State<AdminDuesSheetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<_SheetData> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _future = _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_SheetData> _loadData() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('users').where('role', isEqualTo: 'user').get(),
      db.collection('invoices').get(),
      db.collection('demand_dues').get(),
    ]);

    final userDocs    = results[0].docs;
    final invoiceDocs = results[1].docs;
    final demandDocs  = results[2].docs;

    final demandMeta = <String, Map<String, dynamic>>{
      for (final d in demandDocs) d.id: d.data(),
    };

    final groupMap  = <String, _DueGroup>{};
    final memberMap = <String, _MemberRow>{};

    for (final u in userDocs) {
      final d = u.data();
      memberMap[u.id] = _MemberRow(
        uid:          u.id,
        houseNo:      d['house_no']?.toString()      ?? '-',
        name:         d['name']?.toString()          ?? 'Unknown',
        propertyType: d['property_type']?.toString() ?? 'flat',
        byGroup:      {},
      );
    }

    for (final inv in invoiceDocs) {
      final d      = inv.data();
      final uid    = d['uid']?.toString()       ?? '';
      final type   = d['type']?.toString()      ?? 'MAINTENANCE';
      final status = d['status']?.toString()    ?? 'UNPAID';
      final amount = (d['amount']    as num?)?.toInt() ?? 0;
      final paid   = (d['paid_amount'] as num?)?.toInt() ?? 0;
      final month  = d['month']?.toString()     ?? '';
      final demId  = d['demand_id']?.toString() ?? '';

      final String groupId;
      final String groupTitle;
      final String groupType;
      final DateTime groupDate;

      if (type == 'DEMAND' && demId.isNotEmpty) {
        groupId    = demId;
        final meta = demandMeta[demId] ?? {};
        groupTitle = meta['title']?.toString() ?? d['title']?.toString() ?? 'Special Due';
        groupType  = 'DEMAND';
        groupDate  = meta['created_at'] is Timestamp
            ? (meta['created_at'] as Timestamp).toDate()
            : DateTime.now();
      } else if (month.isNotEmpty) {
        groupId    = month;
        groupTitle = _monthLabel(month);
        groupType  = 'MAINTENANCE';
        groupDate  = _monthDate(month);
      } else {
        continue;
      }

      groupMap.putIfAbsent(groupId,
          () => _DueGroup(id: groupId, title: groupTitle, type: groupType, sortDate: groupDate));

      final group = groupMap[groupId]!;
      group.totalBilled    += amount;
      group.totalCollected += paid;
      if (status == 'PAID')         group.paidCount++;
      else if (status == 'PARTIAL') group.partialCount++;
      else                          group.unpaidCount++;

      if (memberMap.containsKey(uid)) {
        memberMap[uid]!.byGroup[groupId] = _InvoiceSummary(
            invoiceId: inv.id, status: status, amount: amount, paidAmount: paid);
      }
    }

    final groups  = groupMap.values.toList()..sort((a, b) => b.sortDate.compareTo(a.sortDate));
    final members = memberMap.values.toList()..sort((a, b) => a.houseNo.compareTo(b.houseNo));
    return _SheetData(groups: groups, members: members);
  }

  static String _monthLabel(String month) {
    try { return DateFormat('MMM yyyy').format(DateTime.parse('$month-01')); }
    catch (_) { return month; }
  }

  static DateTime _monthDate(String month) {
    try { return DateTime.parse('$month-01'); }
    catch (_) { return DateTime.fromMillisecondsSinceEpoch(0); }
  }

  // ── CSV export helpers ───────────────────────────────────────────────────
  Future<void> _writeCsv(String filename, List<List<String>> rows) async {
    final csv = rows
        .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
        .join('\n');
    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv);
    await OpenFilex.open(file.path);
  }

  Future<void> _exportLedger(_SheetData data) async {
    await _writeCsv('member_ledger.csv', [
      ['Flat No', 'Name', 'Property Type', 'Total Billed', 'Total Paid', 'Outstanding', 'Status'],
      ...data.members.map((m) => [
        m.houseNo, m.name,
        m.propertyType == 'house' ? 'Indep. House' : 'Flat',
        m.totalBilled.toString(), m.totalPaid.toString(),
        m.totalBalance.toString(), m.overallStatus,
      ]),
    ]);
  }

  Future<void> _exportDue(_SheetData data, _DueGroup g) async {
    final rows = data.members.where((m) => m.byGroup.containsKey(g.id)).map((m) {
      final inv = m.byGroup[g.id]!;
      return [m.houseNo, m.name, m.propertyType == 'house' ? 'Indep. House' : 'Flat',
        inv.amount.toString(), inv.paidAmount.toString(), inv.balance.toString(), inv.status];
    });
    await _writeCsv('due_${g.id}.csv', [
      ['Flat No', 'Name', 'Property Type', 'Amount', 'Paid', 'Balance', 'Status'],
      ...rows,
    ]);
  }

  Future<void> _exportDefaulters(_SheetData data, String? gid) async {
    final list = gid == null
        ? data.defaulters
        : data.members.where((m) { final i = m.byGroup[gid]; return i != null && i.isUnpaid; }).toList();
    await _writeCsv('defaulters.csv', [
      ['Flat No', 'Name', 'Property Type', 'Outstanding', 'Status'],
      ...list.map((m) => [m.houseNo, m.name, m.propertyType == 'house' ? 'Indep. House' : 'Flat',
        m.totalBalance.toString(), m.overallStatus]),
    ]);
  }

  void _refresh() => setState(() => _future = _loadData());

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
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context))
            : IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => adminDashboardScaffoldKey.currentState?.openDrawer()),
        actions: [
          if (Navigator.canPop(context))
            IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => adminDashboardScaffoldKey.currentState?.openDrawer()),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: _refresh),
        ],
        title: const Text('Dues Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Ledger'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Per Due'),
            Tab(icon: Icon(Icons.person_off_outlined, size: 18), text: 'Defaulters'),
          ],
        ),
      ),
      body: FutureBuilder<_SheetData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(snap.error.toString(), textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ]),
            ));
          }
          final data = snap.data!;
          if (data.groups.isEmpty) {
            return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_outlined, size: 52, color: AppColors.textHint),
              SizedBox(height: 12),
              Text('No dues generated yet.', style: TextStyle(color: AppColors.textSecondary)),
            ]));
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(data: data),
              _LedgerTab(data: data, onExport: () => _exportLedger(data)),
              _PerDueTab(data: data, onExport: (g) => _exportDue(data, g)),
              _DefaultersTab(data: data, onExport: (gid) => _exportDefaulters(data, gid)),
            ],
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW
// ════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final _SheetData data;
  const _OverviewTab({required this.data});

  String _fmt(int v) => '₹${NumberFormat('#,##0').format(v)}';

  @override
  Widget build(BuildContext context) {
    final rate = data.totalBilled > 0 ? data.totalCollected / data.totalBilled : 0.0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Financial Summary'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
          children: [
            _StatCard('Total Billed',    _fmt(data.totalBilled),    Icons.receipt_long_rounded,   AppColors.primary),
            _StatCard('Collected',       _fmt(data.totalCollected), Icons.check_circle_rounded,   AppColors.success),
            _StatCard('Outstanding',     _fmt(data.totalBalance),   Icons.pending_actions_rounded, AppColors.error),
            _StatCard('Collection Rate', '${(rate * 100).toStringAsFixed(1)}%', Icons.trending_up_rounded, AppColors.warning),
          ],
        ),
        const SizedBox(height: 16),
        _SectionLabel('Member Status'),
        const SizedBox(height: 10),
        Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              _MemberStat('Total',     data.members.length,   AppColors.primary,  Icons.people_alt_rounded),
              _MemberStat('Clear',     data.clearCount,       AppColors.success,  Icons.check_circle_rounded),
              _MemberStat('Partial',   data.partialCount,     AppColors.warning,  Icons.pending_rounded),
              _MemberStat('Defaulters',data.defaulterCount,   AppColors.error,    Icons.person_off_rounded),
            ]),
            const SizedBox(height: 14),
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: rate, minHeight: 10,
                backgroundColor: AppColors.error.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation(AppColors.success))),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(rate * 100).toStringAsFixed(1)}% collected',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
              Text('${data.defaulterCount} defaulter${data.defaulterCount != 1 ? 's' : ''}',
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        _SectionLabel('All Dues — Summary'),
        const SizedBox(height: 10),
        ...data.groups.map((g) => _DueSummaryCard(group: g)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 2 — MEMBER LEDGER
// ════════════════════════════════════════════════════════════════════════════

class _LedgerTab extends StatefulWidget {
  final _SheetData data;
  final Future<void> Function() onExport;
  const _LedgerTab({required this.data, required this.onExport});

  @override
  State<_LedgerTab> createState() => _LedgerTabState();
}

class _LedgerTabState extends State<_LedgerTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _type   = 'all';
  String _status = 'all';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<_MemberRow> get _filtered => widget.data.members.where((m) {
    if (_type   != 'all' && m.propertyType  != _type)   return false;
    if (_status != 'all' && m.overallStatus != _status)  return false;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      if (!m.houseNo.toLowerCase().contains(q) && !m.name.toLowerCase().contains(q)) return false;
    }
    return true;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final outstanding = list.fold<int>(0, (s, m) => s + m.totalBalance);
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(children: [
          Row(children: [
            Expanded(child: _SearchField(ctrl: _searchCtrl, hint: 'Search flat or name…',
                onChanged: (v) => setState(() => _search = v))),
            const SizedBox(width: 8),
            _ExportBtn(onTap: widget.onExport),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _Chip('All',      _type == 'all',  () => setState(() => _type = 'all')),
            const SizedBox(width: 6),
            _Chip('Flats',    _type == 'flat', () => setState(() => _type = 'flat'),  color: AppColors.primary),
            const SizedBox(width: 6),
            _Chip('Houses',   _type == 'house',() => setState(() => _type = 'house'), color: AppColors.success),
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: AppColors.border),
            const SizedBox(width: 12),
            _Chip('Clear',    _status == 'CLEAR',    () => setState(() => _status = _status == 'CLEAR'    ? 'all' : 'CLEAR'),    color: AppColors.success),
            const SizedBox(width: 6),
            _Chip('Partial',  _status == 'PARTIAL',  () => setState(() => _status = _status == 'PARTIAL'  ? 'all' : 'PARTIAL'),  color: AppColors.warning),
            const SizedBox(width: 6),
            _Chip('Defaulter',_status == 'DEFAULTER',() => setState(() => _status = _status == 'DEFAULTER'? 'all' : 'DEFAULTER'), color: AppColors.error),
          ])),
        ]),
      ),
      Container(height: 1, color: AppColors.border),
      _SummaryStrip(
        icon: Icons.people_alt_rounded,
        left: '${list.length} members',
        right: 'Outstanding: ₹${NumberFormat('#,##0').format(outstanding)}',
        color: AppColors.primaryDark,
      ),
      Expanded(
        child: list.isEmpty
            ? const Center(child: Text('No members match the filter.',
                style: TextStyle(color: AppColors.textSecondary)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _LedgerCard(member: list[i])),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 3 — PER DUE SHEET
// ════════════════════════════════════════════════════════════════════════════

class _PerDueTab extends StatefulWidget {
  final _SheetData data;
  final Future<void> Function(_DueGroup) onExport;
  const _PerDueTab({required this.data, required this.onExport});

  @override
  State<_PerDueTab> createState() => _PerDueTabState();
}

class _PerDueTabState extends State<_PerDueTab> {
  late _DueGroup _sel;
  String _status = 'all';

  @override
  void initState() { super.initState(); _sel = widget.data.groups.first; }

  List<_MemberRow> get _members => widget.data.members
      .where((m) => m.byGroup.containsKey(_sel.id))
      .where((m) {
        if (_status == 'all')     return true;
        final inv = m.byGroup[_sel.id]!;
        if (_status == 'PAID')    return inv.isPaid;
        if (_status == 'PARTIAL') return inv.isPartial;
        if (_status == 'UNPAID')  return inv.isUnpaid;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final list    = _members;
    final coll    = list.fold<int>(0, (s, m) => s + (m.byGroup[_sel.id]?.paidAmount ?? 0));
    final balance = list.fold<int>(0, (s, m) => s + (m.byGroup[_sel.id]?.balance ?? 0));

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(children: [
          DropdownButtonFormField<_DueGroup>(
            value: _sel,
            decoration: InputDecoration(
              labelText: 'Select Due',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true, fillColor: AppColors.gray50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            ),
            items: widget.data.groups.map((g) => DropdownMenuItem(
              value: g,
              child: Text('${g.type == 'DEMAND' ? '⚡ ' : '🏠 '}${g.title}',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (g) { if (g != null) setState(() => _sel = g); },
          ),
          const SizedBox(height: 8),
          Row(children: [
            _Chip('All',     _status == 'all',     () => setState(() => _status = 'all')),
            const SizedBox(width: 6),
            _Chip('Paid',    _status == 'PAID',    () => setState(() => _status = 'PAID'),    color: AppColors.success),
            const SizedBox(width: 6),
            _Chip('Partial', _status == 'PARTIAL', () => setState(() => _status = 'PARTIAL'), color: AppColors.warning),
            const SizedBox(width: 6),
            _Chip('Unpaid',  _status == 'UNPAID',  () => setState(() => _status = 'UNPAID'),  color: AppColors.error),
            const Spacer(),
            _ExportBtn(onTap: () => widget.onExport(_sel)),
          ]),
        ]),
      ),
      Container(height: 1, color: AppColors.border),
      Container(
        color: AppColors.primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          _StripStat('Total',   '${_sel.invoiceCount}', Colors.white),
          _StripStat('Paid',    '${_sel.paidCount}',    const Color(0xFF6EE7B7)),
          _StripStat('Partial', '${_sel.partialCount}', const Color(0xFFFCD34D)),
          _StripStat('Unpaid',  '${_sel.unpaidCount}',  const Color(0xFFFCA5A5)),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Collected: ₹${NumberFormat('#,##0').format(coll)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text('Pending: ₹${NumberFormat('#,##0').format(balance)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? const Center(child: Text('No members for this filter.',
                style: TextStyle(color: AppColors.textSecondary)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _DueInvoiceCard(member: list[i], invoice: list[i].byGroup[_sel.id]!)),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TAB 4 — DEFAULTERS
// ════════════════════════════════════════════════════════════════════════════

class _DefaultersTab extends StatefulWidget {
  final _SheetData data;
  final Future<void> Function(String?) onExport;
  const _DefaultersTab({required this.data, required this.onExport});

  @override
  State<_DefaultersTab> createState() => _DefaultersTabState();
}

class _DefaultersTabState extends State<_DefaultersTab> {
  _DueGroup? _filter;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<_MemberRow> get _defaulters {
    var list = _filter == null
        ? widget.data.defaulters
        : widget.data.members.where((m) { final i = m.byGroup[_filter!.id]; return i != null && i.isUnpaid; }).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((m) => m.houseNo.toLowerCase().contains(q) || m.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _defaulters;
    final outstanding = list.fold<int>(0, (s, m) => s + m.totalBalance);

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(children: [
          Row(children: [
            Expanded(child: _SearchField(ctrl: _searchCtrl, hint: 'Search flat or name…',
                onChanged: (v) => setState(() => _search = v))),
            const SizedBox(width: 8),
            _ExportBtn(onTap: () => widget.onExport(_filter?.id)),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _Chip('All Dues', _filter == null, () => setState(() => _filter = null)),
            ...widget.data.groups.map((g) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _Chip(g.title, _filter == g, () => setState(() => _filter = _filter == g ? null : g),
                  color: g.type == 'DEMAND' ? const Color(0xFF7C3AED) : AppColors.primary),
            )),
          ])),
        ]),
      ),
      Container(height: 1, color: AppColors.border),
      _SummaryStrip(
        icon: Icons.person_off_rounded,
        left: '${list.length} defaulter${list.length != 1 ? 's' : ''}',
        right: 'Outstanding: ₹${NumberFormat('#,##0').format(outstanding)}',
        color: AppColors.error,
      ),
      Expanded(
        child: list.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded, size: 52, color: AppColors.success),
                const SizedBox(height: 12),
                Text(_filter == null ? 'No defaulters! Everyone is paid up. 🎉' : 'No defaulters for this due.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _DefaulterCard(
                    member: list[i], groups: widget.data.groups, groupFilter: _filter)),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED CARD WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _DueSummaryCard extends StatelessWidget {
  final _DueGroup group;
  const _DueSummaryCard({required this.group});

  String _fmt(int v) => '₹${NumberFormat('#,##0').format(v)}';

  @override
  Widget build(BuildContext context) {
    final isDemand = group.type == 'DEMAND';
    final color    = isDemand ? const Color(0xFF7C3AED) : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isDemand ? Icons.request_quote_rounded : Icons.home_outlined, size: 11, color: color),
              const SizedBox(width: 4),
              Text(isDemand ? 'DEMAND' : 'MAINTENANCE',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Spacer(),
          Text('${group.invoiceCount} members', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Text(group.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Row(children: [
          _MiniStat('Billed',    _fmt(group.totalBilled),    AppColors.textSecondary),
          _MiniStat('Collected', _fmt(group.totalCollected), AppColors.success),
          _MiniStat('Pending',   _fmt(group.totalOutstanding), AppColors.error),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: group.collectionRate, minHeight: 6,
            backgroundColor: AppColors.error.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color))),
        const SizedBox(height: 4),
        Row(children: [
          Text('${group.paidCount} paid', style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
          if (group.partialCount > 0)
            Text('  ·  ${group.partialCount} partial', style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
          Text('  ·  ${group.unpaidCount} unpaid', style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  final _MemberRow member;
  const _LedgerCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final st = member.overallStatus;
    final c  = st == 'CLEAR' ? AppColors.success : st == 'PARTIAL' ? AppColors.warning : AppColors.error;
    final isHouse = member.propertyType == 'house';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(
            color: (isHouse ? const Color(0xFF059669) : AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(isHouse ? Icons.house_rounded : Icons.apartment_rounded,
              color: isHouse ? const Color(0xFF059669) : AppColors.primary, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(member.houseNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Expanded(child: Text(member.name, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Text('Billed: ₹${NumberFormat('#,##0').format(member.totalBilled)}',
                style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
            const Text('  ·  ', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
            Text('Paid: ₹${NumberFormat('#,##0').format(member.totalPaid)}',
                style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
            if (member.totalBalance > 0) ...[
              const Text('  ·  ', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
              Text('Due: ₹${NumberFormat('#,##0').format(member.totalBalance)}',
                  style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ]),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(st, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _DueInvoiceCard extends StatelessWidget {
  final _MemberRow       member;
  final _InvoiceSummary invoice;
  const _DueInvoiceCard({required this.member, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final Color c;
    final String label;
    if (invoice.isPaid)         { c = AppColors.success; label = 'PAID'; }
    else if (invoice.isPartial) { c = AppColors.warning; label = 'PARTIAL'; }
    else                        { c = AppColors.error;   label = 'UNPAID'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(member.houseNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Expanded(child: Text(member.name, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Text('₹${NumberFormat('#,##0').format(invoice.amount)}', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
            if (invoice.paidAmount > 0) ...[
              const Text('  ·  ', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
              Text('Paid ₹${NumberFormat('#,##0').format(invoice.paidAmount)}',
                  style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
            if (invoice.balance > 0) ...[
              const Text('  ·  ', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
              Text('Due ₹${NumberFormat('#,##0').format(invoice.balance)}',
                  style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ]),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _DefaulterCard extends StatelessWidget {
  final _MemberRow       member;
  final List<_DueGroup>  groups;
  final _DueGroup?       groupFilter;
  const _DefaulterCard({required this.member, required this.groups, required this.groupFilter});

  @override
  Widget build(BuildContext context) {
    final isHouse = member.propertyType == 'house';
    final unpaid  = groupFilter != null
        ? groups.where((g) { final i = member.byGroup[g.id]; return g == groupFilter && i != null && i.isUnpaid; }).toList()
        : groups.where((g) { final i = member.byGroup[g.id]; return i != null && i.isUnpaid; }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(isHouse ? Icons.house_rounded : Icons.apartment_rounded, color: AppColors.error, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(member.houseNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Expanded(child: Text(member.name, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              ]),
              Text(isHouse ? 'Indep. House' : 'Flat',
                  style: TextStyle(color: isHouse ? AppColors.success : AppColors.primary,
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${NumberFormat('#,##0').format(member.totalBalance)}',
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 16)),
              const Text('outstanding', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
            ]),
          ]),
        ),
        if (unpaid.isNotEmpty) ...[
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('UNPAID DUES', style: TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: unpaid.map((g) {
                final inv = member.byGroup[g.id];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.2))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(g.type == 'DEMAND' ? Icons.request_quote_rounded : Icons.home_outlined,
                        size: 12, color: AppColors.error),
                    const SizedBox(width: 5),
                    Text(g.title, style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
                    if (inv != null && inv.balance > 0)
                      Text('  ₹${NumberFormat('#,##0').format(inv.balance)}',
                          style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                );
              }).toList()),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MICRO WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color  color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppTheme.cardDecoration,
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]),
  );
}

class _MemberStat extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  final IconData icon;
  const _MemberStat(this.label, this.count, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Container(width: 38, height: 38,
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 18)),
    const SizedBox(height: 5),
    Text('$count', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
    Text(label,    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
  ]));
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppColors.textHint,   fontSize: 10)),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
  ]));
}

class _StripStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _StripStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
    ]),
  );
}

class _SummaryStrip extends StatelessWidget {
  final IconData icon;
  final String   left, right;
  final Color    color;
  const _SummaryStrip({required this.icon, required this.left, required this.right, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    color: color,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      Icon(icon, color: Colors.white70, size: 16),
      const SizedBox(width: 6),
      Text(left,  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      const Spacer(),
      Text(right, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]),
  );
}

class _Chip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final VoidCallback onTap;
  final Color?   color;
  const _Chip(this.label, this.selected, this.onTap, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : AppColors.gray50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppColors.border, width: 1.5)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.ctrl, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      filled: true, fillColor: AppColors.gray50,
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    ),
  );
}

class _ExportBtn extends StatefulWidget {
  final Future<void> Function() onTap;
  const _ExportBtn({required this.onTap});
  @override State<_ExportBtn> createState() => _ExportBtnState();
}

class _ExportBtnState extends State<_ExportBtn> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _busy ? null : () async {
      setState(() => _busy = true);
      try { await widget.onTap(); } finally { if (mounted) setState(() => _busy = false); }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _busy
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.download_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 5),
        const Text('CSV', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
  );
}
