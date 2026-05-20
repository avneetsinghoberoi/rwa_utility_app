import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'package:gate_basic/utils/admin_dashboard_key.dart';

// ── Data holder ───────────────────────────────────────────────────────────────
class _ReportData {
  // Finance
  final int totalInvoices;
  final int paidInvoices;
  final int submittedInvoices;
  final int unpaidInvoices;
  final double totalBilled;
  final double totalCollected;
  final double totalPending;
  final double totalExpenses;

  // Complaints
  final int openComplaints;
  final int inProgressComplaints;
  final int resolvedComplaints;
  final List<Map<String, dynamic>> recentComplaints;

  // Members
  final int totalMembers;
  final int ownerCount;
  final int tenantCount;

  const _ReportData({
    required this.totalInvoices,
    required this.paidInvoices,
    required this.submittedInvoices,
    required this.unpaidInvoices,
    required this.totalBilled,
    required this.totalCollected,
    required this.totalPending,
    required this.totalExpenses,
    required this.openComplaints,
    required this.inProgressComplaints,
    required this.resolvedComplaints,
    required this.recentComplaints,
    required this.totalMembers,
    required this.ownerCount,
    required this.tenantCount,
  });

  double get netBalance => totalCollected - totalExpenses;
  int get totalComplaints => openComplaints + inProgressComplaints + resolvedComplaints;
}

// ── Filter enum ───────────────────────────────────────────────────────────────
enum _Filter { thisMonth, lastMonth, allTime }

// ── Screen ────────────────────────────────────────────────────────────────────
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  _Filter _filter = _Filter.thisMonth;
  late Future<_ReportData> _future;

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  void _setFilter(_Filter f) {
    setState(() {
      _filter = f;
      _future = _loadData();
    });
  }

  Future<_ReportData> _loadData() async {
    final now = DateTime.now();
    final thisMonthKey = _monthKey(now);
    final lastMonthKey = _monthKey(DateTime(now.year, now.month - 1));

    // ── Invoices ──────────────────────────────────────────────────────
    Query<Map<String, dynamic>> invoiceQ =
        FirebaseFirestore.instance.collection('invoices');
    if (_filter == _Filter.thisMonth) {
      invoiceQ = invoiceQ.where('month', isEqualTo: thisMonthKey);
    } else if (_filter == _Filter.lastMonth) {
      invoiceQ = invoiceQ.where('month', isEqualTo: lastMonthKey);
    }

    // ── Expenses ──────────────────────────────────────────────────────
    Query<Map<String, dynamic>> expenseQ =
        FirebaseFirestore.instance.collection('expenses');
    if (_filter == _Filter.thisMonth) {
      expenseQ = expenseQ.where('monthKey', isEqualTo: thisMonthKey);
    } else if (_filter == _Filter.lastMonth) {
      expenseQ = expenseQ.where('monthKey', isEqualTo: lastMonthKey);
    }

    // ── Run all queries in parallel ───────────────────────────────────
    final results = await Future.wait([
      invoiceQ.get(),
      expenseQ.get(),
      FirebaseFirestore.instance.collection('complaints').get(),
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .get(),
    ]);

    // ── Parse invoices ────────────────────────────────────────────────
    final invoiceDocs = results[0].docs;
    int paid = 0, submitted = 0, unpaid = 0;
    double billed = 0, collected = 0;
    for (final d in invoiceDocs) {
      final data = d.data();
      final status = (data['status'] ?? '').toString();
      final amount = (data['amount'] ?? 0).toDouble();
      billed += amount;
      if (status == 'PAID') {
        paid++;
        collected += amount;
      } else if (status == 'SUBMITTED') {
        submitted++;
      } else {
        unpaid++;
      }
    }
    final pending = billed - collected;

    // ── Parse expenses ────────────────────────────────────────────────
    final expenseDocs = results[1].docs;
    double expenses = 0;
    for (final d in expenseDocs) {
      final data = d.data();
      expenses += (data['amount'] ?? 0).toDouble();
    }

    // ── Parse complaints ──────────────────────────────────────────────
    final complaintDocs = results[2].docs;
    int openC = 0, inProgressC = 0, resolvedC = 0;
    final sortedComplaints = [...complaintDocs];
    sortedComplaints.sort((a, b) {
      final aTs = (a.data() as Map)['created_at'];
      final bTs = (b.data() as Map)['created_at'];
      if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
      return 0;
    });

    for (final d in complaintDocs) {
      final data = d.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'open' || status == 'pending') {
        openC++;
      } else if (status == 'in_progress' || status == 'inprogress' || status == 'in progress') {
        inProgressC++;
      } else {
        resolvedC++;
      }
    }

    final recentComplaints = sortedComplaints
        .take(5)
        .map((d) => {
              'id': d.id,
              ...d.data() as Map<String, dynamic>,
            })
        .toList();

    // ── Parse users ───────────────────────────────────────────────────
    final userDocs = results[3].docs;
    int owners = 0, tenants = 0;
    for (final d in userDocs) {
      final data = d.data() as Map<String, dynamic>;
      final accountLink = data['account_link'] as Map?;
      final isOwner = accountLink == null ||
          accountLink['primary_owner_uid'] == null ||
          accountLink['primary_owner_uid'].toString().isEmpty;
      if (isOwner) {
        owners++;
      } else {
        tenants++;
      }
    }

    return _ReportData(
      totalInvoices: invoiceDocs.length,
      paidInvoices: paid,
      submittedInvoices: submitted,
      unpaidInvoices: unpaid,
      totalBilled: billed,
      totalCollected: collected,
      totalPending: pending,
      totalExpenses: expenses,
      openComplaints: openC,
      inProgressComplaints: inProgressC,
      resolvedComplaints: resolvedC,
      recentComplaints: recentComplaints,
      totalMembers: userDocs.length,
      ownerCount: owners,
      tenantCount: tenants,
    );
  }

  // ── Formatters ────────────────────────────────────────────────────────────
  String _fmt(double n) => '₹${NumberFormat('#,##0').format(n)}';

  String get _filterLabel {
    final now = DateTime.now();
    switch (_filter) {
      case _Filter.thisMonth:
        return DateFormat('MMMM yyyy').format(now);
      case _Filter.lastMonth:
        return DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1));
      case _Filter.allTime:
        return 'All Time';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => setState(() => _future = _loadData()),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: FutureBuilder<_ReportData>(
        future: _future,
        builder: (context, snap) {
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _loadData()),
            child: snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : snap.hasError
                    ? _errorState(snap.error.toString())
                    : _body(snap.data!),
          );
        },
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text('Failed to load reports',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _future = _loadData()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(_ReportData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Time filter chips ────────────────────────────────────────
        _filterChips(),
        const SizedBox(height: 20),

        // ── Finance section ──────────────────────────────────────────
        _sectionHeader(
            Icons.account_balance_wallet_rounded, 'Finance Overview',
            subtitle: _filterLabel),
        const SizedBox(height: 12),
        _financeCards(data),
        const SizedBox(height: 12),
        if (data.totalInvoices > 0) ...[
          _invoiceBreakdownBar(data),
          const SizedBox(height: 12),
        ],

        // ── Complaints section ───────────────────────────────────────
        const SizedBox(height: 8),
        _sectionHeader(
            Icons.report_problem_rounded, 'Complaints & Issues',
            subtitle: '${data.totalComplaints} total'),
        const SizedBox(height: 12),
        _complaintCards(data),
        if (data.recentComplaints.isNotEmpty) ...[
          const SizedBox(height: 12),
          _recentComplaintsList(data.recentComplaints),
        ],

        // ── Member summary ───────────────────────────────────────────
        const SizedBox(height: 20),
        _sectionHeader(Icons.people_alt_rounded, 'Member Summary',
            subtitle: '${data.totalMembers} residents'),
        const SizedBox(height: 12),
        _memberCards(data),

        const SizedBox(height: 32),
      ],
    );
  }

  // ── Filter chips ──────────────────────────────────────────────────────────
  Widget _filterChips() {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _chip('This Month', _Filter.thisMonth),
          _chip('Last Month', _Filter.lastMonth),
          _chip('All Time', _Filter.allTime),
        ],
      ),
    );
  }

  Widget _chip(String label, _Filter f) {
    final selected = _filter == f;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setFilter(f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String title, {String? subtitle}) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
            if (subtitle != null)
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  // ── Finance cards ─────────────────────────────────────────────────────────
  Widget _financeCards(_ReportData d) {
    // Top hero card
    return Column(
      children: [
        // Collected vs Pending hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.primaryShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Billed',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                _fmt(d.totalBilled),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _heroStat(
                      'Collected',
                      _fmt(d.totalCollected),
                      const Color(0xFF4ADE80),
                      Icons.check_circle_rounded,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(
                    child: _heroStat(
                      'Pending',
                      _fmt(d.totalPending),
                      const Color(0xFFFBBF24),
                      Icons.hourglass_empty_rounded,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(
                    child: _heroStat(
                      'Expenses',
                      _fmt(d.totalExpenses),
                      const Color(0xFFF87171),
                      Icons.receipt_long_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Net balance card
        Container(
          decoration: BoxDecoration(
            color: d.netBalance >= 0
                ? AppColors.successLight
                : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: d.netBalance >= 0
                  ? AppColors.success.withOpacity(0.3)
                  : AppColors.error.withOpacity(0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                d.netBalance >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color:
                    d.netBalance >= 0 ? AppColors.success : AppColors.error,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Net Balance',
                style: TextStyle(
                    color: d.netBalance >= 0
                        ? AppColors.success
                        : AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              const Spacer(),
              Text(
                _fmt(d.netBalance.abs()),
                style: TextStyle(
                    color: d.netBalance >= 0
                        ? AppColors.success
                        : AppColors.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const SizedBox(width: 4),
              Text(
                d.netBalance >= 0 ? 'surplus' : 'deficit',
                style: TextStyle(
                    color: d.netBalance >= 0
                        ? AppColors.success
                        : AppColors.error,
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroStat(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  // ── Invoice breakdown bar ─────────────────────────────────────────────────
  Widget _invoiceBreakdownBar(_ReportData d) {
    final total = d.totalInvoices;
    if (total == 0) return const SizedBox.shrink();
    final paidFraction = d.paidInvoices / total;
    final submittedFraction = d.submittedInvoices / total;
    final unpaidFraction = d.unpaidInvoices / total;

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_outlined,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text('Invoice Status — $total residents',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (paidFraction > 0)
                    Flexible(
                      flex: (paidFraction * 100).round(),
                      child: Container(color: AppColors.success),
                    ),
                  if (submittedFraction > 0)
                    Flexible(
                      flex: (submittedFraction * 100).round(),
                      child: Container(color: AppColors.warning),
                    ),
                  if (unpaidFraction > 0)
                    Flexible(
                      flex: (unpaidFraction * 100).round(),
                      child:
                          Container(color: AppColors.error.withOpacity(0.6)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _barLegend(AppColors.success, 'Paid', d.paidInvoices),
              _barLegend(AppColors.warning, 'Review', d.submittedInvoices),
              _barLegend(
                  AppColors.error.withOpacity(0.7), 'Unpaid', d.unpaidInvoices),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barLegend(Color color, String label, int count) {
    return Row(
      children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text('$label: $count',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary)),
      ],
    );
  }

  // ── Complaint cards ───────────────────────────────────────────────────────
  Widget _complaintCards(_ReportData d) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Open',
            value: '${d.openComplaints}',
            icon: Icons.error_outline_rounded,
            color: AppColors.error,
            bg: const Color(0xFFFEE2E2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'In Progress',
            value: '${d.inProgressComplaints}',
            icon: Icons.pending_rounded,
            color: AppColors.warning,
            bg: AppColors.warningLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Resolved',
            value: '${d.resolvedComplaints}',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
            bg: AppColors.successLight,
          ),
        ),
      ],
    );
  }

  // ── Recent complaints list ────────────────────────────────────────────────
  Widget _recentComplaintsList(List<Map<String, dynamic>> complaints) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.history_rounded,
                      color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 10),
                const Text('Recent Complaints',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...complaints.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            final title = (c['title'] ?? c['subject'] ?? c['description'] ?? 'Complaint').toString();
            final status = (c['status'] ?? '').toString();
            final ts = c['created_at'];
            final date = ts is Timestamp
                ? DateFormat('dd MMM').format(ts.toDate())
                : '';
            final name = (c['resident_name'] ?? c['name'] ?? c['user_name'] ?? '').toString();

            Color statusColor;
            String statusLabel;
            if (status.toLowerCase() == 'open' || status.toLowerCase() == 'pending') {
              statusColor = AppColors.error;
              statusLabel = 'Open';
            } else if (status.toLowerCase().contains('progress')) {
              statusColor = AppColors.warning;
              statusLabel = 'In Progress';
            } else {
              statusColor = AppColors.success;
              statusLabel = 'Resolved';
            }

            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (name.isNotEmpty)
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(statusLabel,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (date.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(date,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textHint)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (i < complaints.length - 1)
                  const Divider(
                      height: 1, indent: 36, color: AppColors.divider),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Member cards ──────────────────────────────────────────────────────────
  Widget _memberCards(_ReportData d) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Total',
            value: '${d.totalMembers}',
            icon: Icons.people_alt_rounded,
            color: AppColors.primary,
            bg: AppColors.primaryLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Owners',
            value: '${d.ownerCount}',
            icon: Icons.home_rounded,
            color: const Color(0xFF7C3AED),
            bg: const Color(0xFFEDE9FE),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Tenants',
            value: '${d.tenantCount}',
            icon: Icons.key_rounded,
            color: const Color(0xFF0891B2),
            bg: const Color(0xFFE0F2FE),
          ),
        ),
      ],
    );
  }

  // ── Shared stat card ──────────────────────────────────────────────────────
  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: color,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
