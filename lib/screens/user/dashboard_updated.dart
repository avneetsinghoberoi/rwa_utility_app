import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import 'user_home_screen.dart';
import 'pay_screen.dart';
import 'issues_screen.dart';
import 'notices_screen.dart';
import 'expense_screen.dart';
import 'qrpass_screen.dart';
import 'directory_screen.dart';
import 'manage_members_screen.dart';

class Dashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const Dashboard({super.key, required this.userData});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;
  late User currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  /// Load user data and convert to User model
  Future<void> _initializeUser() async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUserAuth = auth.currentUser;

      if (currentUserAuth != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserAuth.uid)
            .get();

        if (doc.exists) {
          setState(() {
            currentUser = User.fromFirestore(doc);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error initializing user: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Build screens dynamically based on user role and account ownership
    final screens = _buildScreens();
    final navigationDestinations = _buildNavigationDestinations();

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primaryLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: navigationDestinations,
      ),
    );
  }

  /// Build screens list dynamically
  List<Widget> _buildScreens() {
    return [
      UserHomeScreen(userData: currentUser.toFirestore()),
      const UserPayScreen(),
      const IssuesScreen(),
      const NoticesScreen(),
      const ExpenseScreen(),
      // Add Manage Members screen only for account owners
      if (currentUser.canManageFlatMembers)
        ManageMembersScreen(currentUser: currentUser),
      UserProfileScreen(),
    ];
  }

  /// Build navigation destinations dynamically
  List<NavigationDestination> _buildNavigationDestinations() {
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primaryColor),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.payment_outlined),
        selectedIcon: Icon(Icons.payment_rounded, color: AppTheme.primaryColor),
        label: 'Pay',
      ),
      const NavigationDestination(
        icon: Icon(Icons.report_problem_outlined),
        selectedIcon:
            Icon(Icons.report_problem_rounded, color: AppTheme.primaryColor),
        label: 'Issues',
      ),
      const NavigationDestination(
        icon: Icon(Icons.notifications_outlined),
        selectedIcon:
            Icon(Icons.notifications_rounded, color: AppTheme.primaryColor),
        label: 'Notices',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon:
            Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor),
        label: 'Expense',
      ),
    ];

    // Add Manage Members for account owners
    if (currentUser.canManageFlatMembers) {
      destinations.add(
        NavigationDestination(
          icon: Badge(
            label: Text('${currentUser.flatMemberCount}'),
            child: const Icon(Icons.people_outline),
          ),
          selectedIcon: Badge(
            label: Text('${currentUser.flatMemberCount}'),
            child: const Icon(Icons.people_rounded,
                color: AppTheme.primaryColor),
          ),
          label: 'Members',
        ),
      );
    }

    // Profile is always last
    destinations.add(
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon:
            Icon(Icons.person_rounded, color: AppTheme.primaryColor),
        label: 'Profile',
      ),
    );

    return destinations;
  }
}

/// Profile Screen (imported but needs to be updated if it's a separate file)
/// For now, using a placeholder
class UserProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: const Center(
        child: Text('Profile Screen'),
      ),
    );
  }
}
