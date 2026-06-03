import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gate_basic/screens/user/dashboard.dart';
import 'package:gate_basic/screens/admin/admin_dashboard.dart';
import 'package:gate_basic/screens/guard/guard_dashboard.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  String _selectedRole = 'resident'; // 'resident' | 'admin'
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _showError("User not found in database");
        return;
      }

      final doc = snapshot.docs.first;
      final userData = {...doc.data(), 'firestoreDocId': doc.id};
      final role = userData['role'] ?? 'user';

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else if (role == 'guard') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GuardDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Dashboard(userData: userData)),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Login failed. Please try again.");
    } catch (e) {
      _showError("Something went wrong. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPassword() async {
    final emailCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address. We\'ll send you a link to reset your password.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: AppTheme.inputDecoration('Email Address', Icons.email_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final email = emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Reset link sent to $email')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showError(e.code == 'user-not-found'
            ? 'No account found with this email.'
            : e.message ?? 'Failed to send reset email.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E40AF),
              Color(0xFF2563EB),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background decoration circles
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: -100,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -50,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Hero Section
                  Expanded(
                    flex: 45,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated Logo
                          AnimatedBuilder(
                            animation: Listenable.merge([_logoScale, _logoOpacity]),
                            builder: (context, child) => Opacity(
                              opacity: _logoOpacity.value,
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: child,
                              ),
                            ),
                            child: _buildEnhancedLogo(),
                          ),

                          const SizedBox(height: 20),

                          // Brand Name
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'GATE',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'BASIC',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Tagline with Glass Effect
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  'Smart Living, Simplified',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.9),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Form Card
                  Expanded(
                    flex: 55,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(40),
                              topRight: Radius.circular(40),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 30,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: 28,
                              right: 28,
                              top: 20,
                              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Welcome',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Sign in to access your account',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Role Toggle
                                _buildEnhancedRoleToggle(),
                                const SizedBox(height: 16),

                                // Email Field
                                _buildEnhancedInputField(
                                  controller: _emailController,
                                  label: 'Email Address',
                                  icon: Icons.email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),

                                // Password Field
                                _buildEnhancedInputField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_rounded,
                                  obscureText: _obscurePassword,
                                  suffixIcon: GestureDetector(
                                    onTap: () {
                                      setState(() =>
                                          _obscurePassword = !_obscurePassword);
                                    },
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: AppColors.primary.withOpacity(0.6),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Forgot Password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: _showForgotPassword,
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Login Button
                                _buildEnhancedLoginButton(),
                                const SizedBox(height: 12),

                                // Guard login link
                                Center(
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const _GuardLoginScreen()),
                                    ),
                                    child: RichText(
                                      text: TextSpan(
                                        text: 'Are you a guard?  ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        children: const [
                                          TextSpan(
                                            text: 'Login here',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced Input Field
  Widget _buildEnhancedInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.7)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.primaryLight.withOpacity(0.6),
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
      ),
    );
  }

  // Enhanced Role Toggle
  Widget _buildEnhancedRoleToggle() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildRoleOption('Resident', Icons.home_rounded, 'resident'),
          _buildRoleOption('Admin', Icons.admin_panel_settings_rounded, 'admin'),
        ],
      ),
    );
  }

  Widget _buildRoleOption(String label, IconData icon, String role) {
    final selected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced Login Button
  Widget _buildEnhancedLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _loginUser,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 56,
        decoration: BoxDecoration(
          gradient: _isLoading || _emailController.text.isEmpty
              ? LinearGradient(
                  colors: [
                    Colors.grey.withOpacity(0.4),
                    Colors.grey.withOpacity(0.3),
                  ],
                )
              : AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(
                      Colors.white.withOpacity(0.8),
                    ),
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.login_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Login as ${_selectedRole == 'admin' ? 'Admin' : 'Resident'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // Enhanced Logo Widget (Square)
  Widget _buildEnhancedLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/logo_rwa_app.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: const Icon(
              Icons.apartment_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Guard Login Screen ────────────────────────────────────────────────────────
class _GuardLoginScreen extends StatefulWidget {
  const _GuardLoginScreen();

  @override
  State<_GuardLoginScreen> createState() => _GuardLoginScreenState();
}

class _GuardLoginScreenState extends State<_GuardLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailCtrl.text.trim())
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _showError('Account not found.');
        await FirebaseAuth.instance.signOut();
        return;
      }

      final role = snap.docs.first['role']?.toString() ?? '';
      if (role != 'guard') {
        _showError('This login is only for guard accounts.');
        await FirebaseAuth.instance.signOut();
        return;
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GuardDashboard()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Login failed. Please try again.');
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.security_rounded,
                    color: AppColors.primary, size: 34),
              ),
              const SizedBox(height: 20),
              const Text(
                'Guard Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in with your guard credentials',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),

              // Email
              const Text('Email',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _deco('Enter your email',
                    Icons.email_outlined),
              ),
              const SizedBox(height: 16),

              // Password
              const Text('Password',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: _deco(
                  'Enter your password',
                  Icons.lock_outline_rounded,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _login,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.login_rounded, size: 20),
                  label: Text(
                    _loading ? 'Signing in...' : 'Login as Guard',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIcon:
            Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}
