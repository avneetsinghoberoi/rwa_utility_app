import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UserPayScreen extends StatefulWidget {
  const UserPayScreen({super.key});
  @override
  State<UserPayScreen> createState() => _UserPayScreenState();
}

class _UserPayScreenState extends State<UserPayScreen> {
  final user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? userData;
  DocumentSnapshot<Map<String, dynamic>>? latestInvoice;

  final utrCtrl = TextEditingController();
  final amountCtrl = TextEditingController();

  bool loading = true;

  // 🔧 put your VPA/name here or fetch from settings if you want
  final String upiVpa = "avneetoberoi739@okaxis";
  final String upiName = "RWA Maintenance";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (user == null) return;

    try {
      final u = await FirebaseFirestore.instance.collection("users").doc(user!.uid).get();
      userData = u.data();

      // latest invoice for this uid
      final q = await FirebaseFirestore.instance
          .collection("invoices")
          .where("uid", isEqualTo: user!.uid)
          .orderBy("month", descending: true)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        latestInvoice = q.docs.first;
        amountCtrl.text = (latestInvoice!.data()?["amount"] ?? "").toString();
      }

      setState(() => loading = false);
    } catch (e) {
      setState(() => loading = false);
      debugPrint("❌ _load error: $e");
    }
  }

  String _upiLink({required String vpa, required String name, required String amount, required String note}) {
    // URL encode basic spaces etc.
    final n = Uri.encodeComponent(name);
    final t = Uri.encodeComponent(note);
    return "upi://pay?pa=$vpa&pn=$n&am=$amount&cu=INR&tn=$t";
  }

  Future<void> _payNow() async {
    if (latestInvoice == null || userData == null) return;
    final inv = latestInvoice!.data()!;
    final amount = inv["amount"].toString();
    final note = "Maintenance-${inv["month"]}-${userData!["house_no"]}";

    final uri = Uri.parse(_upiLink(vpa: upiVpa, name: upiName, amount: amount, note: note));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No UPI app found")));
    }
  }

  Future<void> _submitPayment() async {
    if (user == null || latestInvoice == null || userData == null) return;

    final utr = utrCtrl.text.trim();
    final amt = num.tryParse(amountCtrl.text.trim());

    if (utr.isEmpty || amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter valid UTR + amount")));
      return;
    }

    final inv = latestInvoice!.data()!;
    final invoiceDocId = latestInvoice!.id; // ✅ your invoiceId = docId (INV_84_2026_02)

    await FirebaseFirestore.instance.collection("payments").add({
      "uid": user!.uid,
      "house_no": userData!["house_no"],
      "invoice_id": invoiceDocId,
      "month": inv["month"],
      "amount": amt,
      "method": "UPI",
      "utr": utr,
      "status": "SUBMITTED",
      "paid_at": Timestamp.now(),
      "created_at": FieldValue.serverTimestamp(),
      "verified_at": null,
      "verified_by": null,
      "admin_note": "",
    });

    utrCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submitted for admin verification")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (latestInvoice == null) {
      return const Scaffold(body: Center(child: Text("No invoice generated yet")));
    }

    final inv = latestInvoice!.data()!;
    final upiPayload = _upiLink(
      vpa: upiVpa,
      name: upiName,
      amount: inv["amount"].toString(),
      note: "Maintenance-${inv["month"]}-${userData?["house_no"]}",
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Pay Maintenance")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: Text("Invoice: ${inv["month"]}"),
                subtitle: Text("Amount: ₹${inv["amount"]} | Status: ${inv["status"]}"),
              ),
            ),
            const SizedBox(height: 16),
            QrImageView(data: upiPayload, size: 200),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _payNow, child: const Text("Pay via UPI App")),
            const SizedBox(height: 24),

            TextField(
              controller: utrCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "UTR / Transaction ID"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Amount Paid"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _submitPayment, child: const Text("Submit for Verification")),

            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("My Submissions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("payments")
                  .where("uid", isEqualTo: user!.uid)
                  .orderBy("created_at", descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const Text("No submissions yet.");

                return Column(
                  children: docs.map((d) {
                    final p = d.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text("₹${p["amount"]} • ${p["status"]}"),
                        subtitle: Text("UTR: ${p["utr"]}\nInvoice: ${p["invoice_id"]}"),
                      ),
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
}

