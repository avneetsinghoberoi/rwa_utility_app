import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String selectedMonthKey = _currentMonthKey();

  static String _currentMonthKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  String _prettyMonthLabelFromKey(String monthKey) {
    final parts = monthKey.split("-");
    if (parts.length != 2) return monthKey;
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    return DateFormat('MMMM yyyy').format(DateTime(year, month, 1));
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return "₹0";
    if (amount is num) return "₹${NumberFormat('#,##0').format(amount)}";
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final expensesRef = FirebaseFirestore.instance.collection('expenses');

    return Scaffold(
      appBar: AppBar(title: const Text("Resident Portal")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Expense Breakdown",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // ✅ Month selector
            Row(
              children: [
                const Text("Month: ", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: expensesRef.orderBy('monthKey', descending: true).snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox(height: 48);

                      final docs = snap.data!.docs;
                      final months = docs
                          .map((d) => (d.data() as Map<String, dynamic>)['monthKey']?.toString())
                          .whereType<String>()
                          .toSet()
                          .toList()
                        ..sort((a, b) => b.compareTo(a));

                      if (months.isEmpty) months.add(selectedMonthKey);
                      if (!months.contains(selectedMonthKey)) months.insert(0, selectedMonthKey);

                      return DropdownButton<String>(
                        isExpanded: true,
                        value: selectedMonthKey,
                        items: months
                            .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(_prettyMonthLabelFromKey(m)),
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
              ],
            ),

            const SizedBox(height: 12),

            // ✅ Month-wise expenses
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
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(child: Text("No expenses for ${_prettyMonthLabelFromKey(selectedMonthKey)}"));
                  }

                  num total = 0;
                  for (final d in docs) {
                    final data = d.data() as Map<String, dynamic>;
                    final amt = data['amount'];
                    if (amt is num) total += amt;
                  }

                  return Column(
                    children: [
                      // Total card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).colorScheme.surfaceVariant,
                        ),
                        child: Text(
                          "Total: ₹${NumberFormat('#,##0').format(total)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      Expanded(
                        child: ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final label = (data['label'] ?? 'Unknown').toString();
                            final amount = _formatAmount(data['amount']);
                            final desc = (data['description'] ?? '').toString();

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        if (desc.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(desc, style: const TextStyle(color: Colors.grey)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

