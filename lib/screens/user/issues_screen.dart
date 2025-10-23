import 'package:flutter/material.dart';

class IssuesScreen extends StatelessWidget {
  const IssuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Resident Portal")),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _statusBox("Open", "1", Colors.red),
              _statusBox("Progress", "1", Colors.blue),
              _statusBox("Done", "1", Colors.green),
            ]),
            const SizedBox(height: 20),
            const Text("My Complaints", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _complaintCard("Power outage in Block A", "Frequent power cuts in Block A, especially during evenings", "Electricity", "In Progress", Colors.blue),
            _complaintCard("Water leakage in main area", "Water leaking from pipe near main gate", "Plumbing", "Resolved", Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _statusBox(String title, String count, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _complaintCard(String title, String desc, String category, String status, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text("$desc\n$category", style: const TextStyle(color: Colors.grey)),
        trailing: Chip(label: Text(status), backgroundColor: color.withOpacity(0.1), labelStyle: TextStyle(color: color)),
      ),
    );
  }
}
