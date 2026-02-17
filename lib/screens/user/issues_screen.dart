import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  final _complaintsRef = FirebaseFirestore.instance.collection('complaints');

  // --- Add Complaint Dialog ---
  Future<void> _openAddComplaintDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = "General";

    final categories = const [
      "General",
      "Electricity",
      "Plumbing",
      "Security",
      "Cleanliness",
      "Lift",
      "Parking",
      "Other",
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Raise a Complaint", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: "Title"),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: "Category"),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => category = v ?? "General",
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: "Description"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.send),
              label: const Text("Submit"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            )
          ],
        );
      },
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter title and description.")),
      );
      return;
    }

    try {
      // ✅ Fetch user info (name + phone) from users collection by email
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: currentUser.email)
          .limit(1)
          .get();

      String userName = "Unknown";
      String userPhone = "";

      if (userSnap.docs.isNotEmpty) {
        final data = userSnap.docs.first.data();
        userName = (data['name'] ?? "Unknown").toString();
        userPhone = (data['phone'] ?? "").toString();
      }

      await _complaintsRef.add({
        "uid": currentUser.uid,
        "userEmail": currentUser.email,
        "userName": userName,
        "userPhone": userPhone,
        "title": title,
        "description": desc,
        "category": category,
        "status": "Open", // default
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complaint submitted ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting complaint: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please login again.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Resident Portal")),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddComplaintDialog,
        child: const Icon(Icons.add),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _complaintsRef
            .where('uid', isEqualTo: currentUser.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          // ✅ status counts
          int open = 0, progress = 0, done = 0;
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final s = (data['status'] ?? 'Open').toString().toLowerCase();
            if (s == "open") open++;
            else if (s == "in progress" || s == "progress") progress++;
            else if (s == "resolved" || s == "done" || s == "closed") done++;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statusBox("Open", "$open", Colors.red),
                    _statusBox("Progress", "$progress", Colors.blue),
                    _statusBox("Done", "$done", Colors.green),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "My Complaints",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: docs.isEmpty
                      ? const Center(child: Text("No complaints yet. Tap + to add one."))
                      : ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;

                      final title = (data['title'] ?? '').toString();
                      final desc = (data['description'] ?? '').toString();
                      final category = (data['category'] ?? 'General').toString();
                      final status = (data['status'] ?? 'Open').toString();
                      final feedback = (data['adminFeedback'] ?? '').toString();
                      final color = _statusColor(status);

                      return _complaintCard(
                        title,
                        desc,
                        category,
                        status,
                        feedback,
                        color,
                      );
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == "open") return Colors.red;
    if (s == "in progress" || s == "progress") return Colors.blue;
    if (s == "resolved" || s == "done" || s == "closed") return Colors.green;
    return Colors.grey;
  }

  Widget _statusBox(String title, String count, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _complaintCard(String title, String desc, String category, String status, String feedback, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          feedback.isNotEmpty
              ? "$desc\n$category\nAdmin: $feedback"
              : "$desc\n$category",
          style: const TextStyle(color: Colors.grey),
        ),

        trailing: Chip(
          label: Text(status),
          backgroundColor: color.withOpacity(0.12),
          labelStyle: TextStyle(color: color),
        ),
      ),
    );
  }
}

