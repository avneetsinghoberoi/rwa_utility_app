import 'package:flutter/material.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'user_home_screen.dart';
import 'pay_screen.dart';
import 'issues_screen.dart';
import 'notices_screen.dart';
import 'expense_screen.dart';
import 'qrpass_screen.dart';
import 'directory_screen.dart';

class Dashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const Dashboard({super.key, required this.userData});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      UserHomeScreen(userData: widget.userData),
      const UserPayScreen(),
      const IssuesScreen(),
      const NoticesScreen(),
      const ExpenseScreen(),
      UserProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.payment_outlined),
            selectedIcon: Icon(Icons.payment_rounded, color: AppColors.primary),
            label: 'Pay',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_problem_outlined),
            selectedIcon: Icon(Icons.report_problem_rounded, color: AppColors.primary),
            label: 'Issues',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded, color: AppColors.primary),
            label: 'Notices',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            label: 'Expense',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
