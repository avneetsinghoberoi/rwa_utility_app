import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rms_app/screens/login/login_screen.dart';

class AdminIssuesScreen extends StatefulWidget {
  const AdminIssuesScreen({super.key});

  @override
  State<AdminIssuesScreen> createState() => _AdminIssuesScreenState();
}

class _AdminIssuesScreenState extends State<AdminIssuesScreen> {
  static const _base = 'https://us-central1-rms-app-3d585.cloudfunctions.net';
  final complaintsRef = FirebaseFirestore.instance.collection("complaints");

  /// Call the Cloud Function to update a complaint's status.
  /// Returns true on success, false on failure.
  Future<bool> _callUpdateStatus(
    String docId,
    String newStatus, {
    String adminFeedback = '',
  }) async {
    try {
      final user  = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';

      final response = await http.post(
        Uri.parse('$_base/updateComplaintStatusHttp'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'complaintId':   docId,
          'status':        newStatus,
          'adminFeedback': adminFeedback,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['ok'] == true) return true;

      final msg = (data['error']?['message'] ?? 'Unknown error').toString();
      debugPrint('[updateComplaintStatus] error: $msg');
      return false;
    } catch (e) {
      debugPrint('[updateComplaintStatus] exception: $e');
      return false;
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return "-";
    final dt = ts.toDate();
    return DateFormat("dd MMM yyyy").format(dt);
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == "open") return Colors.red;
    if (s == "in progress" || s == "progress") return Colors.blue;
    if (s == "resolved" || s == "done" || s == "closed") return Colors.green;
    return Colors.grey;
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    final ok = await _callUpdateStatus(docId, newStatus);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to update status"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resolveComplaintDialog(String docId) async {
    final feedbackController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Resolve Complaint", style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: feedbackController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: "Closing Message / Feedback",
              hintText: "Example: Issue resolved. Electrician visited and fixed wiring.",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check),
              label: const Text("Mark Resolved"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final feedback = feedbackController.text.trim();

    final success = await _callUpdateStatus(
      docId,
      "Resolved",
      adminFeedback: feedback,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      success
          ? const SnackBar(
              content: Text("Complaint resolved ✅ — resident notified!"),
              backgroundColor: Colors.green,
            )
          : const SnackBar(
              content: Text("Failed to resolve complaint"),
              backgroundColor: Colors.red,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text("Admin Complaints", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: complaintsRef.orderBy("createdAt", descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No complaints found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = (data["title"] ?? "").toString();
              final desc = (data["description"] ?? "").toString();
              final category = (data["category"] ?? "General").toString();
              final status = (data["status"] ?? "Open").toString();
              final userName = (data["userName"] ?? "Unknown").toString();
              final userPhone = (data["userPhone"] ?? "-").toString();
              final createdAt = data["createdAt"] as Timestamp?;

              final feedback = (data["adminFeedback"] ?? "").toString();

              final color = _statusColor(status);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Title + status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Chip(
                          label: Text(status),
                          backgroundColor: color.withOpacity(0.12),
                          labelStyle: TextStyle(color: color),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(desc, style: const TextStyle(color: Colors.black87)),
                    const SizedBox(height: 8),

                    Text("Category: $category", style: const TextStyle(color: Colors.grey)),
                    Text("Date: ${_formatDate(createdAt)}", style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),

                    const Divider(),

                    Text("Resident: $userName", style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text("Contact: $userPhone", style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),

                    if (feedback.isNotEmpty) ...[
                      Text("Admin Feedback:", style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(feedback, style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 10),
                    ],

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status.toLowerCase() != "resolved") ...[
                          TextButton(
                            onPressed: () => _updateStatus(doc.id, "In Progress"),
                            child: const Text("Mark In Progress"),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _resolveComplaintDialog(doc.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Resolve"),
                          ),
                        ] else
                          const Text(
                            "Closed",
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          )
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

