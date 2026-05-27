import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'package:gate_basic/utils/admin_dashboard_key.dart';

class AdminDuesSheetScreen extends StatefulWidget {
  const AdminDuesSheetScreen({super.key});

  @override
  State<AdminDuesSheetScreen> createState() => _AdminDuesSheetScreenState();
}

class _AdminDuesSheetScreenState extends State<AdminDuesSheetScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_DuesSheetData> _future;
  String? _selectedPdfMonth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _future = _loadSheetData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_DuesSheetData> _loadSheetData() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('invoices').get(),
      db.collection('demand_dues').get(),
    ]);

    final invoiceDocs = results[0].docs;
    final demandDocs = results[1].docs;

    final demandsById = <String, Map<String, dynamic>>{
      for (final doc in demandDocs) doc.id: doc.data(),
    };
    final groupsByKey = <String, _DueGroup>{};

    for (final doc in invoiceDocs) {
      final data = doc.data();
      final row = _InvoiceRow.fromDoc(doc.id, data);
      final groupKey = row.groupKey;

      groupsByKey
          .putIfAbsent(groupKey, () {
            if (row.isDemand) {
              final demand = demandsById[row.demandId] ?? {};
              return _DueGroup(
                id: groupKey,
                title: demand['title']?.toString() ??
                    row.title.ifBlank('Demand Due'),
                subtitle: demand['description']?.toString() ?? row.description,
                type: 'DEMAND',
                status: demand['status']?.toString() ?? 'UNKNOWN',
                sortDate: _dateFromTimestamp(demand['created_at']) ??
                    _dateFromTimestamp(row.createdAt) ??
                    DateTime.fromMillisecondsSinceEpoch(0),
              );
            }

            return _DueGroup(
              id: groupKey,
              title: row.monthLabel,
              subtitle: 'Monthly maintenance',
              type: 'MAINTENANCE',
              status: 'MONTHLY',
              sortDate: _monthDate(row.month),
            );
          })
          .rows
          .add(row);
    }

    final groups = groupsByKey.values.toList()
      ..sort((a, b) => b.sortDate.compareTo(a.sortDate));

    return _DuesSheetData(groups: groups);
  }

  static DateTime? _dateFromTimestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static DateTime _monthDate(String month) {
    try {
      return DateTime.parse('$month-01');
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  void _refresh() {
    setState(() {
      _future = _loadSheetData();
    });
  }

  String _fmt(num value) => '₹${NumberFormat('#,##0').format(value)}';

  Future<void> _printDefaultersPdf(_DuesSheetData data,
      {String? monthKey}) async {
    try {
      final bytes = await _DefaultersPdfBuilder.build(data, monthKey: monthKey);
      final suffix = monthKey ?? 'overall';
      await Printing.layoutPdf(
        name: 'defaulters_dues_sheet_$suffix.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not print PDF: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareDefaultersPdf(_DuesSheetData data,
      {String? monthKey}) async {
    try {
      final bytes = await _DefaultersPdfBuilder.build(data, monthKey: monthKey);
      final suffix = monthKey ?? 'overall';
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'defaulters_dues_sheet_$suffix.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share PDF: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Dues Sheet',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
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
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Summary'),
            Tab(icon: Icon(Icons.table_chart_outlined), text: 'Dues'),
            Tab(icon: Icon(Icons.person_off_outlined), text: 'Unpaid'),
          ],
        ),
      ),
      body: FutureBuilder<_DuesSheetData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }
          final data = snapshot.data ?? const _DuesSheetData(groups: []);
          if (data.groups.isEmpty) {
            return const _EmptyState();
          }
          final monthKeys = data.monthKeys;
          final selectedMonth = monthKeys.contains(_selectedPdfMonth)
              ? _selectedPdfMonth
              : (monthKeys.isNotEmpty ? monthKeys.first : null);

          return TabBarView(
            controller: _tabController,
            children: [
              _SummaryTab(
                data: data,
                fmt: _fmt,
                selectedMonth: selectedMonth,
                monthKeys: monthKeys,
                onMonthChanged: (value) =>
                    setState(() => _selectedPdfMonth = value),
                onPrintOverall: () => _printDefaultersPdf(data),
                onShareOverall: () => _shareDefaultersPdf(data),
                onPrintMonth: selectedMonth == null
                    ? null
                    : () => _printDefaultersPdf(data, monthKey: selectedMonth),
                onShareMonth: selectedMonth == null
                    ? null
                    : () => _shareDefaultersPdf(data, monthKey: selectedMonth),
              ),
              _DuesTab(data: data, fmt: _fmt),
              _UnpaidTab(
                data: data,
                fmt: _fmt,
                selectedMonth: selectedMonth,
                monthKeys: monthKeys,
                onMonthChanged: (value) =>
                    setState(() => _selectedPdfMonth = value),
                onPrintOverall: () => _printDefaultersPdf(data),
                onShareOverall: () => _shareDefaultersPdf(data),
                onPrintMonth: selectedMonth == null
                    ? null
                    : () => _printDefaultersPdf(data, monthKey: selectedMonth),
                onShareMonth: selectedMonth == null
                    ? null
                    : () => _shareDefaultersPdf(data, monthKey: selectedMonth),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final _DuesSheetData data;
  final String Function(num value) fmt;
  final String? selectedMonth;
  final List<String> monthKeys;
  final ValueChanged<String?> onMonthChanged;
  final VoidCallback onPrintOverall;
  final VoidCallback onShareOverall;
  final VoidCallback? onPrintMonth;
  final VoidCallback? onShareMonth;

  const _SummaryTab({
    required this.data,
    required this.fmt,
    required this.selectedMonth,
    required this.monthKeys,
    required this.onMonthChanged,
    required this.onPrintOverall,
    required this.onShareOverall,
    required this.onPrintMonth,
    required this.onShareMonth,
  });

  @override
  Widget build(BuildContext context) {
    final topUnpaid = data.unpaidRows.take(8).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _MetricCard(
              label: 'Dues Generated',
              value: data.groups.length.toString(),
              icon: Icons.request_quote_rounded,
              color: AppColors.primary,
            ),
            _MetricCard(
              label: 'Total Billed',
              value: fmt(data.totalBilled),
              icon: Icons.receipt_long_rounded,
              color: AppColors.textPrimary,
            ),
            _MetricCard(
              label: 'Collected',
              value: fmt(data.totalCollected),
              icon: Icons.payments_rounded,
              color: AppColors.success,
            ),
            _MetricCard(
              label: 'Balance',
              value: fmt(data.totalBalance),
              icon: Icons.pending_actions_rounded,
              color: AppColors.error,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Combined Collection',
          action: '${data.paidCount}/${data.invoiceCount} paid',
        ),
        const SizedBox(height: 10),
        _ProgressCard(
          paid: data.totalCollected,
          billed: data.totalBilled,
          paidCount: data.paidCount,
          partialCount: data.partialCount,
          unpaidCount: data.unpaidCount,
          fmt: fmt,
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Residents With Balance',
          action: '${data.unpaidRows.length} entries',
        ),
        const SizedBox(height: 10),
        if (topUnpaid.isEmpty)
          const _CleanState()
        else ...[
          _PdfActionBar(
            selectedMonth: selectedMonth,
            monthKeys: monthKeys,
            onMonthChanged: onMonthChanged,
            onPrintOverall: onPrintOverall,
            onShareOverall: onShareOverall,
            onPrintMonth: onPrintMonth,
            onShareMonth: onShareMonth,
          ),
          const SizedBox(height: 10),
          ...topUnpaid.map((row) => _UnpaidRowTile(row: row, fmt: fmt)),
        ],
      ],
    );
  }
}

class _DuesTab extends StatelessWidget {
  final _DuesSheetData data;
  final String Function(num value) fmt;

  const _DuesTab({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = data.groups[index];
        return _DueGroupCard(group: group, fmt: fmt);
      },
    );
  }
}

class _UnpaidTab extends StatelessWidget {
  final _DuesSheetData data;
  final String Function(num value) fmt;
  final String? selectedMonth;
  final List<String> monthKeys;
  final ValueChanged<String?> onMonthChanged;
  final VoidCallback onPrintOverall;
  final VoidCallback onShareOverall;
  final VoidCallback? onPrintMonth;
  final VoidCallback? onShareMonth;

  const _UnpaidTab({
    required this.data,
    required this.fmt,
    required this.selectedMonth,
    required this.monthKeys,
    required this.onMonthChanged,
    required this.onPrintOverall,
    required this.onShareOverall,
    required this.onPrintMonth,
    required this.onShareMonth,
  });

  @override
  Widget build(BuildContext context) {
    final rows = data.unpaidRows;
    if (rows.isEmpty) return const _CleanState();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _PdfActionBar(
            selectedMonth: selectedMonth,
            monthKeys: monthKeys,
            onMonthChanged: onMonthChanged,
            onPrintOverall: onPrintOverall,
            onShareOverall: onShareOverall,
            onPrintMonth: onPrintMonth,
            onShareMonth: onShareMonth,
          );
        }
        return _UnpaidRowTile(row: rows[index - 1], fmt: fmt);
      },
    );
  }
}

class _PdfActionBar extends StatelessWidget {
  final String? selectedMonth;
  final List<String> monthKeys;
  final ValueChanged<String?> onMonthChanged;
  final VoidCallback onPrintOverall;
  final VoidCallback onShareOverall;
  final VoidCallback? onPrintMonth;
  final VoidCallback? onShareMonth;

  const _PdfActionBar({
    required this.selectedMonth,
    required this.monthKeys,
    required this.onMonthChanged,
    required this.onPrintOverall,
    required this.onShareOverall,
    required this.onPrintMonth,
    required this.onShareMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Defaulters PDF',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Print/share overall or month-wise pending dues',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedMonth,
                hint: const Text('No month available'),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: monthKeys
                    .map(
                      (month) => DropdownMenuItem(
                        value: month,
                        child: Text(_InvoiceRow.monthKeyLabel(month)),
                      ),
                    )
                    .toList(),
                onChanged: monthKeys.isEmpty ? null : onMonthChanged,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrintMonth,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Print Month'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShareMonth,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share Month'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPrintOverall,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Print Overall'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onShareOverall,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share Overall'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DueGroupCard extends StatelessWidget {
  final _DueGroup group;
  final String Function(num value) fmt;

  const _DueGroupCard({required this.group, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final progress = group.totalBilled == 0
        ? 0.0
        : (group.totalCollected / group.totalBilled).clamp(0.0, 1.0);
    final statusColor =
        group.isClosed ? AppColors.textSecondary : AppColors.success;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DueDetailSheet(group: group, fmt: fmt),
      ),
      child: Container(
        decoration: AppTheme.cardDecoration,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: group.isDemand
                        ? AppColors.warningLight
                        : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    group.isDemand
                        ? Icons.request_quote_rounded
                        : Icons.calendar_month_rounded,
                    color:
                        group.isDemand ? AppColors.warning : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        group.subtitle.ifBlank(group.type),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppTheme.statusChip(group.status, statusColor),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.errorLight,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniStat(label: 'Billed', value: fmt(group.totalBilled)),
                _MiniStat(label: 'Collected', value: fmt(group.totalCollected)),
                _MiniStat(label: 'Balance', value: fmt(group.totalBalance)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${group.paidCount} paid',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${group.partialCount} partial',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${group.unpaidCount} unpaid',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DueDetailSheet extends StatelessWidget {
  final _DueGroup group;
  final String Function(num value) fmt;

  const _DueDetailSheet({required this.group, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final rows = [...group.rows]..sort((a, b) {
        final houseCompare = a.houseNo.compareTo(b.houseNo);
        if (houseCompare != 0) return houseCompare;
        return a.name.compareTo(b.name);
      });

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${fmt(group.totalCollected)} collected of ${fmt(group.totalBilled)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, index) =>
                    _InvoiceRowTile(row: rows[index], fmt: fmt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRowTile extends StatelessWidget {
  final _InvoiceRow row;
  final String Function(num value) fmt;

  const _InvoiceRowTile({required this.row, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final color = row.statusColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                row.houseNo.ifBlank('-'),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name.ifBlank('Unknown resident'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paid ${fmt(row.paidAmount)} • Balance ${fmt(row.balance)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          AppTheme.statusChip(row.sheetStatus, color),
        ],
      ),
    );
  }
}

class _UnpaidRowTile extends StatelessWidget {
  final _InvoiceRow row;
  final String Function(num value) fmt;

  const _UnpaidRowTile({required this.row, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.subtleCardDecoration,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.person_off_outlined, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.name.ifBlank('Unknown')} • ${row.houseNo.ifBlank('-')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.groupTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            fmt(row.balance),
            style: const TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final num paid;
  final num billed;
  final int paidCount;
  final int partialCount;
  final int unpaidCount;
  final String Function(num value) fmt;

  const _ProgressCard({
    required this.paid,
    required this.billed,
    required this.paidCount,
    required this.partialCount,
    required this.unpaidCount,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final progress = billed == 0 ? 0.0 : (paid / billed).clamp(0.0, 1.0);
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                fmt(paid),
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const Text(
                ' collected',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.errorLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _LegendDot(color: AppColors.success, label: '$paidCount paid'),
              const SizedBox(width: 12),
              _LegendDot(
                  color: AppColors.warning, label: '$partialCount partial'),
              const SizedBox(width: 12),
              _LegendDot(color: AppColors.error, label: '$unpaidCount unpaid'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String action;

  const _SectionTitle({required this.title, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
        ),
        const Spacer(),
        Text(
          action,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No dues have been generated yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _CleanState extends StatelessWidget {
  const _CleanState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.cardDecoration,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: AppColors.success, size: 44),
            SizedBox(height: 10),
            Text(
              'No unpaid dues',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Every generated invoice is fully collected.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.error),
        ),
      ),
    );
  }
}

class _DefaultersPdfBuilder {
  static final _currency = NumberFormat('₹#,##0');
  static const _headerColor = PdfColor.fromInt(0xFF1E40AF);
  static const _errorColor = PdfColor.fromInt(0xFFDC2626);
  static const _warningColor = PdfColor.fromInt(0xFFF59E0B);
  static const _successColor = PdfColor.fromInt(0xFF059669);
  static const _rowAlt = PdfColor.fromInt(0xFFF8FAFC);

  static Future<Uint8List> build(_DuesSheetData data,
      {String? monthKey}) async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    final defaulters =
        monthKey == null ? data.unpaidRows : data.unpaidRowsForMonth(monthKey);
    final scopeLabel =
        monthKey == null ? 'Overall' : _InvoiceRow.monthKeyLabel(monthKey);
    final generatedOn =
        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final totalPending =
        defaulters.fold<num>(0, (total, row) => total + row.balance);
    final partialCount = defaulters.where((row) => row.isPartial).length;
    final unpaidCount = defaulters.length - partialCount;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: _headerColor,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DEFAULTERS DUES SHEET',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '$scopeLabel - residents with pending or partially paid dues',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                      ),
                    ),
                    pw.Text(
                      generatedOn,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _statBox('Pending Entries', '${defaulters.length}', _errorColor),
              pw.SizedBox(width: 8),
              _statBox(
                  'Total Balance', _currency.format(totalPending), _errorColor),
              pw.SizedBox(width: 8),
              _statBox('Unpaid', '$unpaidCount', _errorColor),
              pw.SizedBox(width: 8),
              _statBox('Partial', '$partialCount', _warningColor),
            ],
          ),
          pw.SizedBox(height: 16),
          if (defaulters.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Text(
                'No pending dues found.',
                style: pw.TextStyle(
                  color: _successColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Flat',
                'Resident',
                'Due',
                'Billed',
                'Paid',
                'Balance',
                'Status',
              ],
              data: defaulters.map((row) {
                return [
                  row.houseNo.ifBlank('-'),
                  row.name.ifBlank('Unknown'),
                  row.groupTitle,
                  _currency.format(row.amount),
                  row.paidAmount > 0 ? _currency.format(row.paidAmount) : '-',
                  _currency.format(row.balance),
                  row.sheetStatus,
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerDecoration: const pw.BoxDecoration(color: _headerColor),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(
                color: PdfColors.grey900,
                fontSize: 8,
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.center,
              },
              cellHeight: 22,
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
            ),
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            'Scope: $scopeLabel. This is a system-generated pending dues list from live invoice data. '
            'Balances include all currently unpaid or partially paid generated dues.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _tint(color, 0.9),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: _tint(color, 0.72), width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: const pw.TextStyle(
                color: PdfColors.grey700,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static PdfColor _tint(PdfColor color, double factor) {
    return PdfColor(
      color.red + (1.0 - color.red) * factor,
      color.green + (1.0 - color.green) * factor,
      color.blue + (1.0 - color.blue) * factor,
    );
  }
}

class _DuesSheetData {
  final List<_DueGroup> groups;

  const _DuesSheetData({required this.groups});

  Iterable<_InvoiceRow> get rows => groups.expand((group) => group.rows);

  int get invoiceCount => rows.length;
  num get totalBilled =>
      groups.fold<num>(0, (total, group) => total + group.totalBilled);
  num get totalCollected =>
      groups.fold<num>(0, (total, group) => total + group.totalCollected);
  num get totalBalance =>
      groups.fold<num>(0, (total, group) => total + group.totalBalance);
  int get paidCount => rows.where((row) => row.isPaid).length;
  int get partialCount => rows.where((row) => row.isPartial).length;
  int get unpaidCount => rows.where((row) => row.balance > 0).length;

  List<String> get monthKeys {
    final keys = rows
        .map((row) => row.reportMonthKey)
        .where((month) => month.isNotEmpty)
        .toSet()
        .toList();
    keys.sort((a, b) => b.compareTo(a));
    return keys;
  }

  List<_InvoiceRow> get unpaidRows {
    final list = rows.where((row) => row.balance > 0).toList();
    _sortDefaulters(list);
    return list;
  }

  List<_InvoiceRow> unpaidRowsForMonth(String monthKey) {
    final list = rows
        .where((row) => row.balance > 0 && row.reportMonthKey == monthKey)
        .toList();
    _sortDefaulters(list);
    return list;
  }

  void _sortDefaulters(List<_InvoiceRow> list) {
    list.sort((a, b) {
      final balanceCompare = b.balance.compareTo(a.balance);
      if (balanceCompare != 0) return balanceCompare;
      return a.houseNo.compareTo(b.houseNo);
    });
  }
}

class _DueGroup {
  final String id;
  final String title;
  final String subtitle;
  final String type;
  final String status;
  final DateTime sortDate;
  final List<_InvoiceRow> rows = [];

  _DueGroup({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.status,
    required this.sortDate,
  });

  bool get isDemand => type == 'DEMAND';
  bool get isClosed => status == 'CLOSED';
  num get totalBilled => rows.fold<num>(0, (total, row) => total + row.amount);
  num get totalCollected =>
      rows.fold<num>(0, (total, row) => total + row.paidAmount);
  num get totalBalance =>
      rows.fold<num>(0, (total, row) => total + row.balance);
  int get paidCount => rows.where((row) => row.isPaid).length;
  int get partialCount => rows.where((row) => row.isPartial).length;
  int get unpaidCount => rows.where((row) => row.balance > 0).length;
}

class _InvoiceRow {
  final String id;
  final String uid;
  final String name;
  final String houseNo;
  final String type;
  final String status;
  final String month;
  final String demandId;
  final String title;
  final String description;
  final num amount;
  final num paidAmount;
  final Object? createdAt;
  final Object? dueDate;

  _InvoiceRow({
    required this.id,
    required this.uid,
    required this.name,
    required this.houseNo,
    required this.type,
    required this.status,
    required this.month,
    required this.demandId,
    required this.title,
    required this.description,
    required this.amount,
    required this.paidAmount,
    required this.createdAt,
    required this.dueDate,
  });

  factory _InvoiceRow.fromDoc(String id, Map<String, dynamic> data) {
    final rawType = data['type']?.toString() ?? '';
    final demandId = data['demand_id']?.toString() ?? '';
    final month = data['month']?.toString() ?? '';
    final type =
        rawType == 'DEMAND' || demandId.isNotEmpty ? 'DEMAND' : 'MAINTENANCE';
    return _InvoiceRow(
      id: id,
      uid: data['uid']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      houseNo: data['house_no']?.toString() ?? '',
      type: type,
      status: data['status']?.toString() ?? 'UNPAID',
      month: month,
      demandId: demandId,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      amount: (data['amount'] as num?) ?? 0,
      paidAmount: (data['paid_amount'] as num?) ?? 0,
      createdAt: data['created_at'],
      dueDate: data['due_date'],
    );
  }

  bool get isDemand => type == 'DEMAND';

  String get groupKey {
    if (isDemand && demandId.isNotEmpty) return 'demand:$demandId';
    if (month.isNotEmpty) return 'month:$month';
    return 'invoice:$id';
  }

  String get groupTitle {
    if (isDemand) return title.ifBlank('Demand Due');
    return monthLabel;
  }

  String get monthLabel {
    if (month.isEmpty) return 'Monthly Maintenance';
    return monthKeyLabel(month);
  }

  String get reportMonthKey {
    if (month.isNotEmpty) return month;
    final date = _timestampToDate(dueDate) ?? _timestampToDate(createdAt);
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  static String monthKeyLabel(String monthKey) {
    try {
      return DateFormat('MMMM yyyy').format(DateTime.parse('$monthKey-01'));
    } catch (_) {
      return monthKey;
    }
  }

  static DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  num get balance {
    final value = amount - paidAmount;
    return value < 0 ? 0 : value;
  }

  bool get isPaid => balance <= 0 || status == 'PAID';
  bool get isPartial => paidAmount > 0 && !isPaid;

  String get sheetStatus {
    if (isPaid) return 'PAID';
    if (isPartial) return 'PARTIAL';
    return 'UNPAID';
  }

  Color get statusColor {
    if (isPaid) return AppColors.success;
    if (isPartial) return AppColors.warning;
    return AppColors.error;
  }
}

extension _BlankString on String {
  String ifBlank(String fallback) => trim().isEmpty ? fallback : this;
}
