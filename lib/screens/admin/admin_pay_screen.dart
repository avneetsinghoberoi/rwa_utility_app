import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminPayScreen extends StatefulWidget {
  const AdminPayScreen({super.key});

  @override
  State<AdminPayScreen> createState() => _AdminPayScreenState();
}

class _AdminPayScreenState extends State<AdminPayScreen> {
  String selectedFilter = "All";
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Admin Portal", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data!.docs;
              final totalExpected = users.length * 500;
              double collected = 0.0;
              double pending = 0.0;

              final List<Map<String, dynamic>> paymentData = users.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] ?? 'N/A';
                final houseNo = data['house_no'] ?? '-';
                final status = data['maintenance_status'] ?? 'Pending';
                final dues = data['dues'] ?? 0;
                final lastPayment = data['last_payment_date'] ?? '-';

                if (status.toLowerCase() == 'paid') collected += 500.0;
                if (status.toLowerCase() != 'paid') pending += dues;

                return {
                  'name': name,
                  'unit': houseNo,
                  'status': status,
                  'dues': dues,
                  'paidDate': lastPayment != '-' ? lastPayment.toString().split('T').first : '-',
                  'id': doc.id,
                };
              }).toList();

              List<Map<String, dynamic>> filteredPayments = paymentData;
              if (selectedFilter != "All") {
                filteredPayments = filteredPayments
                    .where((p) => p['status'].toLowerCase() == selectedFilter.toLowerCase())
                    .toList();
              }
              if (searchQuery.isNotEmpty) {
                filteredPayments = filteredPayments
                    .where((p) =>
                p['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
                    p['unit'].toLowerCase().contains(searchQuery.toLowerCase()) ||
                    p['id'].toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryCard("Total Expected", "₹$totalExpected", "${users.length} residents", Icons.currency_rupee, Colors.black),
                  const SizedBox(height: 12),
                  _summaryCard("Collected", "₹$collected", "Payments received", Icons.check_circle_outline, Colors.green),
                  const SizedBox(height: 12),
                  _summaryCard("Pending", "₹$pending", "Outstanding balance", Icons.access_time_outlined, Colors.orange),
                  const SizedBox(height: 20),
                  const Divider(),

                  // Search Field
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
                    onChanged: (query) => setState(() => searchQuery = query),
                  ),

                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip("All", paymentData.length),
                        const SizedBox(width: 8),
                        _filterChip("Paid", paymentData.where((p) => p["status"].toLowerCase() == "paid").length),
                        const SizedBox(width: 8),
                        _filterChip("Pending", paymentData.where((p) => p["status"].toLowerCase() == "pending").length),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Table
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
              );
            },
          ),
        ),
      ),
    );
  }

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
          DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Dues", style: TextStyle(fontWeight: FontWeight.bold))),
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
                  Text(p["id"], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )),
              DataCell(Text(p["unit"].toString())),
              DataCell(_statusChip(p["status"])),
              DataCell(Text("₹${p["dues"]}")),
              DataCell(Text(p["paidDate"])),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _statusChip(String status) {
    final isPaid = status.toLowerCase() == "paid";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPaid ? Icons.check_circle_outline : Icons.access_time, size: 14, color: Colors.white),
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


