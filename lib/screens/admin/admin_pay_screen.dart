import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminPayScreen extends StatefulWidget {
  const AdminPayScreen({super.key});

  @override
  State<AdminPayScreen> createState() => _AdminPayScreenState();
}

class _AdminPayScreenState extends State<AdminPayScreen> {
  // ✅ Change region if you deployed functions elsewhere
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: "us-central1");

  // ✅ Change collection name if yours is different
  final CollectionReference<Map<String, dynamic>> _paymentsRef =
  FirebaseFirestore.instance.collection("payments");

  String _formatMoney(dynamic v) {
    final n = (v is num) ? v : num.tryParse(v?.toString() ?? "0") ?? 0;
    return "₹${n.toStringAsFixed(0)}";
  }

  DateTime? _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  Future<void> _verifyPayment({
    required String paymentDocId,
  }) async {
    try {
      final callable = _functions.httpsCallable("verifyPayment");
      await callable.call({"paymentDocId": paymentDocId});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Payment verified successfully")),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Verify failed: ${e.message ?? e.code}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Verify failed: $e")),
      );
    }
  }

  Future<void> _rejectPayment({
    required String paymentDocId,
    required String reason,
  }) async {
    try {
      final callable = _functions.httpsCallable("rejectPayment");
      await callable.call({"paymentDocId": paymentDocId, "reason": reason});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Payment rejected")),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Reject failed: ${e.message ?? e.code}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Reject failed: $e")),
      );
    }
  }

  Future<void> _confirmVerify(String paymentDocId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Verify payment?"),
        content: const Text(
          "This will mark the payment as VERIFIED (and should update dues/invoice via Cloud Function).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Verify"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _verifyPayment(paymentDocId: paymentDocId);
    }
  }

  Future<void> _confirmReject(String paymentDocId) async {
    final controller = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject payment"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Reason (required)",
            hintText: "e.g., Transaction proof not clear",
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              Navigator.pop(ctx, reason.isEmpty ? null : reason);
            },
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      await _rejectPayment(paymentDocId: paymentDocId, reason: result.trim());
    } else if (result == null) {
      // cancelled
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❗ Please enter a rejection reason")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ If your status field differs, change this filter:
    final query = _paymentsRef
        .where("status", isEqualTo: "PENDING")
        .orderBy("created_at", descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin • Payment Verification"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text("❌ Error: ${snap.error}"),
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text("No pending payments ✅"),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();

              final uid = (data["uid"] ?? "").toString();
              final houseNo = (data["house_no"] ?? data["houseNo"] ?? "-").toString();
              final month = (data["month"] ?? "-").toString();
              final amount = data["amount"];
              final txnId = (data["txnId"] ?? data["transaction_id"] ?? "-").toString();
              final createdAt = _toDate(data["created_at"]);
              final proofUrl = (data["proofUrl"] ?? data["proof_url"] ?? "").toString();

              return Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "House: $houseNo  •  ${_formatMoney(amount)}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              "PENDING",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Text("Month: $month"),
                      const SizedBox(height: 4),
                      Text("UID: ${uid.isEmpty ? "-" : uid}"),
                      const SizedBox(height: 4),
                      Text("Txn ID: $txnId"),
                      if (createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text("Created: ${createdAt.toLocal()}"),
                      ],

                      if (proofUrl.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () {
                            // If you want, we can open URL using url_launcher
                          },
                          child: Text(
                            "Proof: $proofUrl",
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _confirmReject(doc.id),
                              child: const Text("Reject"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _confirmVerify(doc.id),
                              child: const Text("Verify"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}




