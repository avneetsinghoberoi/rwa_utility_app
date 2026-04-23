import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:rms_app/config/app_config.dart';
import 'package:rms_app/screens/admin/report_pdf_service.dart';
import 'package:rms_app/screens/login/login_screen.dart';
import 'package:rms_app/theme/app_theme.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  static final String _base = AppConfig.baseUrl;

  bool _deleting = false;
  bool _generatingReport = false;

  String _monthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // ── Create resident via Cloud Function ─────────────────────────────────────
  Future<void> _createResident(Map<String, String> data) async {
    final adminUser = FirebaseAuth.instance.currentUser;
    final token     = await adminUser?.getIdToken(true);

    final response = await http.post(
      Uri.parse('$_base/createResidentHttp'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name':    data['name'],
        'email':   data['email'],
        'phone':   data['phone'],
        'houseNo': data['houseNo'],
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final err = (body['error'] as Map<String, dynamic>?) ?? {};
      throw Exception(err['message'] ?? 'Failed to create resident');
    }

    final tempPassword = body['tempPassword']?.toString() ?? '';
    final emailSent    = body['emailSent'] == true;

    if (mounted) {
      await _showCreatedDialog(
        name:         data['name']!,
        email:        data['email']!,
        houseNo:      data['houseNo']!,
        tempPassword: tempPassword,
        emailSent:    emailSent,
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

  // ── Report: month picker + PDF generation ─────────────────────────────────
  Future<void> _openReportFlow() async {
    // Build last 13 months (current + 12 past)
    final now = DateTime.now();
    final months = List.generate(13, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _MonthPickerDialog(months: months),
    );
    if (selected == null || !mounted) return;

    setState(() => _generatingReport = true);
    try {
      // Fetch society name from admin's Firestore record
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();
      final societyName = adminDoc.data()?['societyName']?.toString() ?? 'RWA Society';

      final entries = await ReportPdfService.fetchMonthData(selected);
      final file    = await ReportPdfService.generateReport(
        monthKey:    selected,
        societyName: societyName,
        entries:     entries,
      );

      if (!mounted) return;

      // Offer Open or Share
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Report Ready', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Dues report for ${DateFormat('MMMM yyyy').format(DateTime.parse('$selected-01'))} '
            'has been generated with ${entries.length} residents.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await ReportPdfService.sharePdf(
                  file,
                  selected.replaceAll('-', '_'),
                );
              },
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await OpenFilex.open(file.path);
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _showSnack('Failed to generate report: $e');
    } finally {
      if (mounted) setState(() => _generatingReport = false);
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

  // ── Success dialog after resident creation ─────────────────────────────────
  Future<void> _showCreatedDialog({
    required String name,
    required String email,
    required String houseNo,
    required String tempPassword,
    required bool emailSent,
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
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Resident Added!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _credRow(Icons.person_outline_rounded, 'Name', name),
              _credRow(Icons.home_outlined, 'Flat / Unit', houseNo),
              _credRow(Icons.email_outlined, 'Login Email', email),

              const SizedBox(height: 12),

              // Temp password box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Temporary Password',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tempPassword,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                          tooltip: 'Copy password',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: tempPassword));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password copied')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Email status banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: emailSent ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      emailSent ? Icons.mark_email_read_outlined : Icons.warning_amber_rounded,
                      color: emailSent ? const Color(0xFF059669) : const Color(0xFFD97706),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        emailSent
                            ? 'Welcome email with these credentials has been sent to $email.'
                            : 'Email could not be sent. Share these credentials manually via WhatsApp or SMS.',
                        style: TextStyle(
                          fontSize: 12,
                          color: emailSent ? const Color(0xFF065F46) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Copy all button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: 'Welcome to the society app!\n'
                            'Flat: $houseNo\n'
                            'Email: $email\n'
                            'Password: $tempPassword\n'
                            'Tip: Use "Forgot Password" after login to set your own password.',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Credentials copied — ready to share')),
                    );
                  },
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Copy All to Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
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
          // Download report
          _generatingReport
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Download Dues Report',
                  onPressed: _openReportFlow,
                ),
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

          // Full-screen loading overlay during delete / report generation
          if (_deleting || _generatingReport)
            Container(
              color: Colors.black26,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      _generatingReport ? 'Generating report…' : 'Removing resident…',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _MonthPickerDialog extends StatelessWidget {
  final List<String> months;
  const _MonthPickerDialog({required this.months});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Select Month', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: months.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
          itemBuilder: (_, i) {
            final m = months[i];
            String label = m;
            try {
              label = DateFormat('MMMM yyyy').format(DateTime.parse('$m-01'));
            } catch (e) {
              debugPrint('Could not parse month label for "$m": $e');
            }
            final isCurrentMonth = i == 0;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isCurrentMonth ? AppColors.primaryLight : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: isCurrentMonth ? AppColors.primary : AppColors.textHint,
                  size: 20,
                ),
              ),
              title: Text(label, style: TextStyle(
                fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                color: isCurrentMonth ? AppColors.primary : AppColors.textPrimary,
                fontSize: 14,
              )),
              trailing: isCurrentMonth
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Current', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    )
                  : const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
              onTap: () => Navigator.pop(context, m),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
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
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _houseCtrl.dispose();
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A login account will be created and a password setup email will be sent to the resident automatically.',
                          style: TextStyle(color: AppColors.primary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
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
                'name':    _nameCtrl.text.trim(),
                'email':   _emailCtrl.text.trim(),
                'phone':   _phoneCtrl.text.trim(),
                'houseNo': _houseCtrl.text.trim().toUpperCase(),
              });
            }
          },
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: const Text('Create & Send Email'),
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
