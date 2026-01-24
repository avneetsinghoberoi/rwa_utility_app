import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rms_app/screens/login/login_screen.dart';

class AdminNoticesScreen extends StatefulWidget {
  const AdminNoticesScreen({super.key});

  @override
  State<AdminNoticesScreen> createState() => _AdminNoticesScreenState();
}

class _AdminNoticesScreenState extends State<AdminNoticesScreen> {
  // Firestore stream for live notices
  final Stream<QuerySnapshot> _noticesStream = FirebaseFirestore.instance
      .collection('notices')
      .orderBy('created_at', descending: true)
      .snapshots();

  void _openNewAnnouncementDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const NewAnnouncementDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Admin Portal",
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
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
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _noticesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text("No notices posted yet.",
                      style: TextStyle(color: Colors.grey)));
            }

            final notices = snapshot.data!.docs;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Announcements",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        onPressed: _openNewAnnouncementDialog,
                        icon: const Icon(Icons.add),
                        label: const Text("New Announcement"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // List of notices
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: notices.length,
                    itemBuilder: (context, index) {
                      final data =
                      notices[index].data() as Map<String, dynamic>;
                      return _noticeCard(data);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _noticeCard(Map<String, dynamic> n) {
    Color color;
    IconData icon;

    switch (n["type"]) {
      case "Urgent":
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
      case "Event":
        color = Colors.blue;
        icon = Icons.event;
        break;
      case "Maintenance":
        color = Colors.green;
        icon = Icons.build_circle_outlined;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 3, spreadRadius: 1)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 6),
                  Text(n["title"] ?? "",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  n["type"] ?? "",
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(n["description"] ?? "",
              style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text("Posted by ${n["posted_by"] ?? "Admin"}",
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              const Text("•"),
              const SizedBox(width: 6),
              Text(n["date"] ?? "",
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------- NEW ANNOUNCEMENT DIALOG --------------------

class NewAnnouncementDialog extends StatefulWidget {
  const NewAnnouncementDialog({super.key});

  @override
  State<NewAnnouncementDialog> createState() => _NewAnnouncementDialogState();
}

class _NewAnnouncementDialogState extends State<NewAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descController = TextEditingController();
  String? selectedType;
  final List<String> types = ["General", "Urgent", "Event", "Maintenance"];
  bool isSubmitting = false;

  Future<void> _submitNotice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    final newNotice = {
      'title': titleController.text.trim(),
      'description': descController.text.trim(),
      'type': selectedType ?? "General",
      'posted_by': "A001", // or current admin ID
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'created_at': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('notices').add(newNotice);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notice posted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error posting notice: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to post notice"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Add New Announcement",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Text("Enter details to post a new community notice",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
                validator: (v) => v!.isEmpty ? "Enter a title" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Description"),
                validator: (v) => v!.isEmpty ? "Enter a description" : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Type"),
                value: selectedType,
                items: types
                    .map((t) =>
                    DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => selectedType = v),
                validator: (v) => v == null ? "Select a type" : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.upload),
                  label: isSubmitting
                      ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                      : const Text("Post Announcement"),
                  onPressed: isSubmitting ? null : _submitNotice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



