# Complete Solution Guide - Login Issues

## Summary of Issues Found
1. ❌ Role toggle doesn't affect login logic
2. ❌ No input validation
3. ❌ Network/reCAPTCHA errors (emulator connectivity)
4. ❌ No proper error messages
5. ❌ Missing user existence check

## Quick Action Items

### Step 1: Fix the Emulator Network Issue (CRITICAL)
**Why:** Your logs show network errors. The emulator doesn't have internet.

**Solution:**

```bash
# Test if emulator has internet
adb shell ping -c 1 8.8.8.8

# If ping fails, the emulator has no internet. Solutions:

# Option A: Wipe and recreate emulator (recommended)
adb emu kill
# Delete the emulator from Android Studio > Device Manager
# Create a new one with API 33+ and ensure it's configured with internet access

# Option B: Enable internet access in current emulator
adb shell settings put global http_proxy ""  # Clear any proxy settings
# Then restart the emulator
adb reboot
```

---

### Step 2: Disable reCAPTCHA for Testing
**Why:** reCAPTCHA is blocking login attempts due to network issues.

**Steps:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `rms-app-3d585`
3. Go to **Authentication** → **Security**
4. Find "App Check enforcement"
5. **Temporarily disable** it for testing (can re-enable for production)
6. Find reCAPTCHA setting
7. **Disable reCAPTCHA** or set it to "Only on suspicious requests"

---

### Step 3: Update Your Login Screen
**Why:** Current login screen has the issues listed above.

**Steps:**

#### Option A: Use the Fixed Version (RECOMMENDED)
1. Copy the contents of `login_screen_FIXED.dart` provided to you
2. Replace your current `lib/screens/login/login_screen.dart` with the fixed version
3. Update the imports if needed
4. Run: `flutter pub get && flutter run`

#### Option B: Manual Fixes (If you want to keep customizations)
Apply these changes to your existing login_screen.dart:

**A1. Add input validation:**
```dart
bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      _showError('Please enter your email address');
      return false;
    }

    if (!email.contains('@')) {
      _showError('Please enter a valid email address');
      return false;
    }

    if (password.isEmpty || password.length < 6) {
      _showError('Password must be at least 6 characters');
      return false;
    }

    return true;
  }
```

**A2. Update _loginUser() to use validation:**
```dart
Future<void> _loginUser() async {
    // ✅ Validate inputs first
    if (!_validateInputs()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // ✅ Check user exists in Firestore FIRST
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _showError('Account not found. Please check your email.');
        setState(() => _isLoading = false);
        return;
      }

      final doc = snapshot.docs.first;
      final userData = {...doc.data(), 'firestoreDocId': doc.id};
      final userRole = userData['role'] ?? 'user';

      // ✅ Validate role matches selection
      if (isResident && userRole == 'admin') {
        _showError('This is an admin account. Please select "Admin" to login.');
        setState(() => _isLoading = false);
        return;
      }

      if (!isResident && userRole != 'admin') {
        _showError('This is a resident account. Please select "Resident" to login.');
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Now authenticate with Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (userRole == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Dashboard(userData: userData)),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = e.message ?? 'Login failed';
      
      if (e.code == 'user-not-found') {
        errorMessage = 'No account found with this email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Check your internet connection.';
      }
      
      _showError(errorMessage);
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }
```

---

### Step 4: Test Your Setup
**Steps:**

1. **Create test users in Firebase:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Authentication → Users → Create user
   - Create at least 2 users:
     - Resident: `resident@test.com` / password: `test123456`
     - Admin: `admin@test.com` / password: `test123456`

2. **Create matching Firestore documents:**
   - Go to Firestore Database
   - Collection: `users`
   - Create 2 documents:
   
   **Document 1 (Resident):**
   ```
   email: resident@test.com
   role: user
   name: Test Resident
   ```
   
   **Document 2 (Admin):**
   ```
   email: admin@test.com
   role: admin
   name: Test Admin
   ```

3. **Test login:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Try logging in:**
   - Select "Resident" toggle
   - Enter: `resident@test.com` / `test123456`
   - Click Login
   - Should redirect to Dashboard

5. **Try admin login:**
   - Select "Admin" toggle
   - Enter: `admin@test.com` / `test123456`
   - Click Login
   - Should redirect to AdminDashboard

---

## Debugging Tips

### If you still get network errors:

1. **Check emulator internet:**
   ```bash
   adb shell ping google.com
   ```

2. **Check Firebase logs:**
   - Android Studio → Logcat
   - Filter: `FirebaseAuth` or `RecaptchaCallWrapper`
   - Look for actual error messages

3. **Enable verbose logging in main.dart:**
   ```dart
   import 'package:firebase_core/firebase_core.dart';
   
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     
     // Enable Firebase debug logging
     Firebase.initializeApp(
       options: DefaultFirebaseOptions.currentPlatform,
     );
     
     // Add this
     FirebaseAuth.instance.authStateChanges().listen((User? user) {
       debugPrint("🔐 Auth state changed: $user");
     });
     
     runApp(const MyApp());
   }
   ```

---

## Common Errors & Solutions

### Error: "A network error has occurred"
**Cause:** Emulator has no internet
**Fix:** Restart emulator or recreate it with internet access

### Error: "No AppCheckProvider installed"
**Cause:** App Check is enabled but not configured
**Fix:** Disable App Check in Firebase Console for testing

### Error: "User not found in database"
**Cause:** User exists in Firebase Auth but not in Firestore
**Fix:** Create matching document in Firestore `users` collection

### Error: "This is an admin account. Please select Admin to login"
**Cause:** Selected role doesn't match user's actual role
**Fix:** Select the correct role toggle before logging in

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/screens/login/login_screen.dart` | Added validation, role checking, better error messages |
| Firebase Console | Disabled reCAPTCHA and App Check (temporarily) |
| Emulator Network | Fixed connectivity issue |
| Firestore | Created test user documents |

---

## Next Steps (After Login Works)

1. ✅ Test all user flows (resident & admin)
2. ✅ Test Firestore queries work
3. ✅ Test notification service
4. ✅ Re-enable reCAPTCHA for production
5. ✅ Re-enable App Check for production
6. ✅ Deploy to Google Play Store

---

## Questions?

If you still have issues:
1. Check the debug logs in Android Studio
2. Verify Firebase credentials in `firebase_options.dart`
3. Verify Firestore database rules allow reads/writes
4. Check internet connectivity: `adb shell ping 8.8.8.8`

Good luck! 🚀

