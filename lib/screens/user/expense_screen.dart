import 'package:flutter/material.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = [
      {"label": "Electricity", "value": 35, "amount": "₹35k", "color": Colors.amber},
      {"label": "Water Supply", "value": 25, "amount": "₹25k", "color": Colors.blue},
      {"label": "Staff Salaries", "value": 50, "amount": "₹50k", "color": Colors.green},
      {"label": "Maintenance", "value": 20, "amount": "₹20k", "color": Colors.orange},
      {"label": "Security", "value": 10, "amount": "₹10k", "color": Colors.purple},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Resident Portal")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Expense Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            for (var item in expenses)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      CircleAvatar(backgroundColor: item["color"] as Color, radius: 8),
                      const SizedBox(width: 8),
                      Text(item["label"] as String),
                    ]),
                    Text(item["amount"] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
