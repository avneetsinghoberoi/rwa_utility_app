import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:gate_basic/config/app_config.dart';
import 'package:gate_basic/screens/admin/report_pdf_service.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'package:gate_basic/utils/admin_dashboard_key.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  static final String _base = AppConfig.baseUrl;

  bool _deleting = false;
  bool _generatingReport = false;

  // ── Search + filter state ──────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _showOwners = true; // true = Owners tab, false = Others tab

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _monthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // ── Create resident via Cloud Function ─────────────────────────────────────
  Future<void> _createResident(Map<String, String> data) async {
    final adminUser = FirebaseAuth.instance.currentUser;
    final token = await adminUser?.getIdToken(true);

    final response = await http.post(
      Uri.parse('$_base/createResidentHttp'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': data['name'],
        'email': data['email'],
        'phone': data['phone'],
        'houseNo': data['houseNo'],
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final err = (body['error'] as Map<String, dynamic>?) ?? {};
      throw Exception(err['message'] ?? 'Failed to create resident');
    }

    final tempPassword = body['tempPassword']?.toString() ?? '';
    final emailSent = body['emailSent'] == true;

    if (mounted) {
      await _showCreatedDialog(
        name: data['name']!,
        email: data['email']!,
        houseNo: data['houseNo']!,
        tempPassword: tempPassword,
        emailSent: emailSent,
      );
    }
  }

  // ── Delete resident via Cloud Function ─────────────────────────────────────
  Future<void> _deleteResident(String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Resident',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
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
      final societyName =
          adminDoc.data()?['societyName']?.toString() ?? 'RWA Society';

      final entries = await ReportPdfService.fetchMonthData(selected);
      final file = await ReportPdfService.generateReport(
        monthKey: selected,
        societyName: societyName,
        entries: entries,
      );

      if (!mounted) return;

      // Offer Open or Share
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Report Ready',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Resident Added!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
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
                          icon: const Icon(Icons.copy_rounded,
                              size: 18, color: AppColors.primary),
                          tooltip: 'Copy password',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: tempPassword));
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
                  color: emailSent
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      emailSent
                          ? Icons.mark_email_read_outlined
                          : Icons.warning_amber_rounded,
                      color: emailSent
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
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
                          color: emailSent
                              ? const Color(0xFF065F46)
                              : const Color(0xFF92400E),
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
                      const SnackBar(
                          content: Text('Credentials copied — ready to share')),
                    );
                  },
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Copy All to Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
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

  // ── Toggle tab button ──────────────────────────────────────────────────────
  Widget _toggleTab(String label, IconData icon,
      {required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status chip ────────────────────────────────────────────────────────────
  Widget _statusChip(String? status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'PAID':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = 'Paid';
        break;
      case 'PARTIAL':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'Partial';
        break;
      case 'SUBMITTED':
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF3730A3);
        label = 'Review';
        break;
      case 'UNPAID':
        bg = const Color(0xFFFFE4E6);
        fg = const Color(0xFF9F1239);
        label = 'Unpaid';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'No Bill';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Members',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            )),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () =>
                    adminDashboardScaffoldKey.currentState?.openDrawer(),
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.border,
            height: 1,
          ),
        ),
        actions: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () =>
                  adminDashboardScaffoldKey.currentState?.openDrawer(),
            ),
          // Download report
          _generatingReport
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Download Dues Report',
                  onPressed: _openReportFlow,
                ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Header: count + add button ───────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('role',
                                whereIn: ['user', 'resident']).snapshots(),
                        builder: (_, snap) {
                          final docs = snap.data?.docs ?? [];
                          int ownerCount = 0;
                          int tenantCount = 0;
                          for (final d in docs) {
                            final data = d.data() as Map<String, dynamic>;
                            if ((data['status']?.toString() ?? 'active') ==
                                'removed') continue;
                            final link = data['account_link'] as Map?;
                            if (link == null ||
                                link['primary_owner_uid'] == null)
                              ownerCount++;
                            else
                              tenantCount++;
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ownerCount + tenantCount} Members',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                              Text(
                                '$ownerCount owners · $tenantCount tenants/family',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openAddMemberDialog,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add Resident'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search bar ───────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, house no, email or phone',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.textHint),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 18, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),

              // ── Owner / Others toggle ────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _toggleTab('Owners', Icons.home_rounded,
                          isSelected: _showOwners,
                          onTap: () => setState(() => _showOwners = true)),
                      _toggleTab('Others', Icons.people_rounded,
                          isSelected: !_showOwners,
                          onTap: () => setState(() => _showOwners = false)),
                    ],
                  ),
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
                    // Build house_no → invoice status map for this month
                    final Map<String, String> statusMap = {};
                    if (invoiceSnap.hasData) {
                      for (final doc in invoiceSnap.data!.docs) {
                        final d = doc.data() as Map<String, dynamic>;
                        final houseNo = d['house_no'] as String? ?? '';
                        if (houseNo.isNotEmpty)
                          statusMap[houseNo] =
                              d['status'] as String? ?? 'UNPAID';
                      }
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role',
                              whereIn: ['user', 'resident']).snapshots(),
                      builder: (_, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        // Filter: removed users, active toggle tab, and search query
                        final allDocs = (snap.data?.docs ?? []).where((d) {
                          final data = d.data() as Map<String, dynamic>;
                          // Exclude removed
                          if ((data['status']?.toString() ?? 'active') ==
                              'removed') return false;
                          // Apply toggle
                          final link = data['account_link'] as Map?;
                          final isOwner =
                              link == null || link['primary_owner_uid'] == null;
                          if (_showOwners && !isOwner) return false;
                          if (!_showOwners && isOwner) return false;
                          // Apply search
                          if (_searchQuery.isNotEmpty) {
                            final name =
                                (data['name'] ?? '').toString().toLowerCase();
                            final email =
                                (data['email'] ?? '').toString().toLowerCase();
                            final phone =
                                (data['phone'] ?? '').toString().toLowerCase();
                            final houseNo = (data['house_no'] ?? '')
                                .toString()
                                .toLowerCase();
                            if (!name.contains(_searchQuery) &&
                                !email.contains(_searchQuery) &&
                                !phone.contains(_searchQuery) &&
                                !houseNo.contains(_searchQuery)) return false;
                          }
                          return true;
                        }).toList()
                          ..sort((a, b) {
                            final da = a.data() as Map<String, dynamic>;
                            final db = b.data() as Map<String, dynamic>;
                            final hA = (da['house_no'] ?? '').toString();
                            final hB = (db['house_no'] ?? '').toString();
                            final cmp = hA.compareTo(hB);
                            if (cmp != 0) return cmp;
                            // Same house: owner before tenant
                            final aIsOwner = (da['account_link']
                                    as Map?)?['primary_owner_uid'] ==
                                null;
                            final bIsOwner = (db['account_link']
                                    as Map?)?['primary_owner_uid'] ==
                                null;
                            if (aIsOwner && !bIsOwner) return -1;
                            if (!aIsOwner && bIsOwner) return 1;
                            return 0;
                          });

                        if (allDocs.isEmpty) {
                          final isSearch = _searchQuery.isNotEmpty;
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSearch
                                      ? Icons.search_off_rounded
                                      : Icons.people_outline_rounded,
                                  size: 64,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isSearch
                                      ? 'No results for "$_searchQuery"'
                                      : (_showOwners
                                          ? 'No owners yet'
                                          : 'No tenants / family members yet'),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isSearch
                                      ? 'Try a different name, house no. or email'
                                      : (_showOwners
                                          ? 'Tap "Add Resident" to onboard your first member'
                                          : 'Owners can add family/tenants from their Members screen'),
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.textHint),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: allDocs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final doc = allDocs[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['name']?.toString() ?? '—';
                            final email = data['email']?.toString() ?? '—';
                            final phone = data['phone']?.toString() ?? '—';
                            final houseNo = data['house_no']?.toString() ?? '—';
                            final vehicleNo =
                                (data['vehicle_no'] ?? '').toString().trim();
                            final invStatus = statusMap[houseNo];

                            // Role badge
                            final link = data['account_link'] as Map?;
                            final isOwner = link == null ||
                                link['primary_owner_uid'] == null;
                            final linkedAs =
                                link?['linked_as']?.toString() ?? 'tenant';
                            final roleLabel = isOwner
                                ? 'Owner'
                                : '${linkedAs[0].toUpperCase()}${linkedAs.substring(1)}';
                            final roleColor = isOwner
                                ? const Color(0xFF059669)
                                : const Color(0xFF7C3AED);

                            return Container(
                              decoration: AppTheme.cardDecoration,
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  // Avatar / house-no tile
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: isOwner
                                          ? AppColors.primaryLight
                                          : const Color(0xFFEDE9FE),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        houseNo,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isOwner
                                              ? AppColors.primary
                                              : const Color(0xFF7C3AED),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Name + role badge on the same row
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(name,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors
                                                          .textPrimary)),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color:
                                                    roleColor.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                roleLabel,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: roleColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(email,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                        if (phone.isNotEmpty &&
                                            phone != '—') ...[
                                          const SizedBox(height: 1),
                                          Text(phone,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textHint)),
                                        ],
                                        const SizedBox(height: 6),
                                        // Show payment status for owners; for tenants show "Shared flat"
                                        isOwner
                                            ? _statusChip(invStatus)
                                            : Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF3F4F6),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Text('Shared flat',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors
                                                            .textSecondary,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                              ),
                                        // Vehicle number (if set)
                                        if (vehicleNo.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                  Icons.directions_car_rounded,
                                                  size: 12,
                                                  color: Color(0xFFF59E0B)),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFEF3C7),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                  border: Border.all(
                                                      color: const Color(
                                                              0xFFF59E0B)
                                                          .withOpacity(0.4)),
                                                ),
                                                child: Text(
                                                  vehicleNo,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.0,
                                                    color: Color(0xFF92400E),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Delete button
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.error,
                                        size: 22),
                                    tooltip: 'Remove member',
                                    onPressed: _deleting
                                        ? null
                                        : () => _deleteResident(doc.id, name),
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
                      _generatingReport
                          ? 'Generating report…'
                          : 'Removing resident…',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
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
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.border),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCurrentMonth
                      ? AppColors.primaryLight
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color:
                      isCurrentMonth ? AppColors.primary : AppColors.textHint,
                  size: 20,
                ),
              ),
              title: Text(label,
                  style: TextStyle(
                    fontWeight:
                        isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                    color: isCurrentMonth
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontSize: 14,
                  )),
              trailing: isCurrentMonth
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Current',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    )
                  : const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textHint),
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
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
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
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person_add_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Add New Resident',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A login account will be created and a password setup email will be sent to the resident automatically.',
                          style:
                              TextStyle(color: AppColors.primary, fontSize: 12),
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),

                // House / Unit number
                TextFormField(
                  controller: _houseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Flat / Unit Number *',
                    prefixIcon: Icon(Icons.home_outlined),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Unit number is required'
                      : null,
                ),
                const SizedBox(height: 12),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Email is required';
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                'name': _nameCtrl.text.trim(),
                'email': _emailCtrl.text.trim(),
                'phone': _phoneCtrl.text.trim(),
                'houseNo': _houseCtrl.text.trim().toUpperCase(),
              });
            }
          },
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: const Text('Create & Send Email'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
