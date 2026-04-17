import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rms_app/theme/app_theme.dart';
import 'receipt_pdf_service.dart';

class UserPayScreen extends StatefulWidget {
  /// When opened from the dashboard due card, these are pre-populated.
  final String? invoiceId;       // Firestore invoices/{id}
  final int? prefilledAmount;    // remaining amount to pay
  final String? monthLabel;      // e.g. "April 2026"

  const UserPayScreen({
    super.key,
    this.invoiceId,
    this.prefilledAmount,
    this.monthLabel,
  });

  @override
  State<UserPayScreen> createState() => _UserPayScreenState();
}

class _UserPayScreenState extends State<UserPayScreen> {
  final user = FirebaseAuth.instance.currentUser;

  bool loading = true;
  Map<String, dynamic> userData = {};

  late final TextEditingController amountCtrl;
  final txnCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  String method = 'UPI';

  File? proofImage;
  bool uploadingProof = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with invoice amount if coming from a specific due,
    // otherwise default to 1500.
    amountCtrl = TextEditingController(
      text: (widget.prefilledAmount ?? 1500).toString(),
    );
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      userData = snap.data() ?? {};
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (x == null) return;
    setState(() => proofImage = File(x.path));
  }

  Future<String?> _uploadProofIfAny(String paymentDocId) async {
    if (proofImage == null || user == null) return null;

    setState(() => uploadingProof = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('proofs')
          .child(user!.uid)
          .child('$paymentDocId.jpg');

      await ref.putFile(proofImage!);
      return await ref.getDownloadURL();
    } finally {
      if (mounted) setState(() => uploadingProof = false);
    }
  }

  Future<void> _submitPayment() async {
    if (user == null) return;

    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _showSnack('Enter valid amount', isError: true);
      return;
    }

    final utr = txnCtrl.text.trim();
    if (utr.length < 6) {
      _showSnack('Enter valid UTR (min 6 characters)', isError: true);
      return;
    }

    final houseNo = (userData['house_no'] ?? '').toString();

    try {
      final payRef =
          await FirebaseFirestore.instance.collection('payments').add({
        'uid': user!.uid,
        'amount': amount,
        'utr': utr,
        'status': 'SUBMITTED',
        'created_at': FieldValue.serverTimestamp(),
        'house_no': houseNo,
        'method': method,
        'note': noteCtrl.text.trim(),
        // Links this payment to the specific monthly invoice (null if ad-hoc)
        if (widget.invoiceId != null) 'invoice_id': widget.invoiceId,
      });

      final proofUrl = await _uploadProofIfAny(payRef.id);
      if (proofUrl != null) {
        await payRef.update({'proof_url': proofUrl});
      }

      setState(() => proofImage = null);
      txnCtrl.clear();
      noteCtrl.clear();

      _showSnack('Payment submitted ✅ Waiting for admin verification.');
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    txnCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name =
        (userData['name'] ?? userData['username'] ?? 'User').toString();
    final flat =
        (userData['house'] ?? userData['house_noNo'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pay Maintenance',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Invoice context banner (when opened from a due card) ─
          if (widget.invoiceId != null) ...[
            Container(
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
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Maintenance — ${widget.monthLabel ?? ''}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${widget.prefilledAmount ?? 1500} due  •  $name',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── User info banner (when opened standalone) ──────────
          if (widget.invoiceId == null) ...[
            Container(
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
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      if (flat.isNotEmpty)
                        Text('Flat: $flat',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Payment form ──────────────────────────────────────
          _sectionTitle('Payment Details'),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration,
            child: Column(
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  // Lock the field when coming from a specific invoice
                  readOnly: widget.invoiceId != null,
                  decoration: AppTheme.inputDecoration(
                    'Amount (₹)',
                    Icons.currency_rupee_rounded,
                  ).copyWith(
                    suffixIcon: widget.invoiceId != null
                        ? const Tooltip(
                            message: 'Amount set by monthly due',
                            child: Icon(Icons.lock_outline_rounded,
                                size: 18, color: AppColors.textSecondary),
                          )
                        : null,
                    fillColor: widget.invoiceId != null
                        ? AppColors.divider
                        : AppColors.primaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(
                        value: 'BANK_TRANSFER',
                        child: Text('Bank Transfer')),
                  ],
                  onChanged: (v) => setState(() => method = v ?? 'UPI'),
                  decoration: AppTheme.inputDecoration(
                      'Payment Method', Icons.payment_rounded),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: txnCtrl,
                  decoration: AppTheme.inputDecoration(
                      'Transaction ID / UTR', Icons.tag_rounded),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: AppTheme.inputDecoration(
                      'Note (optional)', Icons.note_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Screenshot proof ─────────────────────────────────
          _sectionTitle('Proof of Payment'),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: uploadingProof ? null : _pickProof,
            icon: const Icon(Icons.image_outlined),
            label: Text(proofImage == null
                ? 'Attach Payment Screenshot (optional)'
                : 'Change Screenshot'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),

          if (proofImage != null) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(proofImage!,
                      height: 180, fit: BoxFit.cover, width: double.infinity),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: uploadingProof
                        ? null
                        : () => setState(() => proofImage = null),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── Submit button ─────────────────────────────────────
          AppTheme.gradientButton(
            label: uploadingProof
                ? 'Uploading...'
                : 'Submit for Verification',
            onTap: uploadingProof ? null : _submitPayment,
            height: 52,
            icon: Icons.send_rounded,
          ),

          const SizedBox(height: 28),

          // ── Payment history ──────────────────────────────────
          _sectionTitle('My Payments'),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .where('uid', isEqualTo: user?.uid)
                .orderBy('created_at', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return _emptyState('No payments yet.');
              }

              return Container(
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: docs.asMap().entries.map((entry) {
                    final i = entry.key;
                    final m = entry.value.data() as Map<String, dynamic>;
                    final status =
                        (m['status'] ?? 'PENDING').toString();
                    final statusColor = _payStatusColor(status);

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
                                  color:
                                      statusColor.withOpacity(0.12),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  status == 'VERIFIED'
                                      ? Icons.check_rounded
                                      : status == 'REJECTED'
                                          ? Icons.close_rounded
                                          : Icons.hourglass_empty_rounded,
                                  color: statusColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '₹${m["amount"] ?? 0}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      '${m["method"] ?? "-"}  •  Txn: ${m["utr"] ?? "-"}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              AppTheme.statusChip(status, statusColor),
                            ],
                          ),
                        ),
                        if (i < docs.length - 1)
                          const Divider(
                              height: 1, color: AppColors.divider),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Receipts ─────────────────────────────────────────
          _sectionTitle('My Receipts'),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('receipts')
                .where('uid', isEqualTo: user?.uid)
                .orderBy('created_at', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return _emptyState(
                    'No receipts yet. (Admin must verify payment)');
              }

              return Container(
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: docs.asMap().entries.map((entry) {
                    final i = entry.key;
                    final r = entry.value.data() as Map<String, dynamic>;

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
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_rounded,
                                    color: AppColors.success, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '₹${r["amount"] ?? 0}  •  ${r["status"] ?? "VERIFIED"}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      'Txn: ${r["utr"] ?? "-"}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf_rounded,
                                    color: AppColors.error),
                                onPressed: () async {
                                  final file =
                                      await ReceiptPdfService
                                          .generateReceiptPdf(
                                    receiptId: entry.value.id,
                                    r: r,
                                  );
                                  await ReceiptPdfService.openPdf(file);
                                },
                              ),
                            ],
                          ),
                        ),
                        if (i < docs.length - 1)
                          const Divider(
                              height: 1, color: AppColors.divider),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Color _payStatusColor(String status) {
    switch (status) {
      case 'VERIFIED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _emptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textHint, size: 20),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
