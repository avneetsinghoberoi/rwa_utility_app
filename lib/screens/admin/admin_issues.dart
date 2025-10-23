import 'package:flutter/material.dart';

class AdminIssueScreen extends StatefulWidget {
  const AdminIssueScreen({super.key});

  @override
  State<AdminIssueScreen> createState() => _AdminIssueScreenState();
}

class _AdminIssueScreenState extends State<AdminIssueScreen> {
  String selectedStatus = "Open";

  final List<Map<String, dynamic>> complaints = [
    {
      "title": "Garbage not collected regularly",
      "description": "Garbage bins overflowing, collection not happening on schedule",
      "resident": "Mike Johnson",
      "unit": "B-201",
      "category": "Cleanliness",
      "date": "22/10/2025",
      "status": "Open"
    },
    {
      "title": "Water leakage in Block A",
      "description": "Leak detected near main pipeline junction in Block A",
      "resident": "Jane Smith",
      "unit": "A-102",
      "category": "Maintenance",
      "date": "20/10/2025",
      "status": "In Progress"
    },
    {
      "title": "Broken lights in parking area",
      "description": "Two lights not functioning in basement parking area",
      "resident": "John Doe",
      "unit": "A-101",
      "category": "Electrical",
      "date": "18/10/2025",
      "status": "Resolved"
    },
  ];

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredComplaints =
    complaints.where((c) => c["status"] == selectedStatus).toList();

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            _summaryCard("Open", "2", "Require attention", Icons.error_outline, Colors.red),
            const SizedBox(height: 12),
            _summaryCard("In Progress", "1", "Being worked on", Icons.access_time, Colors.blue),
            const SizedBox(height: 12),
            _summaryCard("Resolved", "1", "Completed", Icons.check_circle_outline, Colors.green),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // Complaint Management Header
            const Text("Complaint Management",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("View, assign, and resolve resident complaints",
                style: TextStyle(color: Colors.grey)),

            const SizedBox(height: 12),
            _statusChips(),

            const SizedBox(height: 16),
            Column(
              children: filteredComplaints.map((complaint) {
                return _complaintCard(complaint);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Summary Cards
  Widget _summaryCard(String title, String count, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3, spreadRadius: 1)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(count,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          Icon(icon, color: color, size: 26),
        ],
      ),
    );
  }

  // Status Filter Chips
  Widget _statusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip("Open", complaints.where((c) => c["status"] == "Open").length),
          const SizedBox(width: 8),
          _filterChip("In Progress", complaints.where((c) => c["status"] == "In Progress").length),
          const SizedBox(width: 8),
          _filterChip("Resolved", complaints.where((c) => c["status"] == "Resolved").length),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int count) {
    final isSelected = selectedStatus == label;
    return ChoiceChip(
      label: Text("$label ($count)",
          style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500)),
      selected: isSelected,
      onSelected: (_) => setState(() => selectedStatus = label),
      selectedColor: Colors.black,
      backgroundColor: Colors.grey.shade200,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  // Complaint Card Widget
  Widget _complaintCard(Map<String, dynamic> complaint) {
    final Color color = complaint["status"] == "Open"
        ? Colors.red
        : complaint["status"] == "In Progress"
        ? Colors.blue
        : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(complaint["title"],
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, height: 1.3)),
              ),
              _statusChip(complaint["status"], color),
            ],
          ),
          const SizedBox(height: 8),
          Text(complaint["description"], style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(complaint["resident"],
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              const Text("•"),
              const SizedBox(width: 4),
              Text(complaint["category"], style: const TextStyle(color: Colors.black54)),
              const SizedBox(width: 4),
              const Text("•"),
              const SizedBox(width: 4),
              Text(complaint["date"], style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          _assignDropdown(),
        ],
      ),
    );
  }

  // Status Chip (colored label)
  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              status == "Open"
                  ? Icons.error_outline
                  : status == "In Progress"
                  ? Icons.access_time
                  : Icons.check_circle_outline,
              size: 14,
              color: Colors.white),
          const SizedBox(width: 4),
          Text(status.toLowerCase(),
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Assign to Team Dropdown
  Widget _assignDropdown() {
    final List<String> teams = ["Security", "Maintenance", "Cleaning", "Electrical"];
    String? selectedTeam;

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: "Assign to team",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: teams
          .map((team) => DropdownMenuItem(
        value: team,
        child: Text(team),
      ))
          .toList(),
      onChanged: (value) {
        setState(() => selectedTeam = value);
      },
      value: selectedTeam,
      hint: const Text("Assign to team"),
    );
  }
}
