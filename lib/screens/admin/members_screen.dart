import 'package:flutter/material.dart';
import 'package:rms_app/screens/login/login_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  // Member data list
  List<Map<String, String>> members = [
    {"name": "John Doe", "unit": "A-101", "email": "john@example.com", "phone": "+91 98765 43210"},
    {"name": "Jane Smith", "unit": "A-102", "email": "jane@example.com", "phone": "+91 98123 45678"},
  ];

  void _openAddMemberDialog() async {
    final newMember = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const AddMemberDialog(),
    );

    if (newMember != null) {
      setState(() {
        members.add(newMember);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text("Admin Portal", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

            // Scrollable Data Table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor:
                    MaterialStateProperty.all(const Color(0xFFF4F6F8)),
                    columns: const [
                      DataColumn(label: Text("Full Name", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Unit No.", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Email", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Phone", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: members.map((member) {
                      return DataRow(
                        cells: [
                          DataCell(Text(member["name"] ?? "")),
                          DataCell(Text(member["unit"] ?? "")),
                          DataCell(Text(member["email"] ?? "")),
                          DataCell(Text(member["phone"] ?? "")),
                        ],
                      );
                    }).toList(),
                  ),
                ),
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
      title: const Text("Add New Member", style: TextStyle(fontWeight: FontWeight.bold)),
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
                decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline)),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter a name" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: unitController,
                decoration: const InputDecoration(labelText: "Unit Number", prefixIcon: Icon(Icons.home_outlined)),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter unit number" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                value == null || value.isEmpty ? "Enter email" : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone", prefixIcon: Icon(Icons.phone_outlined)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text("Add Member"),
        ),
      ],
    );
  }
}

