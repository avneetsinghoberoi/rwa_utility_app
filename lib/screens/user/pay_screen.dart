import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(
          user!.uid).get();
      setState(() {
        userData = doc.exists ? doc.data() : {};
        loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching user data: $e');
      setState(() => loading = false);
    }
  }

  Future<void> _launchUPIPayment(int amount) async {
    final name = Uri.encodeComponent(userData?['name'] ?? 'Resident');
    final upiId = 'avneetoberoi739@okaxis';
    final note = Uri.encodeComponent('RWA Maintenance Payment');
    final url = 'upi://pay?pa=$upiId&pn=$name&tn=$note&am=$amount&cu=INR';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      await Future.delayed(const Duration(seconds: 2));
      await _confirmAndRecordPayment(amount);
    } else {
      debugPrint('⚠️ Could not open UPI app');
    }
  }

  Future<void> _confirmAndRecordPayment(int amount) async {
    String txnId = '';
    String appName = '';

    await showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: const Text("Confirm Payment"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    "Enter transaction ID and UPI app used for verification."),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'Transaction ID'),
                  onChanged: (val) => txnId = val,
                ),
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'UPI App (e.g., GPay)'),
                  onChanged: (val) => appName = val,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Submit"),
              ),
            ],
          ),
    );

    if (txnId.isNotEmpty && appName.isNotEmpty) {
      await _recordPayment(amount, txnId, appName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
            "Payment not recorded. Please provide valid details.")),
      );
    }
  }

  Future<void> _recordPayment(int amount, String txnId, String appName) async {
    final houseId = userData?['qr_payload'] ?? user!.uid;
    final now = DateTime.now();
    final paymentId = 'PAY_${houseId}_${now.millisecondsSinceEpoch}';

    try {
      await FirebaseFirestore.instance.collection('payments')
          .doc(paymentId)
          .set({
        'house_no': houseId,
        'amount_paid': amount,
        'timestamp': now,
        'status': 'Paid',
        'mode': 'UPI Deep Link',
        'remarks': '${now.month}-${now.year} Maintenance',
        'txn_id': txnId,
        'upi_app': appName,
      });

      final currentDue = userData?['dues'] ?? 0;
      await FirebaseFirestore.instance.collection('users')
          .doc(user!.uid)
          .update({
        'dues': (currentDue - amount).clamp(0, double.infinity),
        'maintenance_status': (currentDue - amount) <= 0 ? 'Paid' : 'Partial',
        'last_payment_date': now.toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Payment recorded successfully!')),
      );

      fetchUserData();
    } catch (e) {
      debugPrint('❌ Error recording payment: $e');
    }
  }

  void _showQrDialog(BuildContext context, String upiUrl, int amount) {
    showDialog(
      context: context,
      builder: (_) =>
          Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Scan to Pay", style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),

                  Container(
                    width: 240,
                    height: 240,
                    padding: const EdgeInsets.all(8),
                    color: Colors.white,
                    child: QrImageView(
                      data: upiUrl,
                      version: QrVersions.auto,
                      size: 220.0,
                      backgroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text("Amount: ₹$amount", style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    "Use any UPI app (GPay, Paytm, PhonePe, etc.) to scan",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _confirmAndRecordPayment(amount);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Mark as Paid"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ),
          ),
    );
  }


  void _showPaymentOptionsDialog(BuildContext context, int amount) {
    final name = Uri.encodeComponent(userData?['name'] ?? 'Resident');
    final upiId = 'avneetoberoi739@okaxis';
    final note = Uri.encodeComponent('RWA Maintenance Payment');
    final upiUrl = 'upi://pay?pa=$upiId&pn=$name&tn=$note&am=$amount&cu=INR';

    showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text("Choose Payment Method"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    "Select how you’d like to pay your maintenance dues."),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(upiUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                          uri, mode: LaunchMode.externalApplication);
                      Navigator.pop(context);
                      await Future.delayed(const Duration(seconds: 2));
                      await _confirmAndRecordPayment(amount);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(
                            "⚠️ No UPI app found on this device")),
                      );
                    }
                  },
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text("Pay via UPI App"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showQrDialog(context, upiUrl, amount);
                  },
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text("Pay by Scanning QR"),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45)),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
            ],
          ),
    );
  }

  Widget _summaryCard(String title, String amount, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12), color: Colors.grey[100]),
      child: Column(
        children: [
          Text(title, style: TextStyle(
              fontWeight: FontWeight.w500, color: Colors.grey[700])),
          Text(amount, style: TextStyle(
              fontSize: 16, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _paymentCard(Map<String, dynamic> data) {
    final date = (data['timestamp'] as Timestamp).toDate();
    final status = data['status'];
    final amt = data['amount_paid'];
    final remark = data['remarks'];
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text('${date.month}/${date.year} - $remark'),
        subtitle: Text(status, style: TextStyle(
            color: status == 'Paid' ? Colors.green : Colors.red)),
        trailing: OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) =>
                  AlertDialog(
                    title: const Text("Payment Receipt"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("House: ${userData?['house_no']}"),
                        Text("Amount: ₹$amt"),
                        Text("Txn ID: ${data['txn_id'] ?? 'N/A'}"),
                        Text("UPI App: ${data['upi_app'] ?? 'N/A'}"),
                        Text("Status: $status"),
                        Text("Date: ${DateFormat.yMMMd().format(date)}"),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context),
                          child: const Text("Close"))
                    ],
                  ),
            );
          },
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text("Receipt"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final dues = userData?['dues'] ?? 0;
    final totalPaid = userData?['total_paid'] ?? 0;
    final status = userData?['maintenance_status'] ?? 'Pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Payments'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryCard('Total', '₹${dues + totalPaid}', Colors.black),
                _summaryCard('Paid', '₹$totalPaid', Colors.green),
                _summaryCard(
                    'Due', '₹$dues', dues > 0 ? Colors.red : Colors.green),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Maintenance Status: $status',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('House No: ${userData?['house_no']}'),
                    Text('Resident: ${userData?['name']}'),
                    const SizedBox(height: 16),
                    if (dues > 0)
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showPaymentOptionsDialog(context, dues),
                        icon: const Icon(Icons.payment),
                        label: Text('Pay ₹$dues Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      )
                    else
                      const Text(
                        '✅ No pending dues. Thank you for staying up to date!',
                        style: TextStyle(color: Colors.green),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text('Payment History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('payments')
                  .where('house_no', isEqualTo: userData?['qr_payload'])
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty)
                  return const Text('No payment history found.');
                return Column(children: docs.map((doc) =>
                    _paymentCard(doc.data() as Map<String, dynamic>)).toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}
