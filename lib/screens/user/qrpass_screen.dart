import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rms_app/screens/login/login_screen.dart';
import 'package:rms_app/theme/app_theme.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  // ── Fetch user data (logic unchanged) ─────────────────────────
  Future<void> fetchUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: currentUser.email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          userData = querySnapshot.docs.first.data();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          userData = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() => isLoading = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (userData == null) {
      return const Scaffold(
          body: Center(child: Text('No user data found.')));
    }

    final name = userData!['name'] ?? 'Unknown User';
    final houseNo = userData!['house_no'] ?? '-';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Gradient header ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
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
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Avatar + name
                    Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Avatar circle
                          Container(
                            width: 80,
                            height: 80,
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
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'House No. $houseNo',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Info card ─────────────────────────────────
                  _buildInfoCard(),
                  const SizedBox(height: 16),

                  // ── QR code card ──────────────────────────────
                  _buildQrCard(),
                  const SizedBox(height: 24),

                  // ── Logout button ─────────────────────────────
                  AppTheme.gradientButton(
                    label: 'Logout',
                    onTap: _logout,
                    height: 52,
                    icon: Icons.logout_rounded,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info Card ────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    // Safely format last_payment_date — Firestore returns a Timestamp, not a String
    final rawDate = userData!['last_payment_date'];
    String lastPayment = '-';
    if (rawDate is Timestamp) {
      lastPayment = DateFormat('dd MMM yyyy').format(rawDate.toDate());
    } else if (rawDate is String && rawDate.isNotEmpty) {
      lastPayment = rawDate;
    }

    final rows = [
      _InfoEntry('Email', userData!['email']?.toString() ?? '-', Icons.email_outlined),
      _InfoEntry('Phone', userData!['phone']?.toString() ?? '-', Icons.phone_outlined),
      _InfoEntry('Floor', userData!['floor']?.toString() ?? '-', Icons.layers_outlined),
      _InfoEntry('Maintenance Status', userData!['maintenance_status']?.toString() ?? '-',
          Icons.check_circle_outline),
      _InfoEntry('Dues (₹)', '${userData!['dues'] ?? 0}',
          Icons.account_balance_wallet_outlined),
      _InfoEntry('Last Payment', lastPayment, Icons.calendar_today_outlined),
    ];

    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Profile Details',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...rows.asMap().entries.map((entry) {
            final isLast = entry.key == rows.length - 1;
            return Column(
              children: [
                _buildInfoRow(entry.value),
                if (!isLast)
                  const Divider(
                      height: 1,
                      color: AppColors.divider,
                      indent: 56),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoRow(_InfoEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: AppColors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              entry.value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ── QR Code Card ─────────────────────────────────────────────────
  Widget _buildQrCard() {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Entry QR Code',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
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
                      'name': userData?['name'] ?? 'Unknown',
                      'house_no': userData?['house_no'] ?? 'N/A',
                      'phone': userData?['phone'] ?? 'N/A',
                    }),
                    version: QrVersions.auto,
                    size: 180,
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
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

// ── Helper data class ────────────────────────────────────────────────
class _InfoEntry {
  final String label;
  final String value;
  final IconData icon;
  const _InfoEntry(this.label, this.value, this.icon);
}

/// Simple reusable InfoRow widget (kept for backward compatibility)
class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
          Flexible(
              child: Text(value,
                  style:
                      const TextStyle(color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}
