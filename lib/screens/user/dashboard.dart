import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import '../../models/user.dart' as UserModel;
import '../../theme/app_theme.dart';
import '../../utils/dashboard_key.dart';
import 'user_home_screen.dart';
import 'pay_screen.dart';
import 'issues_screen.dart';
import 'notices_screen.dart';
import 'expense_screen.dart';
import 'manage_members_screen.dart';
import 'user_profile_screen.dart';
import '../login/login_screen.dart';

// ── Simple data class for a navigation entry ─────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });
}

class Dashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const Dashboard({super.key, required this.userData});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;
  UserModel.User? currentUser; // nullable — set only on success
  String? _loadError;          // set on failure
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  // ── Load user data and convert to User model ─────────────────────────────
  Future<void> _initializeUser() async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUserAuth = auth.currentUser;

      if (currentUserAuth == null) {
        setState(() { _loadError = 'Not logged in.'; isLoading = false; });
        return;
      }

      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserAuth.uid);
      final doc = await ref.get();

      if (!doc.exists) {
        setState(() {
          _loadError = 'User profile not found. Contact your admin.';
          isLoading = false;
        });
        return;
      }

      final data = doc.data()!;

      // If this account was removed while the user was already logged in,
      // sign them out immediately and redirect to login.
      final status = (data['status'] ?? 'active').toString();
      if (status == 'removed') {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      // Backfill missing fields for admin-created residents.
      final backfill = <String, dynamic>{};
      if (!data.containsKey('flat_members') ||
          (data['flat_members'] as List?)?.isEmpty == true) {
        backfill['flat_members'] = [currentUserAuth.uid];
      }
      if (!data.containsKey('status')) {
        backfill['status'] = 'active';
      }

      // Backfill house_no for tenants/family created before the Cloud Function fix.
      final accountLink = data['account_link'] as Map?;
      final primaryOwnerUid = accountLink?['primary_owner_uid']?.toString();
      final currentHouseNo = data['house_no']?.toString() ?? '';
      if (primaryOwnerUid != null && currentHouseNo.isEmpty) {
        try {
          final ownerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(primaryOwnerUid)
              .get();
          if (ownerDoc.exists) {
            final ownerHouseNo =
                ownerDoc.data()?['house_no']?.toString() ?? '';
            if (ownerHouseNo.isNotEmpty) {
              backfill['house_no'] = ownerHouseNo;
            }
          }
        } catch (e) {
          debugPrint('Could not backfill tenant house_no: $e');
        }
      }

      bool backfillWritten = false;
      if (backfill.isNotEmpty) {
        try {
          await ref.update(backfill);
          backfillWritten = true;
        } catch (e) {
          debugPrint('Backfill write failed (non-fatal): $e');
        }
      }

      final freshDoc = backfillWritten ? await ref.get() : doc;

      if (!mounted) return;
      setState(() {
        currentUser = UserModel.User.fromFirestore(freshDoc);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing user: $e');
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load profile. Please restart the app.';
          isLoading = false;
        });
      }
    }
  }

  // ── Build the unified list of tab items ──────────────────────────────────
  List<_NavItem> _buildTabItems() {
    final user = currentUser!;
    return [
      _NavItem(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        screen: UserHomeScreen(userData: user.toFirestore()),
      ),
      if (user.isAccountOwner)
        const _NavItem(
          label: 'Pay',
          icon: Icons.payment_outlined,
          selectedIcon: Icons.payment_rounded,
          screen: UserPayScreen(),
        ),
      const _NavItem(
        label: 'Issues',
        icon: Icons.report_problem_outlined,
        selectedIcon: Icons.report_problem_rounded,
        screen: IssuesScreen(),
      ),
      const _NavItem(
        label: 'Notices',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications_rounded,
        screen: NoticesScreen(),
      ),
      const _NavItem(
        label: 'Expenses',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        screen: ExpenseScreen(),
      ),
      if (user.canManageFlatMembers)
        _NavItem(
          label: 'Members',
          icon: Icons.people_outline,
          selectedIcon: Icons.people_rounded,
          screen: ManageMembersScreen(currentUser: user),
        ),
      const _NavItem(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        screen: UserProfileScreen(),
      ),
    ];
  }

  // ── Drawer ───────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context, List<_NavItem> items) {
    final user = currentUser!;
    final name = user.name;
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    final houseNo = user.unitInfo.houseNo;
    final String? roleLabel = user.isLinkedUser
        ? () {
            final la = user.accountLink.linkedAs;
            return la.isNotEmpty
                ? '${la[0].toUpperCase()}${la.substring(1)}'
                : 'Tenant';
          }()
        : null;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (houseNo.isNotEmpty)
                        Text(
                          'House $houseNo',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      if (houseNo.isNotEmpty && roleLabel != null)
                        Text(
                          '  ·  ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 13,
                          ),
                        ),
                      if (roleLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            roleLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Navigation items ────────────────────────────────────
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  for (int i = 0; i < items.length; i++)
                    _drawerTile(context, i, items[i]),
                ],
              ),
            ),

            // ── Logout ──────────────────────────────────────────────
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              onTap: () async {
                Navigator.pop(context); // close drawer first
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(BuildContext context, int index, _NavItem item) {
    final isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: ListTile(
        leading: Icon(
          isSelected ? item.selectedIcon : item.icon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          size: 22,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppColors.primaryLight.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        onTap: () {
          setState(() => _currentIndex = index);
          Navigator.pop(context); // close drawer
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null || currentUser == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  _loadError ?? 'Something went wrong.',
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                      _loadError = null;
                    });
                    _initializeUser();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tabItems = _buildTabItems();

    return Scaffold(
      key: dashboardScaffoldKey,
      body: IndexedStack(
        index: _currentIndex,
        children: tabItems.map((t) => t.screen).toList(),
      ),
      drawer: _buildDrawer(context, tabItems),
    );
  }
}
