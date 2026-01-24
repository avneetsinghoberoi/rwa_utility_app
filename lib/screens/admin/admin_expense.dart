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

  void _openAddExpenseDialog() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => const AddExpenseDialog(),
    );

    // No need to do anything; StreamBuilder auto refreshes.
    if (added == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense added successfully")),
      );
    }
  }

  String _formatCurrency(num n) => "₹${NumberFormat('#,##0').format(n)}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text("Admin Portal", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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

      // ✅ Now listening live from Firestore
      body: StreamBuilder<QuerySnapshot>(
        stream: _expensesRef.orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // Summary calculations
          final now = DateTime.now();
          final currentMonthLabel = DateFormat('MMMM yyyy').format(now);

          num totalAll = 0;
          num totalCurrentMonth = 0;

          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final amount = (data['amount'] ?? 0) as num;
            totalAll += amount;

            final ts = data['date'];
            final date = ts is Timestamp ? ts.toDate() : null;
            if (date != null && date.month == now.month && date.year == now.year) {
              totalCurrentMonth += amount;
            }
          }

          // Unique categories count
          final categorySet = <String>{};
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final c = (data['category'] ?? '').toString();
            if (c.isNotEmpty) categorySet.add(c);
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    _buildSummaryCard(
                      "Current Month",
                      _formatCurrency(totalCurrentMonth),
                      currentMonthLabel,
                      Icons.calendar_today_outlined,
                    ),
                    _buildSummaryCard(
                      "Total Expenses",
                      _formatCurrency(totalAll),
                      "${docs.length} entries",
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
                      "Expense types",
                      Icons.category_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Header Row with Add Button
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

                // Table
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 30,
                        headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F6F8)),
                        columns: const [
                          DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Month", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Description", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Amount", style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: docs.map((doc) {
                          final e = doc.data() as Map<String, dynamic>;
                          final ts = e['date'];
                          final date = ts is Timestamp ? ts.toDate() : DateTime.now();

                          final month = (e['month'] ?? '').toString();
                          final category = (e['category'] ?? '').toString();
                          final description = (e['description'] ?? '').toString();
                          final amount = (e['amount'] ?? 0) as num;

                          return DataRow(
                            cells: [
                              DataCell(Text(DateFormat('d/M/yyyy').format(date))),
                              DataCell(Text(month)),
                              DataCell(Text(category)),
                              DataCell(Text(description)),
                              DataCell(Text(_formatCurrency(amount))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();

  String month = "October 2025";
  String? category;
  String description = "";
  String amount = "";
  DateTime date = DateTime.now();

  final List<String> months = const [
    "January 2025",
    "February 2025",
    "March 2025",
    "April 2025",
    "May 2025",
    "June 2025",
    "July 2025",
    "August 2025",
    "September 2025",
    "October 2025",
    "November 2025",
    "December 2025",
  ];

  final List<String> categories = const [
    "Electricity",
    "Water Supply",
    "Staff Salaries",
    "Maintenance",
    "Security",
    "Administrative",
  ];

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
      "month": month,
      "category": category,
      "description": description.trim(),
      "amount": parsedAmount,
      "createdAt": FieldValue.serverTimestamp(),
    });

    Navigator.pop(context, true); // ✅ tell admin screen that add succeeded
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
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Month"),
                value: month,
                items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (value) => setState(() => month = value ?? month),
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
                        lastDate: DateTime(2026),
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


