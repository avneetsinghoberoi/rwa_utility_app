import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gate_basic/screens/admin/admin_profile_screen.dart';
import 'package:gate_basic/screens/admin/members_screen.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'package:gate_basic/utils/admin_dashboard_key.dart';
import 'admin_dues_screen.dart';
import 'admin_pay_screen.dart';
import 'admin_issues.dart';
import 'admin_expense.dart';
import 'admin_notices.dart';
import 'admin_reports_screen.dart';
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

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 6;

  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Members',
      icon: Icons.people_alt_outlined,
      selectedIcon: Icons.people_alt_rounded,
      screen: MembersScreen(),
    ),
    _NavItem(
      label: 'Pay',
      icon: Icons.credit_card_outlined,
      selectedIcon: Icons.credit_card_rounded,
      screen: AdminPayScreen(),
    ),
    _NavItem(
      label: 'Dues',
      icon: Icons.request_quote_outlined,
      selectedIcon: Icons.request_quote_rounded,
      screen: AdminDuesScreen(),
    ),
    _NavItem(
      label: 'Issues',
      icon: Icons.report_problem_outlined,
      selectedIcon: Icons.report_problem_rounded,
      screen: AdminIssuesScreen(),
    ),
    _NavItem(
      label: 'Expenses',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      screen: AdminExpenseScreen(),
    ),
    _NavItem(
      label: 'Notices',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      screen: AdminNoticesScreen(),
    ),
    _NavItem(
      label: 'Reports',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
      screen: AdminReportsScreen(),
    ),
    _NavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      screen: AdminProfileScreen(),
    ),
  ];

  // ── Drawer ───────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
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
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Admin Portal',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // ── Navigation items ─────────────────────────────────────
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  for (int i = 0; i < _navItems.length; i++)
                    _drawerTile(context, i),
                ],
              ),
            ),

            // ── Logout ───────────────────────────────────────────────
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
                Navigator.pop(context);
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

  Widget _drawerTile(BuildContext context, int index) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
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
          setState(() => _selectedIndex = index);
          Navigator.pop(context); // close drawer
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: adminDashboardScaffoldKey,
      body: IndexedStack(
        index: _selectedIndex,
        children: _navItems.map((item) => item.screen).toList(),
      ),
      drawer: _buildDrawer(context),
    );
  }
}
