import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rms_app/theme/app_theme.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String selectedMonthKey = _currentMonthKey();

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _prettyMonthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    return DateFormat('MMMM yyyy').format(DateTime(year, month, 1));
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '₹0';
    if (amount is num) return '₹${NumberFormat('#,##0').format(amount)}';
    return amount.toString();
  }

  // ── Expense category color map ──────────────────────────────────
  Color _categoryColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('salary') || l.contains('staff')) return AppColors.primary;
    if (l.contains('electric') || l.contains('power')) return AppColors.warning;
    if (l.contains('water')) return const Color(0xFF06B6D4);
    if (l.contains('clean') || l.contains('sweep')) return AppColors.success;
    if (l.contains('security') || l.contains('guard')) return const Color(0xFF8B5CF6);
    if (l.contains('repair') || l.contains('maintain')) return AppColors.error;
    return AppColors.textSecondary;
  }

  IconData _categoryIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('salary') || l.contains('staff')) return Icons.people_rounded;
    if (l.contains('electric') || l.contains('power')) return Icons.bolt_rounded;
    if (l.contains('water')) return Icons.water_drop_rounded;
    if (l.contains('clean') || l.contains('sweep')) return Icons.cleaning_services_rounded;
    if (l.contains('security') || l.contains('guard')) return Icons.security_rounded;
    if (l.contains('repair') || l.contains('maintain')) return Icons.build_rounded;
    return Icons.receipt_long_rounded;
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final expensesRef = FirebaseFirestore.instance.collection('expenses');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Expense Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Month selector ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  expensesRef.orderBy('monthKey', descending: true).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox(height: 52);

                final months = snap.data!.docs
                    .map((d) =>
                        (d.data() as Map<String, dynamic>)['monthKey']
                            ?.toString())
                    .whereType<String>()
                    .toSet()
                    .toList()
                  ..sort((a, b) => b.compareTo(a));

                if (months.isEmpty) months.add(selectedMonthKey);
                if (!months.contains(selectedMonthKey)) {
                  months.insert(0, selectedMonthKey);
                }

                return DropdownButtonFormField<String>(
                  value: selectedMonthKey,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_month_rounded,
                        color: AppColors.primary, size: 20),
                    filled: true,
                    fillColor: AppColors.primaryLight,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  items: months
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(_prettyMonthLabel(m)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => selectedMonthKey = v);
                  },
                );
              },
            ),
          ),

          // ── Expense list ────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: expensesRef
                  .where('monthKey', isEqualTo: selectedMonthKey)
                  .orderBy('label')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 64, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        Text(
                          'No expenses for ${_prettyMonthLabel(selectedMonthKey)}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                num total = 0;
                for (final d in docs) {
                  final data = d.data() as Map<String, dynamic>;
                  final amt = data['amount'];
                  if (amt is num) total += amt;
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Total summary card ──────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppTheme.primaryShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _prettyMonthLabel(selectedMonthKey),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12),
                              ),
                              Text(
                                '₹${NumberFormat('#,##0').format(total)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Total Expenses  •  ${docs.length} items',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Expense items ───────────────────────────
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final label = (data['label'] ?? 'Unknown').toString();
                      final amount = _formatAmount(data['amount']);
                      final desc = (data['description'] ?? '').toString();
                      final color = _categoryColor(label);
                      final icon = _categoryIcon(label);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: AppTheme.cardDecoration,
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, color: color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.textPrimary)),
                                  if (desc.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(desc,
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12)),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              amount,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
