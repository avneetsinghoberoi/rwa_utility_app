import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:rms_app/screens/login/login_screen.dart';
import 'package:rms_app/theme/app_theme.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  static const _base = 'https://us-central1-rms-app-3d585.cloudfunctions.net';

  bool _deleting = false;

  String _monthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // ── Create resident via Cloud Function ─────────────────────────────────────
  Future<void> _createResident(Map<String, String> data) async {
    final user  = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken(true);

    final response = await http.post(
      Uri.parse('$_base/createResidentHttp'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name':     data['name'],
        'email':    data['email'],
        'phone':    data['phone'],
        'houseNo':  data['houseNo'],
        'password': data['password'],
      }),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final err = (json['error'] as Map<String, dynamic>?) ?? {};
      throw Exception(err['message'] ?? 'Failed to create resident');
    }

    // Show credentials dialog
    if (mounted) {
      await _showCredentialsDialog(
        name:     data['name']!,
        email:    data['email']!,
        password: data['password']!,
        houseNo:  data['houseNo']!,
      );
    }
  }

  // ── Delete resident via Cloud Function ─────────────────────────────────────
  Future<void> _deleteResident(String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Resident', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "$name"?\n\n'
          'This will permanently remove their account and login access. '
          'Their payment history will remain.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final user  = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(true);

      final response = await http.post(
        Uri.parse('$_base/deleteResidentHttp'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': userId}),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final err = (json['error'] as Map<String, dynamic>?) ?? {};
        throw Exception(err['message'] ?? 'Failed to delete resident');
      }

      if (mounted) _showSnack('✅ $name has been removed', success: true);
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  // ── Open Add Member dialog ─────────────────────────────────────────────────
  void _openAddMemberDialog() async {
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const AddMemberDialog(),
    );
    if (data == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _createResident(data);
      if (mounted) Navigator.pop(context); // close loader
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        _showSnack('Error: $e');
      }
    }
  }

  // ── Credentials dialog (shown after successful creation) ───────────────────
  Future<void> _showCredentialsDialog({
    required String name,
    required String email,
    required String password,
    required String houseNo,
  }) async {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Resident Created!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share these login credentials with the resident:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _credRow(Icons.person_outline_rounded, 'Name', name),
            _credRow(Icons.home_outlined, 'Flat / Unit', houseNo),
            _credRow(Icons.email_outlined, 'Email (login ID)', email),
            _credRow(Icons.lock_outline_rounded, 'Password', password),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: 'Login credentials for $name (Flat $houseNo)\nEmail: $email\nPassword: $password',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Credentials copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Credentials'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _credRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Status chip ────────────────────────────────────────────────────────────
  Widget _statusChip(String? status) {
    Color bg; Color fg; String label;
    switch (status) {
      case 'PAID':    bg = const Color(0xFFD1FAE5); fg = const Color(0xFF065F46); label = 'Paid';    break;
      case 'PARTIAL': bg = const Color(0xFFFEF3C7); fg = const Color(0xFF92400E); label = 'Partial'; break;
      case 'SUBMITTED': bg = const Color(0xFFE0E7FF); fg = const Color(0xFF3730A3); label = 'Review'; break;
      case 'UNPAID':  bg = const Color(0xFFFFE4E6); fg = const Color(0xFF9F1239); label = 'Unpaid';  break;
      default:        bg = const Color(0xFFF1F5F9); fg = const Color(0xFF64748B); label = 'No Bill'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .where('role', isEqualTo: 'user')
                                .snapshots(),
                            builder: (_, snap) {
                              final count = snap.data?.docs.length ?? 0;
                              return Text(
                                '$count Residents',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              );
                            },
                          ),
                          const Text('Manage resident accounts', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openAddMemberDialog,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add Resident'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // ── Member list ─────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('invoices')
                      .where('month', isEqualTo: _monthKey())
                      .snapshots(),
                  builder: (_, invoiceSnap) {
                    // Build uid → invoice status map for this month
                    final Map<String, String> statusMap = {};
                    if (invoiceSnap.hasData) {
                      for (final doc in invoiceSnap.data!.docs) {
                        final d = doc.data() as Map<String, dynamic>;
                        final uid = d['uid'] as String? ?? '';
                        if (uid.isNotEmpty) statusMap[uid] = d['status'] as String? ?? 'UNPAID';
                      }
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'user')
                          .orderBy('created_at', descending: true)
                          .snapshots(),
                      builder: (_, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textHint),
                                const SizedBox(height: 12),
                                const Text('No residents yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                const Text('Tap "Add Resident" to onboard your first member', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final doc  = docs[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final name    = data['name']?.toString() ?? '—';
                            final email   = data['email']?.toString() ?? '—';
                            final phone   = data['phone']?.toString() ?? '—';
                            final houseNo = data['house_no']?.toString() ?? '—';
                            final invStatus = statusMap[doc.id];

                            return Container(
                              decoration: AppTheme.cardDecoration,
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        houseNo,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text(email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        if (phone.isNotEmpty && phone != '—') ...[
                                          const SizedBox(height: 1),
                                          Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                                        ],
                                        const SizedBox(height: 6),
                                        _statusChip(invStatus),
                                      ],
                                    ),
                                  ),

                                  // Delete button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
                                    tooltip: 'Remove resident',
                                    onPressed: _deleting ? null : () => _deleteResident(doc.id, name),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // Full-screen loading overlay during delete
          if (_deleting)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Member Dialog
// ─────────────────────────────────────────────────────────────────────────────
class AddMemberDialog extends StatefulWidget {
  const AddMemberDialog({super.key});

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _houseCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  bool _showPassword = false;

  void _generatePassword() {
    final house = _houseCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    final suffix = (100 + Random().nextInt(900)).toString(); // 3-digit random
    final generated = house.isNotEmpty ? 'Home${house}@$suffix' : 'Home@$suffix';
    setState(() => _passCtrl.text = generated);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _houseCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.all(20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Add New Resident', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A Firebase account will be created. Share the email and password with the resident so they can log in.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),

                // House / Unit number
                TextFormField(
                  controller: _houseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Flat / Unit Number *',
                    prefixIcon: Icon(Icons.home_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Unit number is required' : null,
                ),
                const SizedBox(height: 12),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Phone
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                          tooltip: _showPassword ? 'Hide' : 'Show',
                        ),
                        IconButton(
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 20, color: AppColors.primary),
                          onPressed: _generatePassword,
                          tooltip: 'Auto-generate',
                        ),
                      ],
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Password is required';
                    if (v.trim().length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _generatePassword,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                    label: const Text('Auto-generate password', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name':     _nameCtrl.text.trim(),
                'email':    _emailCtrl.text.trim(),
                'phone':    _phoneCtrl.text.trim(),
                'houseNo':  _houseCtrl.text.trim().toUpperCase(),
                'password': _passCtrl.text.trim(),
              });
            }
          },
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: const Text('Create Account'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
