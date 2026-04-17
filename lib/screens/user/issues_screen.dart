import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rms_app/theme/app_theme.dart';

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  final _complaintsRef = FirebaseFirestore.instance.collection('complaints');

  // ── Add Complaint Dialog (logic unchanged) ───────────────────────
  Future<void> _openAddComplaintDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = "General";

    const categories = [
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.report_problem_rounded,
                  color: AppColors.error, size: 22),
              SizedBox(width: 8),
              Text('Raise a Complaint',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration:
                      AppTheme.inputDecoration('Title', Icons.title_rounded),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: AppTheme.inputDecoration(
                      'Category', Icons.category_outlined),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => category = v ?? 'General',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: AppTheme.inputDecoration(
                      'Description', Icons.description_outlined),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            SizedBox(
              width: 110,
              child: AppTheme.gradientButton(
                label: 'Submit',
                onTap: () => Navigator.pop(context, true),
                height: 42,
                icon: Icons.send_rounded,
              ),
            ),
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
        const SnackBar(content: Text('Please enter title and description.')),
      );
      return;
    }

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: currentUser.email)
          .limit(1)
          .get();

      String userName = 'Unknown';
      String userPhone = '';

      if (userSnap.docs.isNotEmpty) {
        final data = userSnap.docs.first.data();
        userName = (data['name'] ?? 'Unknown').toString();
        userPhone = (data['phone'] ?? '').toString();
      }

      await _complaintsRef.add({
        'uid': currentUser.uid,
        'userEmail': currentUser.email,
        'userName': userName,
        'userPhone': userPhone,
        'title': title,
        'description': desc,
        'category': category,
        'status': 'Open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Complaint submitted successfully'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting complaint: $e')),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please login again.')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Complaints',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddComplaintDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Complaint',
            style: TextStyle(fontWeight: FontWeight.w600)),
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          int open = 0, progress = 0, done = 0;
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final s = (data['status'] ?? 'Open').toString().toLowerCase();
            if (s == 'open') {
              open++;
            } else if (s == 'in progress' || s == 'progress') {
              progress++;
            } else if (s == 'resolved' || s == 'done' || s == 'closed') {
              done++;
            }
          }

          return CustomScrollView(
            slivers: [
              // ── Status summary ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildStatusSummary(open, progress, done),
                ),
              ),

              // ── List header ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: AppTheme.sectionHeader('My Complaints'),
                ),
              ),

              // ── Empty state ────────────────────────────────────
              if (docs.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64, color: AppColors.textHint),
                        SizedBox(height: 12),
                        Text('No complaints yet.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Tap + to raise a new complaint.',
                            style: TextStyle(
                                color: AppColors.textHint, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                // ── Complaint cards ──────────────────────────────
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final data =
                            docs[index].data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildComplaintCard(data),
                        );
                      },
                      childCount: docs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Status Summary Row ──────────────────────────────────────────
  Widget _buildStatusSummary(int open, int progress, int done) {
    return Row(
      children: [
        _statusTile('Open', open, AppColors.error, AppColors.errorLight,
            Icons.radio_button_checked),
        const SizedBox(width: 10),
        _statusTile('In Progress', progress, AppColors.warning,
            AppColors.warningLight, Icons.autorenew_rounded),
        const SizedBox(width: 10),
        _statusTile('Resolved', done, AppColors.success, AppColors.successLight,
            Icons.check_circle_rounded),
      ],
    );
  }

  Widget _statusTile(
      String label, int count, Color color, Color bg, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Complaint Card ───────────────────────────────────────────────
  Widget _buildComplaintCard(Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString();
    final desc = (data['description'] ?? '').toString();
    final category = (data['category'] ?? 'General').toString();
    final status = (data['status'] ?? 'Open').toString();
    final feedback = (data['adminFeedback'] ?? '').toString();
    final color = _statusColor(status);

    return Container(
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AppTheme.statusChip(status, color),
              ],
            ),
            const SizedBox(height: 8),

            // ── Description ─────────────────────────────────────
            Text(desc,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 10),

            // ── Category tag ────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.label_outline,
                      size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(category,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            // ── Admin feedback ──────────────────────────────────
            if (feedback.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      feedback,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'open') return AppColors.error;
    if (s == 'in progress' || s == 'progress') return AppColors.warning;
    if (s == 'resolved' || s == 'done' || s == 'closed') return AppColors.success;
    return AppColors.textSecondary;
  }
}
