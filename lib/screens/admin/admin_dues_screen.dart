import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rms_app/config/app_config.dart';
import 'package:rms_app/theme/app_theme.dart';

import 'create_demand_due_screen.dart';

class AdminDuesScreen extends StatelessWidget {
  const AdminDuesScreen({super.key});

  static final String _base = AppConfig.baseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Demand Dues', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateDemandDueScreen()),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Due'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // No orderBy here — sorts client-side to avoid needing a Firestore index
        stream: FirebaseFirestore.instance
            .collection('demand_dues')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Surface any Firestore errors instead of silently showing empty state
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text('Failed to load dues', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(snap.error.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return _emptyState(context);
          }

          // Sort client-side: newest first
          final docs = [...snap.data!.docs];
          docs.sort((a, b) {
            final aTs = (a.data() as Map)['created_at'];
            final bTs = (b.data() as Map)['created_at'];
            if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
            return 0;
          });

          final active = docs.where((d) => (d.data() as Map)['status'] == 'ACTIVE').toList();
          final closed = docs.where((d) => (d.data() as Map)['status'] == 'CLOSED').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                _sectionHeader('Active', AppColors.success),
                const SizedBox(height: 10),
                ...active.map((d) => _DemandDueCard(doc: d, base: _base)),
                const SizedBox(height: 20),
              ],
              if (closed.isNotEmpty) ...[
                _sectionHeader('Closed', AppColors.textSecondary),
                const SizedBox(height: 10),
                ...closed.map((d) => _DemandDueCard(doc: d, base: _base)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.request_quote_outlined, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No demand dues yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Create one to charge residents\nfor special work or expenses', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          AppTheme.gradientButton(
            label: 'Create First Due',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDemandDueScreen())),
            height: 48,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }
}

// ── Individual demand due card ────────────────────────────────────────────────
class _DemandDueCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String base;

  const _DemandDueCard({required this.doc, required this.base});

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Repair':      return const Color(0xFFEF4444);
      case 'Renovation':  return const Color(0xFF8B5CF6);
      case 'Event':       return const Color(0xFFF59E0B);
      case 'Utility':     return const Color(0xFF06B6D4);
      default:            return AppColors.primary;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Repair':      return Icons.build_rounded;
      case 'Renovation':  return Icons.home_repair_service_rounded;
      case 'Event':       return Icons.celebration_rounded;
      case 'Utility':     return Icons.bolt_rounded;
      default:            return Icons.handyman_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m       = doc.data() as Map<String, dynamic>;
    final title   = m['title']?.toString() ?? '-';
    final desc    = m['description']?.toString() ?? '';
    final cat     = m['category']?.toString() ?? 'Other';
    final amount  = (m['amount_per_unit'] as num?)?.toInt() ?? 0;
    final count   = (m['invoices_created'] as num?)?.toInt() ?? 0;
    final status  = m['status']?.toString() ?? 'ACTIVE';
    final rawDate = m['due_date'];
    final dueDate = rawDate is Timestamp ? rawDate.toDate() : null;
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && status == 'ACTIVE';
    final catColor = _categoryColor(cat);
    final total   = amount * count;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_categoryIcon(cat), color: catColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      if (desc.isNotEmpty)
                        Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(status),
              ],
            ),
          ),

          // ── Stats row ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _statTile('₹${NumberFormat('#,##0').format(amount)}', 'Per Flat', catColor),
                    _divider(),
                    _statTile('$count', 'Flats', AppColors.textSecondary),
                    _divider(),
                    _statTile('₹${NumberFormat('#,##0').format(total)}', 'Total', AppColors.textPrimary),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today_rounded,
                      size: 14,
                      color: isOverdue ? AppColors.error : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dueDate != null
                          ? (isOverdue ? 'Overdue — ' : 'Due by ') + DateFormat('dd MMM yyyy').format(dueDate)
                          : 'No due date',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue ? AppColors.error : AppColors.textSecondary,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    // Live invoice payment status
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('invoices')
                          .where('demand_id', isEqualTo: doc.id)
                          .snapshots(),
                      builder: (ctx, invSnap) {
                        if (!invSnap.hasData) return const SizedBox.shrink();
                        final invDocs = invSnap.data!.docs;
                        final paid = invDocs.where((d) => (d.data() as Map)['status'] == 'PAID').length;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$paid/${invDocs.length} paid',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (status == 'ACTIVE') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDetailSheet(context),
                          icon: const Icon(Icons.list_alt_rounded, size: 16),
                          label: const Text('View Details'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _confirmClose(context),
                        icon: const Icon(Icons.lock_outline_rounded, size: 16),
                        label: const Text('Close'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'ACTIVE' ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _statTile(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: AppColors.border);

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DemandDueDetailSheet(demandId: doc.id, title: (doc.data() as Map)['title']?.toString() ?? ''),
    );
  }

  Future<void> _confirmClose(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Close Demand Due', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('No more payments will be accepted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Close Due'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final user  = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(true);
      await http.post(
        Uri.parse('$base/closeDemandDueHttp'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'demandId': doc.id}),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Demand due closed.'),
          backgroundColor: AppColors.textSecondary,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// ── Detail bottom sheet: per-resident invoice status ─────────────────────────
class _DemandDueDetailSheet extends StatelessWidget {
  final String demandId;
  final String title;
  const _DemandDueDetailSheet({required this.demandId, required this.title});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.list_alt_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // No orderBy — sorts client-side to avoid composite index requirement
                stream: FirebaseFirestore.instance
                    .collection('invoices')
                    .where('demand_id', isEqualTo: demandId)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.hasError) return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.error)));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  // Sort by house_no client-side
                  final docs = [...snap.data!.docs]
                    ..sort((a, b) {
                      final ha = (a.data() as Map)['house_no']?.toString() ?? '';
                      final hb = (b.data() as Map)['house_no']?.toString() ?? '';
                      return ha.compareTo(hb);
                    });
                  if (docs.isEmpty) return const Center(child: Text('No invoices found.'));

                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (ctx, i) {
                      final inv = docs[i].data() as Map<String, dynamic>;
                      final status    = inv['status']?.toString() ?? 'UNPAID';
                      final name      = inv['name']?.toString() ?? '-';
                      final house     = inv['house_no']?.toString() ?? '-';
                      final amount    = (inv['amount'] as num?)?.toInt() ?? 0;
                      final paid      = (inv['paid_amount'] as num?)?.toInt() ?? 0;
                      final remaining = amount - paid;

                      Color statusColor;
                      switch (status) {
                        case 'PAID':      statusColor = AppColors.success; break;
                        case 'PARTIAL':   statusColor = AppColors.warning; break;
                        case 'SUBMITTED': statusColor = AppColors.primary; break;
                        default:          statusColor = AppColors.error;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Text(house, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(
                                    status == 'PAID' ? 'Fully paid ₹$amount' : 'Remaining ₹$remaining of ₹$amount',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            AppTheme.statusChip(status, statusColor),
                          ],
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
