import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rms_app/screens/login/login_screen.dart';
import 'package:rms_app/screens/user/dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Wait 3 seconds and decide next screen
    Timer(const Duration(seconds: 3), () {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        try {
          // ✅ Fetch userData from Firestore
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();

// ✅ Access the first document
          if (snapshot.docs.isEmpty) {
            throw Exception("User not found.");
          }

          final userData = snapshot.docs.first.data(); // ✅ This works


          // ✅ Navigate to Dashboard with userData
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => Dashboard(userData: userData),
            ),
          );
        } catch (e) {
          // Handle error if needed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to load user data: $e")),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // or your theme color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo_rwa_app.png', height: 120), // ✅ Add your app logo
            const SizedBox(height: 20),
            const Text(
              'RWA Manager',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
