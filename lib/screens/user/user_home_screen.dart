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
                  // ── All pending dues ─────────────────────────
                  AppTheme.sectionHeader('Your Dues', emoji: '💳'),
                  const SizedBox(height: 12),
                  _buildAllDuesSection(context),
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

  // ── All Dues Section ─────────────────────────────────────────────
  Widget _buildAllDuesSection(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final firestoreDocId =
        (widget.userData['firestoreDocId'] as String?)?.isNotEmpty == true
            ? widget.userData['firestoreDocId'] as String
            : currentUser.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invoices')
          .where('uid', isEqualTo: firestoreDocId)
          .where('status', whereIn: ['UNPAID', 'PARTIAL', 'SUBMITTED'])
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _shimmerCard();
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('All clear! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('No pending dues for House ${widget.userData['house_no'] ?? ''}',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Sort: UNPAID first, then PARTIAL, then SUBMITTED; within each group by due_date ascending
        final sorted = [...docs];
        const order = {'UNPAID': 0, 'PARTIAL': 1, 'SUBMITTED': 2};
        sorted.sort((a, b) {
          final am = a.data() as Map<String, dynamic>;
          final bm = b.data() as Map<String, dynamic>;
          final aOrder = order[am['status']] ?? 3;
          final bOrder = order[bm['status']] ?? 3;
          if (aOrder != bOrder) return aOrder.compareTo(bOrder);
          final aDate = am['due_date'] is Timestamp ? (am['due_date'] as Timestamp).millisecondsSinceEpoch : 0;
          final bDate = bm['due_date'] is Timestamp ? (bm['due_date'] as Timestamp).millisecondsSinceEpoch : 0;
          return aDate.compareTo(bDate);
        });

        return Column(
          children: sorted.map((doc) => _dueCard(context, doc)).toList(),
        );
      },
    );
  }

  Widget _dueCard(BuildContext context, QueryDocumentSnapshot doc) {
    final inv       = doc.data() as Map<String, dynamic>;
    final status    = inv['status']?.toString() ?? 'UNPAID';
    final type      = inv['type']?.toString() ?? 'MAINTENANCE';
    final title     = inv['title']?.toString() ?? (type == 'DEMAND' ? 'Special Due' : 'Monthly Maintenance');
    final desc      = inv['description']?.toString() ?? '';
    final amount    = (inv['amount'] as num?)?.toInt() ?? 1500;
    final paidAmt   = (inv['paid_amount'] as num?)?.toInt() ?? 0;
    final remaining = (amount - paidAmt).clamp(0, amount);
    final rawDate   = inv['due_date'];
    final dueDate   = rawDate is Timestamp ? rawDate.toDate() : null;
    final month     = inv['month']?.toString() ?? '';
    final isDemand  = type == 'DEMAND';
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && status != 'SUBMITTED';

    // Colors
    final Color accentColor;
    final List<Color> gradColors;
    if (status == 'SUBMITTED') {
      accentColor = AppColors.warning;
      gradColors  = [const Color(0xFFD97706), const Color(0xFFF59E0B)];
    } else if (isOverdue) {
      accentColor = AppColors.error;
      gradColors  = [const Color(0xFFDC2626), const Color(0xFFEF4444)];
    } else if (isDemand) {
      accentColor = const Color(0xFF8B5CF6);
      gradColors  = [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)];
    } else {
      accentColor = AppColors.primary;
      gradColors  = [const Color(0xFF1A56DB), const Color(0xFF3B82F6)];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: accentColor.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isDemand ? Icons.request_quote_rounded : Icons.home_outlined, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(isDemand ? 'Special Due' : 'Monthly Maintenance', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (status == 'SUBMITTED') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Under Review', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
              if (isOverdue && status != 'SUBMITTED') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                  child: const Text('OVERDUE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
          ],
          if (!isDemand && month.isNotEmpty)
            Text(DateFormat('MMMM yyyy').format(DateTime.parse('$month-01')),
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${NumberFormat('#,##0').format(remaining)}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1),
                    ),
                    if (paidAmt > 0)
                      Text('of ₹${NumberFormat('#,##0').format(amount)}  •  ₹${NumberFormat('#,##0').format(paidAmt)} paid',
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11)),
                    if (dueDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${isOverdue ? 'Was due' : 'Due by'} ${DateFormat('dd MMM yyyy').format(dueDate)}',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              if (status != 'SUBMITTED')
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserPayScreen(
                        invoiceId: doc.id,
                        prefilledAmount: remaining,
                        monthLabel: isDemand ? title : (month.isNotEmpty ? DateFormat('MMMM yyyy').format(DateTime.parse('$month-01')) : ''),
                        invoiceTitle: title,
                        invoiceDescription: desc,
                        invoiceType: type,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: accentColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: Text(
                    status == 'PARTIAL' ? 'Pay Rest' : 'Pay Now',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmerCard() {
    return Container(
      height: 120,
      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(20)),
      child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
    );
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
