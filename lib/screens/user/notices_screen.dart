import 'package:flutter/material.dart';

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Resident Portal")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _noticeCard("Diwali Festival Celebration", "Join us for Diwali celebrations on October 31st at the community hall.", "Event", Colors.blue),
            _noticeCard("Water Supply Maintenance", "Water supply will be interrupted on October 25th for maintenance work.", "Urgent", Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _noticeCard(String title, String desc, String type, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(type == "Urgent" ? Icons.warning_amber_rounded : Icons.event_note, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: Chip(label: Text(type), backgroundColor: color.withOpacity(0.1), labelStyle: TextStyle(color: color)),
      ),
    );
  }
}
