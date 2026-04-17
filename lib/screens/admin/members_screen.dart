import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rms_app/screens/login/login_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _monthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Widget _invoiceStatusChip(String? status) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'PAID':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        icon = Icons.check_circle_outline;
        label = 'Paid';
        break;
      case 'PARTIAL':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        icon = Icons.remove_circle_outline;
        label = 'Partial';
        break;
      case 'SUBMITTED':
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF3730A3);
        icon = Icons.hourglass_empty_rounded;
        label = 'Review';
        break;
      case 'UNPAID':
        bg = const Color(0xFFFFE4E6);
        fg = const Color(0xFF9F1239);
        icon = Icons.cancel_outlined;
        label = 'Unpaid';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        icon = Icons.help_outline;
        label = 'No Bill';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
  // 🔹 Add new member to Firestore
  Future<void> _addMemberToFirestore(Map<String, String> memberData) async {
    try {
      await FirebaseFirestore.instance.collection('users').add({
        'name': memberData['name'],
        'email': memberData['email'],
        'phone': memberData['phone'],
        'house_no': memberData['unit'], // using unit number as house_no
        'floor': '',
        'dues': 0,
        'maintenance_status': 'Paid',
        'role': 'user',
        'qr_payload': memberData['unit'], // optional unique payload
        'created_at': FieldValue.serverTimestamp(),
        'last_due_update': '',
        'last_payment_date': '',
        'last_payment_sate': '',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Member added successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error adding member: $e")),
      );
    }
  }

  void _openAddMemberDialog() async {
    final newMember = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const AddMemberDialog(),
    );

    if (newMember != null) {
      _addMemberToFirestore(newMember);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text("Members",
            style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Resident Members",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _openAddMemberDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add Member"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Manage and view all registered residents",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),

            // 🔹 Real-time Firestore user list with invoice status
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('invoices')
                    .where('month', isEqualTo: _monthKey())
                    .snapshots(),
                builder: (context, invoiceSnap) {
                  // Build uid → invoice status map from current month
                  final Map<String, String> invoiceStatusMap = {};
                  if (invoiceSnap.hasData) {
                    for (final doc in invoiceSnap.data!.docs) {
                      final d = doc.data() as Map<String, dynamic>;
                      final uid = d['uid'] as String? ?? '';
                      final status = d['status'] as String? ?? 'UNPAID';
                      if (uid.isNotEmpty) invoiceStatusMap[uid] = status;
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .orderBy('created_at', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No members found."));
                      }

                      final users = snapshot.data!.docs;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                                const Color(0xFFF4F6F8)),
                            columns: const [
                              DataColumn(
                                  label: Text("Full Name",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text("Unit No.",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text("Email",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text("Phone",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text("This Month",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                            ],
                            rows: users.map((doc) {
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              final invStatus =
                                  invoiceStatusMap[doc.id]; // null = no invoice
                              return DataRow(
                                cells: [
                                  DataCell(Text(data['name'] ?? '')),
                                  DataCell(Text(data['house_no'] ?? '')),
                                  DataCell(Text(data['email'] ?? '')),
                                  DataCell(Text(data['phone'] ?? '')),
                                  DataCell(_invoiceStatusChip(invStatus)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔹 Add Member Dialog
class AddMemberDialog extends StatefulWidget {
  const AddMemberDialog({super.key});

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Add New Member",
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter the details of the new resident",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter a name" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: unitController,
                decoration: const InputDecoration(
                    labelText: "Unit Number",
                    prefixIcon: Icon(Icons.home_outlined)),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter unit number" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                value == null || value.isEmpty ? "Enter email" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                    labelText: "Phone",
                    prefixIcon: Icon(Icons.phone_outlined)),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                value == null || value.isEmpty ? "Enter phone" : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                "name": nameController.text,
                "unit": unitController.text,
                "email": emailController.text,
                "phone": phoneController.text,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text("Add Member"),
        ),
      ],
    );
  }
}
