import 'package:flutter/material.dart';
import 'pay_screen.dart';
import 'issues_screen.dart';
import 'notices_screen.dart';
import 'expense_screen.dart';
import 'qrpass_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;

  final screens = const [
    PayScreen(),
    IssuesScreen(),
    NoticesScreen(),
    ExpenseScreen(),
    UserProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.payment_outlined), label: "Pay"),
          NavigationDestination(icon: Icon(Icons.report_problem_outlined), label: "Issues"),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: "Notices"),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: "Expense"),
          NavigationDestination(icon: Icon(Icons.qr_code_2_outlined), label: "QR Pass"),
        ],
      ),
    );
  }
}
