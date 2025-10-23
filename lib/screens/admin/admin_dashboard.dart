import 'package:flutter/material.dart';
import 'package:rms_app/screens/admin/admin_profile_screen.dart';
import 'package:rms_app/screens/admin/members_screen.dart';
import 'admin_pay_screen.dart';
import 'admin_issues.dart';
import 'admin_expense.dart';
import 'admin_notices.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 1;

  final List<Widget> _screens = [
    MembersScreen(), // optional - if you later add member list
    AdminPayScreen(),
    AdminIssueScreen(),
    AdminExpenseScreen(),
    AdminNoticesScreen(),
    AdminProfileScreen(),
  ];

  final List<String> _titles = [
    "Members",
    "Payments",
    "Issues",
    "Expense",
    "Notices"
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: "Members"),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card_outlined), label: "Payments"),
          BottomNavigationBarItem(icon: Icon(Icons.report_problem_outlined), label: "Issues"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: "Expense"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none_outlined), label: "Notices"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile")
        ],
      ),
    );
  }
}

// Optional placeholder (if you don’t have it yet)
class AdminMembersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: const Text("Admin Portal")),
      body: const Center(child: Text("Members Dashboard Coming Soon")),
    );
  }
}
