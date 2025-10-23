import 'package:flutter/material.dart';

class AdminPayScreen extends StatefulWidget {
  const AdminPayScreen({super.key});

  @override
  State<AdminPayScreen> createState() => _AdminPayScreenState();
}

class _AdminPayScreenState extends State<AdminPayScreen> {
  String selectedFilter = "All";

  final List<Map<String, dynamic>> payments = [
    {"name": "John Doe", "id": "USER001", "unit": "A-101", "month": "October", "status": "pending", "paidDate": "-"},
    {"name": "Jane Smith", "id": "USER002", "unit": "A-102", "month": "October", "status": "paid", "paidDate": "15/10/2025"},
    {"name": "Mike Johnson", "id": "USER003", "unit": "B-201", "month": "October", "status": "pending", "paidDate": "-"},
    {"name": "Sarah Williams", "id": "USER004", "unit": "B-202", "month": "October", "status": "paid", "paidDate": "20/10/2025"},
    {"name": "John Doe", "id": "USER001", "unit": "A-101", "month": "September", "status": "paid", "paidDate": "28/9/2025"},
    {"name": "Mike Johnson", "id": "USER003", "unit": "B-201", "month": "September", "status": "pending", "paidDate": "-"},
  ];

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredPayments = selectedFilter == "All"
        ? payments
        : payments.where((p) => p["status"] == selectedFilter.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Admin Portal", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: () {}),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryCard("Total Expected", "₹30,000", "Current period", Icons.currency_rupee, Colors.black),
              const SizedBox(height: 12),
              _summaryCard("Collected", "₹15,000", "3 payments received", Icons.check_circle_outline, Colors.green),
              const SizedBox(height: 12),
              _summaryCard("Pending", "₹15,000", "3 outstanding", Icons.access_time_outlined, Colors.orange),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: "Search by name, unit, or ID",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (query) {
                  setState(() {
                    if (query.isEmpty) {
                      filteredPayments = payments;
                    } else {
                      filteredPayments = payments
                          .where((p) =>
                      p["name"].toLowerCase().contains(query.toLowerCase()) ||
                          p["unit"].toLowerCase().contains(query.toLowerCase()) ||
                          p["id"].toLowerCase().contains(query.toLowerCase()))
                          .toList();
                    }
                  });
                },
              ),

              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip("All", payments.length),
                    const SizedBox(width: 8),
                    _filterChip("Paid", payments.where((p) => p["status"] == "paid").length),
                    const SizedBox(width: 8),
                    _filterChip("Pending", payments.where((p) => p["status"] == "pending").length),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ✅ Scrollable table fix
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _paymentsTable(filteredPayments),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Summary Card Widget
  Widget _summaryCard(String title, String amount, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3, spreadRadius: 1)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(amount, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Icon(icon, size: 28, color: color),
        ],
      ),
    );
  }

  // Filter Chip Widget
  Widget _filterChip(String label, int count) {
    final isSelected = selectedFilter == label;
    return ChoiceChip(
      label: Text(
        "$label ($count)",
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => selectedFilter = label),
      selectedColor: Colors.black,
      backgroundColor: Colors.grey.shade200,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  // Payments Table
  Widget _paymentsTable(List<Map<String, dynamic>> filtered) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3, spreadRadius: 1)],
      ),
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F6F8)),
        columns: const [
          DataColumn(label: Text("Member", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Unit", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Month", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Paid Date", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: filtered.map((p) {
          return DataRow(
            cells: [
              DataCell(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(p["name"], style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(p["id"], style: const TextStyle(color: Colors.grey)),
                ],
              )),
              DataCell(Text(p["unit"])),
              DataCell(Text(p["month"])),
              DataCell(_statusChip(p["status"])),
              DataCell(Text(p["paidDate"])),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Status Chip
  Widget _statusChip(String status) {
    final bool isPaid = status == "paid";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? Colors.black : Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPaid ? Icons.check_circle_outline : Icons.access_time,
              size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            status,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

