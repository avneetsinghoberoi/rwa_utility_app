import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rms_app/screens/login/login_screen.dart';

class AdminExpenseScreen extends StatefulWidget {
  const AdminExpenseScreen({super.key});

  @override
  State<AdminExpenseScreen> createState() => _AdminExpenseScreenState();
}

class _AdminExpenseScreenState extends State<AdminExpenseScreen> {
  final _expensesRef = FirebaseFirestore.instance.collection('expenses');

  String selectedMonthKey = _monthKey(DateTime.now());
  String selectedMonthLabel = DateFormat('MMMM yyyy').format(DateTime.now());

  static String _monthKey(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    return "${d.year}-$mm"; // YYYY-MM
  }

  String _formatCurrency(num n) => "₹${NumberFormat('#,##0').format(n)}";

  void _openAddExpenseDialog() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AddExpenseDialog(
        defaultMonthKey: selectedMonthKey,
        defaultMonthLabel: selectedMonthLabel,
      ),
    );

    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense added successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text("Expense Manager", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Month selector (admin portal view)
            Row(
              children: [
                const Text("Month: ", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _expensesRef.orderBy('monthKey', descending: true).snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox(height: 48);

                      final docs = snap.data!.docs;
                      final months = docs
                          .map((d) => (d.data() as Map<String, dynamic>)['monthKey']?.toString())
                          .whereType<String>()
                          .toSet()
                          .toList()
                        ..sort((a, b) => b.compareTo(a));

                      if (months.isEmpty) {
                        months.add(selectedMonthKey);
                      }
                      if (!months.contains(selectedMonthKey)) {
                        months.insert(0, selectedMonthKey);
                      }

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
                          setState(() {
                            selectedMonthKey = v;
                            selectedMonthLabel = _prettyMonthLabelFromKey(v);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ✅ Filtered list for selected month
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _expensesRef
                    .where('monthKey', isEqualTo: selectedMonthKey)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    // If you see an index error, create the index from the link in console.
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final docs = (snapshot.data?.docs ?? []).toList()
                    ..sort((a, b) {
                      final ad = ((a.data() as Map<String, dynamic>)['date'] as Timestamp?)?.toDate();
                      final bd = ((b.data() as Map<String, dynamic>)['date'] as Timestamp?)?.toDate();
                      if (ad == null && bd == null) return 0;
                      if (ad == null) return 1;
                      if (bd == null) return -1;
                      return bd.compareTo(ad); // DESC
                    });

                  num totalMonth = 0;
                  final categorySet = <String>{};

                  for (final d in docs) {
                    final data = d.data() as Map<String, dynamic>;
                    final amount = (data['amount'] ?? 0) as num;
                    totalMonth += amount;

                    final c = (data['label'] ?? data['category'] ?? '').toString();
                    if (c.isNotEmpty) categorySet.add(c);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary cards
                      Row(
                        children: [
                          _buildSummaryCard(
                            "Selected Month",
                            _formatCurrency(totalMonth),
                            selectedMonthLabel,
                            Icons.calendar_today_outlined,
                          ),
                          _buildSummaryCard(
                            "Entries",
                            "${docs.length}",
                            "in this month",
                            Icons.receipt_long,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildSummaryCard(
                            "Categories",
                            "${categorySet.length}",
                            "expense types",
                            Icons.category_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Header + Add button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Expense Management",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: _openAddExpenseDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Add Expense"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Post and manage monthly expense details for transparency",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 10),

                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 26,
                              headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F6F8)),
                              columns: const [
                                DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Description", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Amount", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: docs.map((doc) {
                                final e = doc.data() as Map<String, dynamic>;
                                final ts = e['date'];
                                final date = ts is Timestamp ? ts.toDate() : DateTime.now();

                                final label = (e['label'] ?? e['category'] ?? '').toString();
                                final description = (e['description'] ?? '').toString();
                                final amount = (e['amount'] ?? 0) as num;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(DateFormat('d/M/yyyy').format(date))),
                                    DataCell(Text(label)),
                                    DataCell(Text(description)),
                                    DataCell(Text(_formatCurrency(amount))),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          await _expensesRef.doc(doc.id).delete();
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
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

  String _prettyMonthLabelFromKey(String monthKey) {
    // monthKey = YYYY-MM
    final parts = monthKey.split("-");
    if (parts.length != 2) return monthKey;
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    return DateFormat('MMMM yyyy').format(DateTime(year, month, 1));
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddExpenseDialog extends StatefulWidget {
  final String defaultMonthKey;
  final String defaultMonthLabel;

  const AddExpenseDialog({
    super.key,
    required this.defaultMonthKey,
    required this.defaultMonthLabel,
  });

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();

  late String monthKey;
  late String monthLabel;

  String? category;
  String description = "";
  String amount = "";
  DateTime date = DateTime.now();

  // ✅ keep categories like your old ones
  final List<String> categories = const [
    "Electricity",
    "Water Supply",
    "Staff Salaries",
    "Maintenance",
    "Security",
    "Administrative",
  ];

  @override
  void initState() {
    super.initState();
    monthKey = widget.defaultMonthKey;
    monthLabel = widget.defaultMonthLabel;
  }

  // ignore: unused_element
  String _formatMonthLabelFromKey(String key) {
    final parts = key.split("-");
    if (parts.length != 2) return key;
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    return DateFormat('MMMM yyyy').format(DateTime(y, m, 1));
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(date.year, date.month, 1),
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: "Select any date in the month",
    );
    if (picked == null) return;

    setState(() {
      monthKey = "${picked.year}-${picked.month.toString().padLeft(2, '0')}";
      monthLabel = DateFormat('MMMM yyyy').format(DateTime(picked.year, picked.month, 1));
    });
  }

  Future<void> _saveExpense() async {
    final parsedAmount = num.tryParse(amount.replaceAll(',', '').trim());

    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }
    if (category == null || category!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select a category")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('expenses').add({
      "date": Timestamp.fromDate(date),
      "monthKey": monthKey,
      "monthLabel": monthLabel,          // optional, but useful
      "label": category,                 // ✅ use 'label' consistently
      "description": description.trim(),
      "amount": parsedAmount,
      "createdAt": FieldValue.serverTimestamp(),
    });

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Add New Expense", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Month picker (writes monthKey)
              TextFormField(
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Month",
                  suffixIcon: Icon(Icons.calendar_month_outlined),
                ),
                controller: TextEditingController(text: monthLabel),
                onTap: _pickMonth,
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Category"),
                value: category,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (value) => setState(() => category = value),
              ),
              const SizedBox(height: 10),

              TextFormField(
                decoration: const InputDecoration(labelText: "Description"),
                onChanged: (value) => description = value,
              ),
              const SizedBox(height: 10),

              TextFormField(
                decoration: const InputDecoration(labelText: "Amount (₹)"),
                keyboardType: TextInputType.number,
                onChanged: (value) => amount = value,
              ),
              const SizedBox(height: 10),

              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Date",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => date = picked);
                      }
                    },
                  ),
                ),
                controller: TextEditingController(
                  text: "${date.day}/${date.month}/${date.year}",
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          onPressed: _saveExpense,
          icon: const Icon(Icons.check),
          label: const Text("Add Expense"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}



