import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'pay_screen.dart';
import 'issues_screen.dart';
import 'notices_screen.dart';
import 'expense_screen.dart';
import 'qrpass_screen.dart';

class UserHomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const UserHomeScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${userData['name']}"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Maintenance Summary Card
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text("Maintenance Due"),
                subtitle: Text("House No: ${userData['house_no']}"),
                trailing: ElevatedButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const PayScreen())),
                  child: const Text("Pay Now"),
                ),
              ),
            ),
            const SizedBox(height: 16),

            /// Latest Notice Preview
            const Text("📢 Latest Notice", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder(
              future: FirebaseFirestore.instance
                  .collection('notices')
                  .orderBy('date', descending: true)
                  .limit(1)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final doc = snapshot.data!.docs.first;
                final notice = doc.data();
                return Card(
                  elevation: 2,
                  child: ListTile(
                    title: Text(notice['title']),
                    subtitle: Text(
                      notice['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const NoticesScreen())),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            /// Quick Access Grid
            const Text("🧾 Quick Access", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _quickButton(context, Icons.payment, "Pay", const PayScreen()),
                _quickButton(context, Icons.report_problem, "Issue", const IssuesScreen()),
                _quickButton(context, Icons.campaign, "Notices", const NoticesScreen()),
                _quickButton(context, Icons.qr_code, "QR Pass", const UserProfileScreen()),
                _quickButton(context, Icons.receipt_long, "Expenses", const ExpenseScreen()),
              ],
            ),
            const SizedBox(height: 20),

            /// Recent Payment Activity
            const Text("📈 Recent Payments", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('payments')
                  .where('house_no', isEqualTo: userData['qr_payload'])
                  .orderBy('timestamp', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text("No payments yet.");
                final docs = snapshot.data!.docs;
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final date = (data['timestamp'] as Timestamp).toDate();
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text("Paid ₹${data['amount_paid']}"),
                      subtitle: Text(DateFormat.yMMMd().format(date)),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickButton(BuildContext context, IconData icon, String label, Widget screen) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.blue),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
