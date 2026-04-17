import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rms_app/theme/app_theme.dart';

import 'pay_screen.dart';
import 'issues_screen.dart';
import 'notices_screen.dart';
import 'expense_screen.dart';
import 'qrpass_screen.dart';

class UserHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const UserHomeScreen({super.key, required this.userData});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  // ── Quick-access items ──────────────────────────────────────────
  late final List<_QuickItem> _quickItems = [
    _QuickItem(
      icon: Icons.payment_rounded,
      label: 'Pay',
      color: AppColors.primary,
      screen: const UserPayScreen(),
    ),
    _QuickItem(
      icon: Icons.report_problem_rounded,
      label: 'Issue',
      color: AppColors.error,
      screen: const IssuesScreen(),
    ),
    _QuickItem(
      icon: Icons.campaign_rounded,
      label: 'Notices',
      color: const Color(0xFF8B5CF6),
      screen: const NoticesScreen(),
    ),
    _QuickItem(
      icon: Icons.qr_code_rounded,
      label: 'QR Pass',
      color: AppColors.success,
      screen: UserProfileScreen(),
    ),
    _QuickItem(
      icon: Icons.receipt_long_rounded,
      label: 'Expenses',
      color: AppColors.warning,
      screen: const ExpenseScreen(),
    ),
  ];

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final name = (widget.userData['name'] ?? 'Resident').toString();
    final houseNo = (widget.userData['house_no'] ?? '-').toString();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Gradient header ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 170,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
                child: Stack(
                  children: [
                    // Decorative circle
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // User info
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting! 👋',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.home_outlined,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'House No. $houseNo',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              titlePadding:
                  const EdgeInsets.only(left: 16, bottom: 14),
            ),
          ),

          // ── Body content ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Maintenance card ─────────────────────────
                  _buildMaintenanceCard(context, houseNo),
                  const SizedBox(height: 22),

                  // ── Quick access ──────────────────────────────
                  AppTheme.sectionHeader('Quick Access'),
                  const SizedBox(height: 12),
                  _buildQuickAccessGrid(context),
                  const SizedBox(height: 22),

                  // ── Latest notice ─────────────────────────────
                  AppTheme.sectionHeader('Latest Notice', emoji: '📢'),
                  const SizedBox(height: 12),
                  _buildLatestNotice(context),
                  const SizedBox(height: 22),

                  // ── Recent payments ──────────────────────────
                  AppTheme.sectionHeader('Recent Payments', emoji: '📈'),
                  const SizedBox(height: 12),
                  _buildRecentPayments(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Maintenance Card (live from Firestore invoices) ─────────────
  Widget _buildMaintenanceCard(BuildContext context, String houseNo) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final month =
        '${now.year}-${now.month.toString().padLeft(2, '0')}'; // e.g. "2026-04"

    // Use the Firestore document ID (not Firebase Auth UID) because invoices
    // are created with uid = userDoc.id (Firestore doc ID), which may differ
    // from the Firebase Auth UID for users created manually by an admin.
    final firestoreDocId =
        (widget.userData['firestoreDocId'] as String?)?.isNotEmpty == true
            ? widget.userData['firestoreDocId'] as String
            : currentUser.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invoices')
          .where('uid', isEqualTo: firestoreDocId)
          .where('month', isEqualTo: month)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        // ── Loading ──────────────────────────────────────────────
        if (snap.connectionState == ConnectionState.waiting) {
          return _maintenanceShimmer();
        }

        // ── No invoice yet (admin hasn't generated this month's dues) ─
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _maintenanceInfoCard(
            icon: Icons.hourglass_empty_rounded,
            iconColor: AppColors.textSecondary,
            bgGradient: const LinearGradient(
              colors: [Color(0xFF64748B), Color(0xFF94A3B8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            title: 'No dues for this month',
            subtitle: 'House No: $houseNo',
            action: null,
          );
        }

        final doc = snap.data!.docs.first;
        final inv = doc.data() as Map<String, dynamic>;
        final status = (inv['status'] ?? 'UNPAID').toString();
        final totalAmt = (inv['amount'] ?? 1500) as num;
        final paidAmt = (inv['paid_amount'] ?? 0) as num;
        final remaining = (totalAmt - paidAmt).clamp(0, totalAmt);
        final invoiceId = doc.id;

        // ── PAID ─────────────────────────────────────────────────
        if (status == 'PAID') {
          return _maintenanceInfoCard(
            icon: Icons.check_circle_rounded,
            iconColor: Colors.white,
            bgGradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            title: 'All paid for this month! 🎉',
            subtitle: '₹${NumberFormat('#,##0').format(totalAmt)} cleared  •  House No: $houseNo',
            action: null,
          );
        }

        // ── SUBMITTED (under review) ──────────────────────────────
        if (status == 'SUBMITTED') {
          return _maintenanceInfoCard(
            icon: Icons.pending_actions_rounded,
            iconColor: Colors.white,
            bgGradient: const LinearGradient(
              colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            title: 'Payment under review',
            subtitle: '₹${NumberFormat('#,##0').format(remaining)} pending admin verification',
            action: null,
          );
        }

        // ── UNPAID or PARTIAL ─────────────────────────────────────
        final isPartial = status == 'PARTIAL';
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.primaryShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPartial ? 'Partial Payment Remaining' : 'Maintenance Due',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85), fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${NumberFormat('#,##0').format(remaining)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.home_outlined,
                            color: Colors.white.withOpacity(0.7), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'House No: $houseNo',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12),
                        ),
                        if (isPartial) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(of ₹${NumberFormat('#,##0').format(totalAmt)})',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserPayScreen(
                      invoiceId: invoiceId,
                      prefilledAmount: remaining.toInt(),
                      monthLabel: _monthLabel(now),
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
                child: Text(
                  isPartial ? 'Pay Rest' : 'Pay Now',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Info variant (paid / submitted / no-due) ────────────────────
  Widget _maintenanceInfoCard({
    required IconData icon,
    required Color iconColor,
    required LinearGradient bgGradient,
    required String title,
    required String subtitle,
    required Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  // ── Skeleton shimmer while loading ──────────────────────────────
  Widget _maintenanceShimmer() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  String _monthLabel(DateTime d) {
    return DateFormat('MMMM yyyy').format(d);
  }

  // ── Quick Access Grid ───────────────────────────────────────────
  Widget _buildQuickAccessGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: _quickItems.length,
      itemBuilder: (context, index) {
        final item = _quickItems[index];
        return GestureDetector(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => item.screen)),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: item.color.withOpacity(0.25), width: 1),
                ),
                child: Icon(item.icon, color: item.color, size: 26),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Latest Notice ────────────────────────────────────────────────
  Widget _buildLatestNotice(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('notices')
          .orderBy('date', descending: true)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyCard('No notices posted yet.');
        }

        final notice =
            snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final type = (notice['type'] ?? 'General').toString();

        Color typeColor;
        IconData typeIcon;
        switch (type) {
          case 'Urgent':
            typeColor = AppColors.error;
            typeIcon = Icons.warning_amber_rounded;
            break;
          case 'Event':
            typeColor = AppColors.primary;
            typeIcon = Icons.event_rounded;
            break;
          case 'Maintenance':
            typeColor = AppColors.success;
            typeIcon = Icons.build_circle_outlined;
            break;
          default:
            typeColor = AppColors.textSecondary;
            typeIcon = Icons.info_outline;
        }

        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NoticesScreen())),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (notice['title'] ?? '').toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (notice['description'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Recent Payments ──────────────────────────────────────────────
  Widget _buildRecentPayments() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('house_no', isEqualTo: widget.userData['house_no'])
          .orderBy('timestamp', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyCard('No payments yet.');
        }

        final docs = snapshot.data!.docs;
        return Container(
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: docs.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['timestamp'];
              final date = ts is Timestamp ? ts.toDate() : DateTime.now();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: AppColors.success, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Paid ₹${data['amount_paid'] ?? '-'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.textPrimary),
                              ),
                              Text(
                                DateFormat.yMMMd().format(date),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        AppTheme.statusChip('Paid', AppColors.success),
                      ],
                    ),
                  ),
                  if (index < docs.length - 1)
                    const Divider(height: 1, color: AppColors.divider),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Empty state placeholder ──────────────────────────────────────
  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.textHint, size: 20),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Quick Item Data Class ────────────────────────────────────────────
class _QuickItem {
  final IconData icon;
  final String label;
  final Color color;
  final Widget screen;

  const _QuickItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.screen});
}
