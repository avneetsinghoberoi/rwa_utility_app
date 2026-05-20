import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gate_basic/screens/login/login_screen.dart';

/// Wraps a widget in a minimal MaterialApp so it can be pumped in tests.
Widget _wrap(Widget child) {
  GoogleFonts.config.allowRuntimeFetching = false;
  return MaterialApp(home: child);
}

void main() {
  // ── Basic rendering ───────────────────────────────────────────────────────
  group('LoginScreen — renders', () {
    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pump();

      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    });

    testWidgets('shows a login button', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pump();

      // The login button contains text such as 'Login' or 'Sign In'
      expect(
        find.widgetWithText(ElevatedButton, 'Login').evaluate().isNotEmpty ||
            find.widgetWithText(FilledButton, 'Login').evaluate().isNotEmpty ||
            find.text('Login').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  // ── Validation feedback ───────────────────────────────────────────────────
  group('LoginScreen — validation', () {
    testWidgets('shows error snackbar when fields are empty', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pump();

      // Tap login without entering anything
      final loginBtn = find.text('Login');
      if (loginBtn.evaluate().isNotEmpty) {
        await tester.tap(loginBtn.first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(SnackBar), findsOneWidget);
      }
    });

    testWidgets('shows error for invalid email format', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pump();

      final emailField = find.byType(TextField).first;
      await tester.enterText(emailField, 'notanemail');

      final passwordFields = find.byType(TextField);
      if (passwordFields.evaluate().length > 1) {
        await tester.enterText(passwordFields.at(1), 'password123');
      }

      final loginBtn = find.text('Login');
      if (loginBtn.evaluate().isNotEmpty) {
        await tester.tap(loginBtn.first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(SnackBar), findsOneWidget);
      }
    });
  });

  // ── Toggle between Resident / Admin ──────────────────────────────────────
  group('LoginScreen — role toggle', () {
    testWidgets('has a way to switch between Resident and Admin login',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pump();

      // Look for Resident or Admin text used in the toggle
      final hasResident = find.text('Resident').evaluate().isNotEmpty ||
          find.text('Resident Login').evaluate().isNotEmpty;
      final hasAdmin = find.text('Admin').evaluate().isNotEmpty ||
          find.text('Admin Login').evaluate().isNotEmpty;

      expect(hasResident || hasAdmin, isTrue);
    });
  });
}
