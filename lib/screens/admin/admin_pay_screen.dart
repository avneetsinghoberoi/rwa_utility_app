import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rms_app/config/app_config.dart';
import 'package:rms_app/theme/app_theme.dart';

class AdminPayScreen extends StatefulWidget {
  const AdminPayScreen({super.key});

  @override
  State<AdminPayScreen> createState() => _AdminPayScreenState();
}

class _AdminPayScreenState extends State<AdminPayScreen> {
  static final String _verifyPaymentHttpUrl =
      AppConfig.functionsUrl('verifyPaymentManualHttp');
  static final String _rejectPaymentHttpUrl =
      AppConfig.functionsUrl('rejectPaymentManualHttp');
  static final String _generateInvoicesHttpUrl =
      AppConfig.functionsUrl('generateInvoicesManualHttp');

  // Track which payment card is loading so we can show per-card spinners
  String? _loadingPaymentId;
  bool _generatingDues = false;

  // ── Current month helpers ────────────────────────────────────────
  String get _currentMonthKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String get _currentMonthLabel =>
      DateFormat('MMMM yyyy').format(DateTime.now());

  // ── Verify via Cloud Function ─────────────────────────────────────
  Future<void> _verify(String paymentId) async {
    setState(() => _loadingPaymentId = paymentId);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('🔑 Calling verifyPaymentManual as uid=${currentUser?.uid}, email=${currentUser?.email}');
      final authToken = await currentUser?.getIdToken(true);
      final response = await http.post(
        Uri.parse(_verifyPaymentHttpUrl),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'paymentDocId': paymentId,
          if (authToken != null) 'authToken': authToken,
        }),
      );

      final responseBody = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = responseBody['error'];
        final status = error is Map<String, dynamic>
            ? (error['status'] ?? 'HTTP_${response.statusCode}')
            : 'HTTP_${response.statusCode}';
        final message = error is Map<String, dynamic>
            ? (error['message'] ?? 'Unknown error')
            : 'Unknown error';
        throw Exception('$status: $message');
      }

      debugPrint('✅ verifyPaymentManualHttp success: $responseBody');

      if (!mounted) return;
      _showSnack('Payment verified ✅  Invoice & receipt updated.',
          isSuccess: true);
    } catch (e) {
      debugPrint('❌ verifyPaymentManualHttp failed: $e');
      if (!mounted) return;
      _showSnack('Verify failed: $e');
    } finally {
      if (mounted) setState(() => _loadingPaymentId = null);
    }
  }

  // ── Reject via Cloud Function (requires a reason) ─────────────────
  Future<void> _reject(BuildContext context, String paymentId) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Reject Payment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason. The resident will see this.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: AppTheme.inputDecoration(
                  'Rejection reason', Icons.notes_rounded),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          SizedBox(
            width: 100,
            child: OutlinedButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Reject'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) return;

    setState(() => _loadingPaymentId = paymentId);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final authToken = await user?.getIdToken(true);
      debugPrint('🔑 Calling rejectPaymentManualHttp as uid=${user?.uid}');
      final response = await http.post(
        Uri.parse(_rejectPaymentHttpUrl),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'paymentDocId': paymentId,
          'reason': reason,
        }),
      );

      final responseBody = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = responseBody['error'];
        final msg = error is Map<String, dynamic>
            ? (error['message'] ?? error['status'] ?? 'Unknown error')
            : 'Unknown error';
        throw Exception(msg);
      }

      debugPrint('✅ rejectPaymentManualHttp success');
      if (!mounted) return;
      _showSnack('Payment rejected.');
    } catch (e) {
      debugPrint('❌ rejectPaymentManualHttp failed: $e');
      if (!mounted) return;
      _showSnack('Reject failed: $e');
    } finally {
      if (mounted) setState(() => _loadingPaymentId = null);
    }
  }

  // ── Generate invoices for current month ────────────────────────────
  Future<void> _generateDues() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Generate Monthly Dues',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'This will create a ₹1,500 invoice for every resident for '
          '$_currentMonthLabel.\n\n'
          'The system does this automatically on the 1st of each month. '
          'Only proceed if the automatic run was missed.',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          SizedBox(
            width: 120,
            child: AppTheme.gradientButton(
              label: 'Generate',
              onTap: () => Navigator.pop(ctx, true),
              height: 40,
              icon: Icons.add_task_rounded,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _generatingDues = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final authToken = await user?.getIdToken(true);
      debugPrint('🔑 Calling generateInvoicesManualHttp as uid=${user?.uid}');
      final response = await http.post(
        Uri.parse(_generateInvoicesHttpUrl),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'month': _currentMonthKey}),
      );

      final responseBody = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = responseBody['error'];
        final msg = error is Map<String, dynamic>
            ? (error['message'] ?? error['status'] ?? 'Unknown error')
            : 'Unknown error';
        throw Exception(msg);
      }

      debugPrint('✅ generateInvoicesManualHttp success: $responseBody');
      final data = (responseBody['result'] ?? responseBody) as Map<String, dynamic>;

      if (!mounted) return;
      if (data['skipped'] == true) {
        _showSnack('Dues for $_currentMonthLabel already exist.',
            isSuccess: false);
      } else {
        _showSnack(
            'Generated ${data['created']} invoices for $_currentMonthLabel ✅',
            isSuccess: true);
      }
    } catch (e) {
      debugPrint('❌ generateInvoicesManualHttp failed: $e');
      if (!mounted) return;
      _showSnack('Failed: $e');
    } finally {
      if (mounted) setState(() => _generatingDues = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payments',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          // Manual "Generate dues" button
          _generatingDues
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.add_task_rounded),
                  tooltip: 'Generate $_currentMonthLabel dues',
                  onPressed: _generateDues,
                ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payments')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return _emptyState();
          }

          final pending = docs.where((d) {
            final s = (d.data() as Map<String, dynamic>)['status'] ?? '';
            return s == 'SUBMITTED' || s == 'PENDING';
          }).toList();

          final processed = docs.where((d) {
            final s = (d.data() as Map<String, dynamic>)['status'] ?? '';
            return s == 'VERIFIED' || s == 'REJECTED';
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Monthly invoice overview ──────────────────────
              _buildMonthlyOverview(),
              const SizedBox(height: 20),

              // ── Summary chips ─────────────────────────────────
              Row(
                children: [
                  _summaryChip('${pending.length} Pending',
                      AppColors.warning, AppColors.warningLight,
                      Icons.hourglass_empty_rounded),
                  const SizedBox(width: 10),
                  _summaryChip('${processed.length} Processed',
                      AppColors.success, AppColors.successLight,
                      Icons.check_circle_rounded),
                ],
              ),
              const SizedBox(height: 20),

              // ── Pending payments ──────────────────────────────
              if (pending.isNotEmpty) ...[
                _sectionHeader('Pending Verification', AppColors.warning),
                const SizedBox(height: 10),
                ...pending.map((d) =>
                    _paymentCard(context, d, isPending: true)),
                const SizedBox(height: 20),
              ],

              // ── Processed payments ────────────────────────────
              if (processed.isNotEmpty) ...[
                _sectionHeader('Processed', AppColors.textSecondary),
                const SizedBox(height: 10),
                ...processed.map((d) =>
                    _paymentCard(context, d, isPending: false)),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Monthly invoice overview card ───────────────────────────────────
  Widget _buildMonthlyOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invoices')
          .where('month', isEqualTo: _currentMonthKey)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No invoices generated for $_currentMonthLabel yet. '
                    'Tap ⊕ in the top-right to generate them.',
                    style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        }

        int unpaid = 0, submitted = 0, paid = 0;
        for (final d in docs) {
          final s = (d.data() as Map<String, dynamic>)['status'] ?? '';
          if (s == 'UNPAID') unpaid++;
          else if (s == 'SUBMITTED') submitted++;
          else if (s == 'PAID') paid++;
        }
        final total = docs.length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.primaryShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '$_currentMonthLabel — Invoice Overview',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _overviewTile('$total', 'Total', Colors.white),
                  _overviewDivider(),
                  _overviewTile('$paid', 'Paid',
                      Colors.greenAccent.shade200),
                  _overviewDivider(),
                  _overviewTile('$submitted', 'Review',
                      Colors.amberAccent.shade200),
                  _overviewDivider(),
                  _overviewTile('$unpaid', 'Unpaid',
                      Colors.redAccent.shade200),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? paid / total : 0,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.greenAccent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$paid of $total residents have paid',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _overviewTile(String count, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(count,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _overviewDivider() => Container(
        width: 1,
        height: 36,
        color: Colors.white.withOpacity(0.25),
      );

  // ── Payment Card ──────────────────────────────────────────────────
  Widget _paymentCard(BuildContext context, QueryDocumentSnapshot d,
      {required bool isPending}) {
    final m = d.data() as Map<String, dynamic>;
    final status = (m['status'] ?? 'PENDING').toString();
    final name = (m['userName'] ?? 'User').toString();
    final flat = (m['house_no'] ?? '').toString();
    final amt = (m['amount'] ?? 0).toString();
    final txn = (m['utr'] ?? '-').toString();
    final methodStr = (m['method'] ?? '-').toString();
    final proofUrl = (m['proof_url'] ?? '').toString();
    final note = (m['note'] ?? '').toString().trim();
    final purpose = (m['purpose'] ?? '').toString().trim();
    final invoiceType = (m['invoice_type'] ?? 'MAINTENANCE').toString();
    final statusColor = _statusColor(status);
    final isThisLoading = _loadingPaymentId == d.id;
    final isDemand = invoiceType == 'DEMAND';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name + (flat.isNotEmpty ? '  •  Flat $flat' : ''),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        '₹$amt  •  $methodStr',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                AppTheme.statusChip(status, statusColor),
              ],
            ),

            // ── Purpose / invoice type badge ────────────────────
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDemand ? const Color(0xFFF3E8FF) : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDemand ? Icons.request_quote_rounded : Icons.receipt_long_rounded,
                        size: 13,
                        color: isDemand ? const Color(0xFF8B5CF6) : AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isDemand
                            ? (purpose.isNotEmpty ? purpose : 'Demand Due')
                            : 'Monthly Maintenance',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDemand ? const Color(0xFF8B5CF6) : AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Transaction info ────────────────────────────────
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('UTR / Txn ID: $txn',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),

            // ── Note ────────────────────────────────────────────
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(note,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ],

            // ── Proof image ─────────────────────────────────────
            if (proofUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(proofUrl,
                    height: 180,
                    fit: BoxFit.cover,
                    width: double.infinity),
              ),
            ],

            // ── Action buttons ───────────────────────────────────
            if (isPending) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              isThisLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: AppTheme.gradientButton(
                            label: 'Verify',
                            onTap: () => _verify(d.id),
                            height: 44,
                            icon: Icons.check_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _reject(context, d.id),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                  color: AppColors.error.withOpacity(0.5)),
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    status == 'VERIFIED'
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == 'VERIFIED'
                        ? 'Verified — invoice & receipt updated'
                        : 'Rejected',
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status) {
      case 'VERIFIED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Widget _summaryChip(String label, Color color, Color bg, IconData icon) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 64, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text('No payment requests yet.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _generateDues,
            icon: const Icon(Icons.add_task_rounded),
            label: Text('Generate $_currentMonthLabel Dues'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
