import 'package:flutter/material.dart';
import 'user_home_screen.dart'; // ✅ Import home screen
import 'pay_screen.dart';
import 'issues_screen.dart';
import 'notices_screen.dart';
import 'expense_screen.dart';
import 'qrpass_screen.dart';

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
      UserHomeScreen(userData: widget.userData),  // ✅ Legal here
      const PayScreen(),
      const IssuesScreen(),
      const NoticesScreen(),
      const ExpenseScreen(),
      UserProfileScreen(),
    ];
    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.payment_outlined),
            label: "Pay",
          ),
          NavigationDestination(
            icon: Icon(Icons.report_problem_outlined),
            label: "Issues",
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: "Notices",
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: "Expense",
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            label: "QR Pass",
          ),
        ],
      ),
    );
  }
}

