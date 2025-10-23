import 'package:flutter/material.dart';
import 'package:rms_app/screens/login/login_screen.dart';

class AdminExpenseScreen extends StatefulWidget {
  const AdminExpenseScreen({super.key});

  @override
  State<AdminExpenseScreen> createState() => _AdminExpenseScreenState();
}

class _AdminExpenseScreenState extends State<AdminExpenseScreen> {
  final List<Map<String, dynamic>> expenses = [
    {
      "date": "1/10/2025",
      "category": "Electricity",
      "description": "Monthly EB Bill",
      "amount": "₹25,000"
    },
    {
      "date": "1/10/2025",
      "category": "Water Supply",
      "description": "Water Tanker Service",
      "amount": "₹20,000"
    },
    {
      "date": "1/10/2025",
      "category": "Staff Salaries",
      "description": "Security, Cleaner, Supervisor",
      "amount": "₹60,000"
    },
    {
      "date": "5/10/2025",
      "category": "Maintenance",
      "description": "Electrical and plumbing work",
      "amount": "₹20,000"
    },
    {
      "date": "10/10/2025",
      "category": "Administrative",
      "description": "Stationery + Festive Arrangements",
      "amount": "₹10,000"
    },
  ];

  void _openAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddExpenseDialog(),
    );
  }

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard("Current Month", "₹1,35,000", "October 2025", Icons.calendar_today_outlined),
                _buildSummaryCard("Total Expenses", "₹1,35,000", "5 entries", Icons.receipt_long),
              ],
            ),
            const SizedBox(height: 10),
            _buildSummaryCard("Categories", "5", "Expense types", Icons.category_outlined),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

            // ✅ FIXED TABLE SCROLL
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 30,
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F6F8)),
                    columns: const [
                      DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Description", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Amount", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: expenses.map((e) {
                      return DataRow(
                        cells: [
                          DataCell(Text(e["date"])),
                          DataCell(Text(e["category"])),
                          DataCell(Text(e["description"])),
                          DataCell(Text(e["amount"])),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
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
  String? month = "October 2025";
  String? category;
  String description = "";
  String amount = "";
  DateTime date = DateTime.now();

  final List<String> months = ["October 2025", "September 2025", "August 2025"];
  final List<String> categories = [
    "Electricity",
    "Water Supply",
    "Staff Salaries",
    "Maintenance",
    "Security",
    "Administrative",
  ];

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
                onChanged: (value) => setState(() => month = value),
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
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
            }
          },
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

