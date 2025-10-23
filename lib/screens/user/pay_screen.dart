import 'package:flutter/material.dart';

class PayScreen extends StatelessWidget {
  const PayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Resident Portal")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryCard("Total", "₹20k", Colors.black),
                _summaryCard("Paid", "₹15k", Colors.green),
                _summaryCard("Due", "₹5k", Colors.red),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Payment History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _paymentCard("October 2025", "Due", "₹5,000", Colors.red, true),
            _paymentCard("September 2025", "Paid", "₹5,000", Colors.green, false),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String amount, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
          Text(amount, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _paymentCard(String month, String status, String amount, Color color, bool due) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(month),
        subtitle: Text(status, style: TextStyle(color: color)),
        trailing: due
            ? ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.payment_outlined),
          label: const Text("Pay Now"),
        )
            : OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text("Receipt"),
        ),
      ),
    );
  }
}
