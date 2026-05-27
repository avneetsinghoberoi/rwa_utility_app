import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gate_basic/theme/app_theme.dart';
import '../login/login_screen.dart';
import '../../utils/dashboard_key.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Vehicle number inline editing
  bool _editingVehicle = false;
  bool _savingVehicle = false;
  late TextEditingController _vehicleCtrl;

  @override
  void initState() {
    super.initState();
    _vehicleCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveVehicleNo(String uid) async {
    final val = _vehicleCtrl.text.trim().toUpperCase();
    setState(() => _savingVehicle = true);
    try {
      await _firestore.collection('users').doc(uid).update({'vehicle_no': val});
      if (!mounted) return;
      setState(() {
        _editingVehicle = false;
        _savingVehicle = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Vehicle number saved!'),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingVehicle = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in.')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            _firestore.collection('users').doc(firebaseUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No user data found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // ── Parse fields ──────────────────────────────────────────
          final name =
              (data['name'] ?? firebaseUser.displayName ?? 'User').toString();
          final email = (data['email'] ?? firebaseUser.email ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final houseNo = (data['house_no'] ??
                  (data['unit_info'] as Map?)?['house_no'] ??
                  '')
              .toString();
          final vehicleNo = (data['vehicle_no'] ?? '').toString().trim();

          final accountLink = data['account_link'] as Map?;
          final isOwner =
              accountLink == null || accountLink['primary_owner_uid'] == null;
          final linkedAs = (accountLink?['linked_as'] ?? '').toString();
          final roleLabel = isOwner
              ? 'Owner'
              : (linkedAs.isNotEmpty
                  ? '${linkedAs[0].toUpperCase()}${linkedAs.substring(1)}'
                  : 'Tenant');

          final createdAt = data['created_at'];
          final memberSince = createdAt is Timestamp
              ? DateFormat('dd MMM yyyy').format(createdAt.toDate())
              : (firebaseUser.metadata.creationTime != null
                  ? DateFormat('dd MMM yyyy')
                      .format(firebaseUser.metadata.creationTime!)
                  : '—');

          final rawLastPay = data['last_payment_date'];
          final lastPayment = rawLastPay is Timestamp
              ? DateFormat('dd MMM yyyy').format(rawLastPay.toDate())
              : (rawLastPay is String && rawLastPay.isNotEmpty
                  ? rawLastPay
                  : '—');

          final initials = name.trim().isNotEmpty
              ? name
                  .trim()
                  .split(' ')
                  .take(2)
                  .map((w) => w[0].toUpperCase())
                  .join()
              : '?';

          // Sync vehicle controller when not actively editing
          if (!_editingVehicle && _vehicleCtrl.text != vehicleNo) {
            _vehicleCtrl.text = vehicleNo;
          }

          return CustomScrollView(
            slivers: [
              // ── Gradient header ─────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.primaryDark,
                leading: Navigator.canPop(context)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    : IconButton(
                        icon:
                            const Icon(Icons.menu_rounded, color: Colors.white),
                        onPressed: () =>
                            dashboardScaffoldKey.currentState?.openDrawer(),
                      ),
                actions: [
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white),
                      onPressed: () =>
                          dashboardScaffoldKey.currentState?.openDrawer(),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Container(
                    decoration:
                        const BoxDecoration(gradient: AppTheme.primaryGradient),
                    child: Stack(
                      children: [
                        // Decorative circle
                        Positioned(
                          top: -50,
                          right: -50,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Avatar + name + role
                        Align(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 48),
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 2.5),
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (houseNo.isNotEmpty) ...[
                                    const Icon(Icons.home_outlined,
                                        color: Colors.white70, size: 13),
                                    const SizedBox(width: 4),
                                    Text('House $houseNo',
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.85),
                                            fontSize: 13)),
                                    const SizedBox(width: 8),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(roleLabel,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Body content ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // ── Profile details card ──────────────────
                      _card(
                        headerIcon: Icons.person_outline_rounded,
                        headerLabel: 'Profile Details',
                        child: Column(
                          children: [
                            _infoRow(Icons.email_outlined, 'Email',
                                email.isNotEmpty ? email : '—'),
                            _divider(),
                            _infoRow(Icons.phone_outlined, 'Phone',
                                phone.isNotEmpty ? phone : '—'),
                            _divider(),
                            _infoRow(Icons.home_outlined, 'House No.',
                                houseNo.isNotEmpty ? houseNo : '—'),
                            _divider(),
                            _infoRow(Icons.calendar_today_outlined,
                                'Member Since', memberSince),
                            _divider(),
                            _infoRow(Icons.payment_outlined, 'Last Payment',
                                lastPayment),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Vehicle number card ───────────────────
                      Container(
                        decoration: AppTheme.cardDecoration,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.directions_car_rounded,
                                      color: Color(0xFFF59E0B),
                                      size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text('Vehicle Number',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary)),
                                ),
                                if (!_editingVehicle)
                                  TextButton.icon(
                                    onPressed: () {
                                      _vehicleCtrl.text = vehicleNo;
                                      setState(() => _editingVehicle = true);
                                    },
                                    icon: const Icon(Icons.edit_rounded,
                                        size: 15),
                                    label: const Text('Edit'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (!_editingVehicle)
                              // Plate-style display
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: vehicleNo.isNotEmpty
                                      ? const Color(0xFFFEF3C7)
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: vehicleNo.isNotEmpty
                                        ? const Color(0xFFF59E0B)
                                            .withOpacity(0.5)
                                        : AppColors.border,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    vehicleNo.isNotEmpty
                                        ? vehicleNo
                                        : 'Not set — tap Edit to add',
                                    style: TextStyle(
                                      fontSize: vehicleNo.isNotEmpty ? 18 : 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing:
                                          vehicleNo.isNotEmpty ? 2.0 : 0,
                                      color: vehicleNo.isNotEmpty
                                          ? const Color(0xFF92400E)
                                          : AppColors.textHint,
                                    ),
                                  ),
                                ),
                              )
                            else ...[
                              TextField(
                                controller: _vehicleCtrl,
                                autofocus: true,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: AppTheme.inputDecoration(
                                    'e.g. MH12AB1234',
                                    Icons.directions_car_rounded),
                                style: const TextStyle(
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _savingVehicle
                                          ? null
                                          : () => setState(
                                              () => _editingVehicle = false),
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _savingVehicle
                                          ? null
                                          : () =>
                                              _saveVehicleNo(firebaseUser.uid),
                                      icon: _savingVehicle
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : const Icon(Icons.check_rounded,
                                              size: 18),
                                      label: Text(
                                          _savingVehicle ? 'Saving…' : 'Save'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── QR Code card ──────────────────────────
                      _card(
                        headerIcon: Icons.qr_code_rounded,
                        headerLabel: 'Entry QR Code',
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: QrImageView(
                                  data: jsonEncode({
                                    'name': name,
                                    'house_no': houseNo,
                                    'phone': phone,
                                    if (vehicleNo.isNotEmpty)
                                      'vehicle_no': vehicleNo,
                                  }),
                                  version: QrVersions.auto,
                                  size: 190,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Show this at the society gate for entry',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Logout ────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded,
                              color: AppColors.error),
                          label: const Text('Logout',
                              style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  Widget _card(
      {required IconData headerIcon,
      required String headerLabel,
      required Widget child}) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(headerIcon, color: AppColors.primary, size: 17),
                ),
                const SizedBox(width: 10),
                Text(headerLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: AppColors.primary, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
          ),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 62, color: AppColors.divider);
}
