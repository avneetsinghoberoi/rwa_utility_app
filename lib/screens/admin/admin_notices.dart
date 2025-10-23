import 'package:flutter/material.dart';
import 'package:rms_app/screens/login/login_screen.dart';

class AdminNoticesScreen extends StatefulWidget {
  const AdminNoticesScreen({super.key});

  @override
  State<AdminNoticesScreen> createState() => _AdminNoticesScreenState();
}

class _AdminNoticesScreenState extends State<AdminNoticesScreen> {
  final List<Map<String, dynamic>> notices = [
    {
      "title": "Diwali Festival Celebration",
      "description":
      "Join us for Diwali celebrations on October 31st at the community hall. Cultural programs and dinner will be organized.",
      "type": "Event",
      "icon": Icons.notifications_active_outlined,
      "color": Colors.blue,
      "postedBy": "Admin",
      "date": "22/10/2025",
      "id": "ANN001",
    },
    {
      "title": "Water Supply Disruption",
      "description":
      "Please note water supply will be disrupted tomorrow between 9 AM to 1 PM due to maintenance.",
      "type": "Urgent",
      "icon": Icons.error_outline,
      "color": Colors.red,
      "postedBy": "Admin",
      "date": "21/10/2025",
      "id": "ANN002",
    },
    {
      "title": "Monthly Meeting Notice",
      "description":
      "The monthly residents' meeting will be held on October 28th at 6 PM in the community hall. All residents are requested to attend.",
      "type": "General",
      "icon": Icons.info_outline,
      "color": Colors.grey,
      "postedBy": "Admin",
      "date": "20/10/2025",
      "id": "ANN003",
    },
    {
      "title": "Lift Maintenance Completed",
      "description":
      "The annual maintenance of all lifts has been completed successfully. All lifts are now operational.",
      "type": "Maintenance",
      "icon": Icons.check_circle_outline,
      "color": Colors.green,
      "postedBy": "Admin",
      "date": "18/10/2025",
      "id": "ANN004",
    },
  ];

  void _openNewAnnouncementDialog() async {
    final newAnnouncement = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const NewAnnouncementDialog(),
    );

    if (newAnnouncement != null) {
      setState(() {
        notices.insert(0, newAnnouncement);
      });
    }
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryCard("General", "2", "General notices", Icons.info_outline,
                  Colors.grey),
              const SizedBox(height: 12),
              _summaryCard("Urgent", "1", "Important alerts",
                  Icons.warning_amber_rounded, Colors.red),
              const SizedBox(height: 12),
              _summaryCard("Events", "1", "Community events",
                  Icons.notifications_none, Colors.blue),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 10),

              // Header Row (fixed width-safe)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    fit: FlexFit.loose,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Announcements",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Post and manage community announcements",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: ElevatedButton.icon(
                      onPressed: _openNewAnnouncementDialog,
                      icon: const Icon(Icons.add),
                      label: const Text("New Announcement"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notices List (scroll-safe)
              ListView.builder(
                itemCount: notices.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) =>
                    _noticeCard(notices[index]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String count, String subtitle,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 3, spreadRadius: 1)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(count,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          Icon(icon, size: 26, color: color),
        ],
      ),
    );
  }

  Widget _noticeCard(Map<String, dynamic> n) {
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(n["icon"], color: n["color"], size: 22),
                  const SizedBox(width: 6),
                  Text(n["title"],
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.3)),
                ],
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: n["color"].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  n["type"],
                  style: TextStyle(
                      color: n["color"],
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(n["description"],
              style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 10),

          Row(
            children: [
              Text("Posted by ${n["postedBy"]}",
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              const Text("•"),
              const SizedBox(width: 6),
              Text(n["date"], style: const TextStyle(color: Colors.black54)),
              const Spacer(),
              Text("ID: ${n["id"]}",
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------- ADD ANNOUNCEMENT DIALOG --------------------

class NewAnnouncementDialog extends StatefulWidget {
  const NewAnnouncementDialog({super.key});

  @override
  State<NewAnnouncementDialog> createState() => _NewAnnouncementDialogState();
}

class _NewAnnouncementDialogState extends State<NewAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  String? selectedType;
  final List<String> types = ["General", "Urgent", "Event", "Maintenance"];

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
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded))
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
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => selectedType = v),
                validator: (v) => v == null ? "Select a type" : null,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.upload),
                  label: const Text("Post Announcement"),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final newNotice = {
                        "title": titleController.text,
                        "description": descController.text,
                        "type": selectedType ?? "General",
                        "icon": Icons.campaign_outlined,
                        "color": Colors.blue,
                        "postedBy": "Admin",
                        "date":
                        "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                        "id":
                        "ANN${DateTime.now().millisecondsSinceEpoch % 10000}",
                      };
                      Navigator.pop(context, newNotice);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


