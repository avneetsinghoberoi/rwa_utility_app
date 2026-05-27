import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:gate_basic/theme/app_theme.dart';
import '../../utils/dashboard_key.dart';
import 'receipt_pdf_service.dart';

class UserPayScreen extends StatefulWidget {
  /// When opened from the dashboard due card, these are pre-populated.
  final String? invoiceId; // Firestore invoices/{id}
  final int? prefilledAmount; // remaining amount to pay
  final String? monthLabel; // e.g. "April 2026"
  final String? invoiceTitle; // e.g. "Society Painting Q2 2026"
  final String? invoiceDescription; // detail description
  final String? invoiceType; // "MAINTENANCE" | "DEMAND"

  const UserPayScreen({
    super.key,
    this.invoiceId,
    this.prefilledAmount,
    this.monthLabel,
    this.invoiceTitle,
    this.invoiceDescription,
    this.invoiceType,
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
    amountCtrl = TextEditingController(
      text: widget.prefilledAmount?.toString() ?? '',
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
    } catch (e, stackTrace) {
      debugPrint('Error loading user data: $e');
      debugPrint(stackTrace.toString());
    }
    setState(() => loading = false);
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final x =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (x == null) return;
    setState(() => proofImage = File(x.path));
  }

  /// ✅ IMPROVED: Better error handling for image uploads (works on mobile & web)
  Future<String?> _uploadProofIfAny(String paymentDocId) async {
    if (proofImage == null || user == null) return null;

    setState(() => uploadingProof = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('proofs')
          .child(user!.uid)
          .child('$paymentDocId.jpg');

      // Read file as bytes (works on all platforms: mobile & web)
      final fileBytes = await proofImage!.readAsBytes();

      // Upload with metadata and timeout
      await ref
          .putData(
        fileBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toString(),
            'uploadedBy': user!.uid,
          },
        ),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
              'Upload took too long (30s). Check internet connection.');
        },
      );

      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage error: ${e.code} - ${e.message}');
      throw Exception('Storage error: ${e.code}');
    } finally {
      if (mounted) setState(() => uploadingProof = false);
    }
  }

  /// ✅ IMPROVED: Validate image before upload
  bool _validateProofImage() {
    if (proofImage == null) return true; // optional field

    // Check file size
    final fileSize = proofImage!.lengthSync();
    if (fileSize > 10 * 1024 * 1024) {
      _showSnack('Image too large (max 10MB). Please compress and try again.',
          isError: true);
      return false;
    }

    // Check file format
    final ext = proofImage!.path.toLowerCase().split('.').last;
    if (!['jpg', 'jpeg', 'png'].contains(ext)) {
      _showSnack('Only JPG and PNG images are allowed.', isError: true);
      return false;
    }

    return true;
  }

  Future<void> _submitPayment() async {
    if (user == null) return;
    if (widget.invoiceId == null) {
      _showSnack('Select a due before making payment.', isError: true);
      return;
    }

    final invoiceSnap = await FirebaseFirestore.instance
        .collection('invoices')
        .doc(widget.invoiceId)
        .get();
    if (!invoiceSnap.exists) {
      _showSnack('This due is no longer available.', isError: true);
      return;
    }

    final invoiceData = invoiceSnap.data() ?? {};
    final invoiceStatus = invoiceData['status']?.toString() ?? 'UNPAID';
    if (invoiceStatus == 'SUBMITTED') {
      _showSnack('This due is already under review.', isError: true);
      return;
    }
    if (invoiceStatus == 'PAID') {
      _showSnack('This due is already paid.', isError: true);
      return;
    }

    final invoiceAmount = (invoiceData['amount'] as num?)?.toInt() ?? 0;
    final paidAmount = (invoiceData['paid_amount'] as num?)?.toInt() ?? 0;
    final amount = (invoiceAmount - paidAmount).clamp(0, invoiceAmount);
    amountCtrl.text = amount.toString();
    if (amount <= 0) {
      _showSnack('No balance left for this due.', isError: true);
      return;
    }

    final isCash = method == 'CASH';
    final txnValue = txnCtrl.text.trim();
    if (isCash) {
      if (txnValue.length < 2) {
        _showSnack('Enter the name of the person who received the cash.',
            isError: true);
        return;
      }
    } else if (txnValue.length < 6) {
      _showSnack('Enter valid UTR (min 6 characters)', isError: true);
      return;
    }

    // ✅ IMPROVED: Validate proof image
    if (!_validateProofImage()) {
      return;
    }

    // Resolve house_no for payment submission.
    // Priority: top-level → unit_info.flat_no (= owner's house_no for tenants) → unit_info.house_no
    final unitInfo = userData['unit_info'] as Map?;
    final houseNo = (userData['house_no'] ??
            unitInfo?['flat_no'] ??
            unitInfo?['house_no'] ??
            '')
        .toString();

    try {
      // ✅ UPLOAD PROOF FIRST (before creating payment) - Works on mobile & web
      String? proofUrl;
      if (proofImage != null) {
        setState(() => uploadingProof = true);
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('proofs')
              .child(user!.uid)
              .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

          // Read file as bytes (works on all platforms: mobile & web)
          final fileBytes = await proofImage!.readAsBytes();

          await ref
              .putData(
            fileBytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'uploadedAt': DateTime.now().toString(),
                'uploadedBy': user!.uid,
              },
            ),
          )
              .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                  'Upload timeout. Check your internet connection.');
            },
          );

          proofUrl = await ref.getDownloadURL();
          debugPrint('✅ Proof uploaded successfully: $proofUrl');
        } on TimeoutException {
          _showSnack(
              'Upload timeout. Please check your internet and try again.',
              isError: true);
          return;
        } on FirebaseException catch (e) {
          _handleStorageError(e);
          return;
        } finally {
          if (mounted) setState(() => uploadingProof = false);
        }
      }

      final invoiceType = widget.invoiceType ?? 'MAINTENANCE';
      final purpose = widget.invoiceTitle?.isNotEmpty == true
          ? widget.invoiceTitle!
          : (invoiceType == 'DEMAND' ? 'Special Due' : 'Monthly Maintenance');

      // ✅ CREATE PAYMENT WITH PROOF URL INCLUDED
      final paymentData = {
        'uid': user!.uid,
        'amount': amount,
        'utr': isCash ? 'Cash handed to $txnValue' : txnValue,
        'status': 'SUBMITTED',
        'created_at': FieldValue.serverTimestamp(),
        'house_no': houseNo,
        'method': method,
        'note': noteCtrl.text.trim(),
        if (isCash) 'cash_handed_to': txnValue,
        'invoice_type': invoiceType,
        'purpose': purpose,
        'invoice_id': widget.invoiceId,
        if (proofUrl != null) 'proof_url': proofUrl, // ← INCLUDE HERE
      };

      debugPrint('🔵 [Payment] Submitting payment data: $paymentData');
      final db = FirebaseFirestore.instance;
      final paymentRef = db.collection('payments').doc();
      final batch = db.batch();
      batch.set(paymentRef, paymentData);
      batch.update(db.collection('invoices').doc(widget.invoiceId), {
        'status': 'SUBMITTED',
        'submitted_payment_id': paymentRef.id,
        'submitted_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      debugPrint('🟢 [Payment] Payment created successfully!');

      setState(() => proofImage = null);
      txnCtrl.clear();
      noteCtrl.clear();

      _showSnack('Payment submitted ✅ Waiting for admin verification.');
    } on FirebaseException catch (e) {
      debugPrint(
          '🔴 [Payment] Firestore error - Code: ${e.code}, Message: ${e.message}');
      String errorMsg = 'Payment submission failed';
      switch (e.code) {
        case 'permission-denied':
          errorMsg =
              'You do not have permission to submit payments. Contact admin.';
          break;
        case 'invalid-argument':
          errorMsg = 'Invalid payment data. Check all fields and try again.';
          break;
        case 'unauthenticated':
          errorMsg = 'Your session expired. Please log in again.';
          break;
        default:
          errorMsg = 'Error: ${e.code}. ${e.message}';
      }
      _showSnack(errorMsg, isError: true);
    } catch (e) {
      debugPrint('🔴 [Payment] Unexpected error: $e');
      _showSnack('Failed: $e', isError: true);
    }
  }

  /// ✅ IMPROVED: Better error handling
  void _handleStorageError(FirebaseException e) {
    String errorMsg = 'Upload failed';

    switch (e.code) {
      case 'permission-denied':
        errorMsg =
            'You do not have permission to upload files. Contact administrator.';
        break;
      case 'unauthenticated':
        errorMsg = 'Please log in again to upload proof.';
        break;
      case 'canceled':
        errorMsg = 'Upload was canceled. Please try again.';
        break;
      case 'retry-limit-exceeded':
        errorMsg =
            'Upload failed after multiple retries. Check your connection.';
        break;
      default:
        errorMsg = 'Upload error: ${e.code}. ${e.message ?? ""}';
    }

    _showSnack(errorMsg, isError: true);
    debugPrint('🔴 Firebase Storage Error: ${e.code} - ${e.message}');
  }

  Widget _buildPendingDuesSection(String houseNo) {
    if (houseNo.isEmpty) {
      return _emptyState('House number not found. Contact admin.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invoices')
          .where('house_no', isEqualTo: houseNo)
          .where('status',
              whereIn: ['UNPAID', 'PARTIAL', 'SUBMITTED']).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _emptyState('Could not load dues: ${snap.error}');
        }

        final docs = [...(snap.data?.docs ?? [])];
        if (docs.isEmpty) {
          return _allClearCard(houseNo);
        }

        const order = {'UNPAID': 0, 'PARTIAL': 1, 'SUBMITTED': 2};
        docs.sort((a, b) {
          final am = a.data() as Map<String, dynamic>;
          final bm = b.data() as Map<String, dynamic>;
          final aOrder = order[am['status']] ?? 3;
          final bOrder = order[bm['status']] ?? 3;
          if (aOrder != bOrder) return aOrder.compareTo(bOrder);
          final aDate = am['due_date'] is Timestamp
              ? (am['due_date'] as Timestamp).millisecondsSinceEpoch
              : 0;
          final bDate = bm['due_date'] is Timestamp
              ? (bm['due_date'] as Timestamp).millisecondsSinceEpoch
              : 0;
          return aDate.compareTo(bDate);
        });

        return Column(
          children: docs.map((doc) => _payableDueCard(context, doc)).toList(),
        );
      },
    );
  }

  Widget _allClearCard(String houseNo) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.successGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No pending dues',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'House $houseNo is all clear.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _payableDueCard(BuildContext context, QueryDocumentSnapshot doc) {
    final inv = doc.data() as Map<String, dynamic>;
    final status = inv['status']?.toString() ?? 'UNPAID';
    final type = inv['type']?.toString() ?? 'MAINTENANCE';
    final title = inv['title']?.toString() ??
        (type == 'DEMAND' ? 'Special Due' : 'Monthly Maintenance');
    final desc = inv['description']?.toString() ?? '';
    final amount = (inv['amount'] as num?)?.toInt() ?? 0;
    final paidAmt = (inv['paid_amount'] as num?)?.toInt() ?? 0;
    final remaining = (amount - paidAmt).clamp(0, amount);
    final rawDate = inv['due_date'];
    final dueDate = rawDate is Timestamp ? rawDate.toDate() : null;
    final month = inv['month']?.toString() ?? '';
    final isDemand = type == 'DEMAND';
    final isOverdue = dueDate != null &&
        dueDate.isBefore(DateTime.now()) &&
        status != 'SUBMITTED';

    final Color accentColor;
    final List<Color> gradColors;
    if (status == 'SUBMITTED') {
      accentColor = AppColors.warning;
      gradColors = [const Color(0xFFD97706), const Color(0xFFF59E0B)];
    } else if (isOverdue) {
      accentColor = AppColors.error;
      gradColors = [const Color(0xFFDC2626), const Color(0xFFEF4444)];
    } else if (isDemand) {
      accentColor = const Color(0xFF8B5CF6);
      gradColors = [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)];
    } else {
      accentColor = AppColors.primary;
      gradColors = [const Color(0xFF1A56DB), const Color(0xFF3B82F6)];
    }

    void openPaymentForm() {
      if (status == 'SUBMITTED') {
        _showSnack(
            'This due is already submitted and waiting for admin verification.',
            isError: true);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserPayScreen(
            invoiceId: doc.id,
            prefilledAmount: remaining,
            monthLabel: isDemand
                ? title
                : (month.isNotEmpty
                    ? DateFormat('MMMM yyyy')
                        .format(DateTime.parse('$month-01'))
                    : ''),
            invoiceTitle: title,
            invoiceDescription: desc,
            invoiceType: type,
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: openPaymentForm,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDemand ? 'Special Due' : 'Monthly Maintenance',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (status == 'SUBMITTED') ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Under Review',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75), fontSize: 12),
              ),
            ],
            if (!isDemand && month.isNotEmpty)
              Text(
                DateFormat('MMMM yyyy').format(DateTime.parse('$month-01')),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75), fontSize: 12),
              ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      if (paidAmt > 0)
                        Text(
                          'of ₹${NumberFormat('#,##0').format(amount)} • ₹${NumberFormat('#,##0').format(paidAmt)} paid',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 11,
                          ),
                        ),
                      if (dueDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${isOverdue ? 'Was due' : 'Due by'} ${DateFormat('dd MMM yyyy').format(dueDate)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (status != 'SUBMITTED')
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status == 'PARTIAL' ? 'Pay Rest' : 'Pay Now',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceBanner(String name) {
    final isDemand = widget.invoiceType == 'DEMAND';
    final title = widget.invoiceTitle?.isNotEmpty == true
        ? widget.invoiceTitle!
        : (isDemand ? 'Special Due' : 'Monthly Maintenance');
    final subtitle = widget.invoiceDescription?.isNotEmpty == true
        ? widget.invoiceDescription!
        : (isDemand ? '' : widget.monthLabel ?? '');

    final gradColors = isDemand
        ? const [Color(0xFF7C3AED), Color(0xFF8B5CF6)]
        : const [Color(0xFF1A56DB), Color(0xFF3B82F6)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: gradColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.primaryShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(
                isDemand
                    ? Icons.request_quote_rounded
                    : Icons.receipt_long_rounded,
                color: Colors.white,
                size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ],
                const SizedBox(height: 4),
                Text('₹${widget.prefilledAmount ?? 0} due  •  $name',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
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

    // Guard: only the account owner can make payments.
    // A user is an owner if account_link is absent OR primary_owner_uid is null.
    final accountLink = userData['account_link'] as Map?;
    final isOwner =
        accountLink == null || accountLink['primary_owner_uid'] == null;
    if (!isOwner) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Pay Maintenance',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                )
              : IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () =>
                      dashboardScaffoldKey.currentState?.openDrawer(),
                ),
          actions: [
            if (Navigator.canPop(context))
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () =>
                    dashboardScaffoldKey.currentState?.openDrawer(),
              ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 36, color: AppColors.error),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Payments are managed by the flat owner',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Only the primary account holder can pay dues. Please contact the flat owner for payment.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final name =
        (userData['name'] ?? userData['username'] ?? 'User').toString();
    final ui = userData['unit_info'] as Map?;
    final flat =
        (userData['house_no'] ?? ui?['flat_no'] ?? ui?['house_no'] ?? '')
            .toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pay Maintenance',
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
                    dashboardScaffoldKey.currentState?.openDrawer(),
              ),
        actions: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => dashboardScaffoldKey.currentState?.openDrawer(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.border,
            height: 1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.invoiceId == null) ...[
            _sectionTitle('Pending Dues'),
            const SizedBox(height: 12),
            _buildPendingDuesSection(flat),
            const SizedBox(height: 28),
          ] else ...[
            _buildInvoiceBanner(name),
            const SizedBox(height: 16),
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
                    readOnly: true,
                    decoration: AppTheme.inputDecoration(
                      'Amount (₹)',
                      Icons.currency_rupee_rounded,
                    ).copyWith(
                      suffixIcon: const Tooltip(
                        message: 'Amount is fixed by the selected due',
                        child: Icon(Icons.lock_outline_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ),
                      fillColor: AppColors.divider,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: method,
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(
                          value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                    ],
                    onChanged: (v) => setState(() {
                      method = v ?? 'UPI';
                      txnCtrl.clear();
                    }),
                    decoration: AppTheme.inputDecoration(
                        'Payment Method', Icons.payment_rounded),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: txnCtrl,
                    textCapitalization: method == 'CASH'
                        ? TextCapitalization.words
                        : TextCapitalization.none,
                    decoration: AppTheme.inputDecoration(
                      method == 'CASH'
                          ? 'Handed over to?'
                          : 'Transaction ID / UTR',
                      method == 'CASH'
                          ? Icons.person_outline_rounded
                          : Icons.tag_rounded,
                    ),
                  ),
                  if (method != 'CASH') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: AppTheme.inputDecoration(
                          'Note (optional)', Icons.note_outlined),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
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
            AppTheme.gradientButton(
              label:
                  uploadingProof ? 'Uploading...' : 'Submit for Verification',
              onTap: uploadingProof ? null : _submitPayment,
              height: 52,
              icon: Icons.send_rounded,
            ),
            const SizedBox(height: 28),
          ],

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
                    final status = (m['status'] ?? 'PENDING').toString();
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
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          const Divider(height: 1, color: AppColors.divider),
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
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_rounded,
                                    color: AppColors.success, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  final file = await ReceiptPdfService
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
                          const Divider(height: 1, color: AppColors.divider),
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
