# RWA App - Code Examples & Key Snippets

## 1. Authentication Flow

### Login Screen (main.dart)
```dart
// Entry point - determines which screen to show based on user role
Future<Widget> _getLandingPage() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    
    // No user logged in → show login screen
    if (user == null) {
      return const LoginScreen();
    }
    
    // Get user record from Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: user.email)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final role = doc['role'] ?? 'user';
      
      // Route based on role
      if (role == 'admin') {
        return const AdminDashboard();
      } else {
        final userData = {
          ...doc.data(),
          'firestoreDocId': doc.id,
        };
        return Dashboard(userData: userData);
      }
    }
  } catch (e) {
    debugPrint("Error: $e");
  }
  
  return const LoginScreen();
}
```

### Login Logic (login_screen.dart)
```dart
Future<void> _loginUser() async {
  setState(() => _isLoading = true);
  
  try {
    // Sign in with Firebase Auth
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    
    // Get user role from Firestore
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
    
    // Route to appropriate dashboard
    if (role == 'admin') {
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
    _showError(e.message ?? "Login failed");
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### Password Reset
```dart
Future<void> _showForgotPassword() async {
  final emailCtrl = TextEditingController();
  
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Reset Password'),
      content: TextField(
        controller: emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(labelText: 'Email Address'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Send Reset Link'),
        ),
      ],
    ),
  );
  
  if (result != true) return;
  
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: emailCtrl.text.trim(),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reset link sent to ${emailCtrl.text}')),
    );
  } on FirebaseAuthException catch (e) {
    _showError(e.message ?? 'Failed to send reset email');
  }
}
```

---

## 2. Payment Submission & Verification

### Resident Submits Payment (user/pay_screen.dart)
```dart
Future<void> _submitPayment() async {
  if (user == null) return;
  
  final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
  if (amount <= 0) {
    _showSnack('Enter valid amount', isError: true);
    return;
  }
  
  final utr = txnCtrl.text.trim();
  if (utr.length < 6) {
    _showSnack('Enter valid UTR (min 6 characters)', isError: true);
    return;
  }
  
  try {
    // Create payment document in Firestore
    final payRef = await FirebaseFirestore.instance
        .collection('payments')
        .add({
      'uid': user!.uid,
      'amount': amount,
      'utr': utr,
      'status': 'SUBMITTED',  // Waiting for admin verification
      'created_at': FieldValue.serverTimestamp(),
      'house_no': userData['house_no'],
      'method': method,
      'note': noteCtrl.text.trim(),
      'invoice_type': widget.invoiceType ?? 'MAINTENANCE',
      'purpose': widget.invoiceTitle ?? 'Monthly Maintenance',
      if (widget.invoiceId != null) 'invoice_id': widget.invoiceId,
    });
    
    // Upload proof image if selected
    final proofUrl = await _uploadProofIfAny(payRef.id);
    if (proofUrl != null) {
      await payRef.update({'proof_url': proofUrl});
    }
    
    _showSnack('Payment submitted ✅ Waiting for admin verification');
  } catch (e) {
    _showSnack('Failed: $e', isError: true);
  }
}

// Upload proof image to Firebase Storage
Future<String?> _uploadProofIfAny(String paymentDocId) async {
  if (proofImage == null || user == null) return null;
  
  setState(() => uploadingProof = true);
  try {
    final ref = FirebaseStorage.instance
        .ref()
        .child('proofs')
        .child(user!.uid)
        .child('$paymentDocId.jpg');
    
    await ref.putFile(proofImage!);
    return await ref.getDownloadURL();
  } finally {
    if (mounted) setState(() => uploadingProof = false);
  }
}
```

### Admin Verifies Payment (admin/admin_pay_screen.dart)
```dart
// Admin calls Cloud Function to verify payment
Future<void> _verifyPayment(String paymentId, String invoiceId) async {
  try {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/verifyPaymentManualHttp'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _getAuthToken()}',
      },
      body: jsonEncode({
        'paymentId': paymentId,
        'invoiceId': invoiceId,
      }),
    );
    
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['ok'] == true) {
      _showSnack('Payment verified ✅', success: true);
      // Refresh list
      setState(() {});
    } else {
      _showSnack('Error: ${data['error']['message']}');
    }
  } catch (e) {
    _showSnack('Failed: $e');
  }
}
```

---

## 3. Cloud Functions: Invoice Generation

### Scheduled Monthly Invoice Generation (functions/index.js)
```javascript
// Runs automatically on 1st of every month at 00:05 IST
exports.generateMonthlyInvoices = onSchedule(
  { schedule: "5 0 1 * *", timeZone: "Asia/Kolkata" },
  async () => {
    const db = admin.firestore();
    
    // Generate for current month
    const monthKey = '2026-05';
    
    // Check if already generated (idempotent)
    const existing = await db.collection("invoices")
      .where("month", "==", monthKey)
      .limit(1)
      .get();
    
    if (!existing.empty) {
      console.log(`Invoices for ${monthKey} already exist — skipping.`);
      return;
    }
    
    // Fetch all residents
    const usersSnap = await db.collection("users")
      .where("role", "==", "user")
      .get();
    
    // Batch create invoices (Firestore batch limit = 500)
    let batch = db.batch();
    let count = 0;
    let batchCount = 0;
    
    for (const userDoc of usersSnap.docs) {
      const u = userDoc.data();
      const ref = db.collection("invoices").doc();
      
      batch.set(ref, {
        uid: userDoc.id,
        house_no: u.house_no || "",
        name: u.name || "",
        email: u.email || "",
        month: monthKey,
        amount: 1500,           // Fixed monthly amount
        paid_amount: 0,
        status: "UNPAID",
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      count++;
      batchCount++;
      
      // Commit batch every 400 docs (stay under 500 limit)
      if (batchCount === 400) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    }
    
    // Commit remaining
    if (batchCount > 0) {
      await batch.commit();
    }
    
    console.log(`Generated ${count} invoices for ${monthKey}.`);
    
    // Notify all residents via FCM
    try {
      const tokens = await getAllResidentFcmTokens(db);
      const label = `April 2026`;
      await sendFcmMulticast(
        tokens,
        `🏠 Maintenance Due — ${label}`,
        `Your monthly maintenance invoice of ₹1500 has been generated.`,
        { type: "INVOICE_GENERATED", month: monthKey }
      );
    } catch (fcmErr) {
      console.error("[FCM error]:", fcmErr.message);
    }
  }
);
```

### Manual Invoice Generation (callable function)
```javascript
exports.generateInvoicesManual = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const db = admin.firestore();
    
    // Check if user is admin
    await requireAdminFromRequest(db, request);
    
    // Allow targeting specific month or default to current
    const targetMonth = request.data?.month || monthKey();
    
    // Call the core function
    const result = await _generateInvoicesForMonth(db, targetMonth);
    return result;
  }
);
```

---

## 4. Admin Creating Residents

### Create Resident HTTP Function (functions/index.js)
```javascript
exports.createResidentHttp = onRequest(
  { cors: true },
  async (req, res) => {
    try {
      const db = admin.firestore();
      
      // Verify admin auth
      const authCtx = await resolveAuthContext({ auth: req.auth, data: req.body });
      const user = await db.collection("users").doc(authCtx.uid).get();
      
      if (!user.exists || user.data().role !== "admin") {
        return res.status(403).json({ error: { message: "Admin only" } });
      }
      
      const { name, email, phone, houseNo } = req.body;
      
      // Validate inputs
      if (!name || !email || !houseNo) {
        return res.status(400).json({
          error: { message: "Missing required fields" }
        });
      }
      
      // Generate temporary password
      const tempPassword = crypto.randomBytes(8).toString("hex");
      
      // Create Firebase Auth account
      const newUser = await admin.auth().createUser({
        email: email.toLowerCase(),
        password: tempPassword,
        displayName: name,
      });
      
      // Create Firestore user document
      await db.collection("users").doc(newUser.uid).set({
        email: email.toLowerCase(),
        name: name,
        house_no: houseNo,
        phone: phone || "",
        role: "user",
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Send welcome email with temp password
      let emailSent = false;
      try {
        const mailTransporter = nodemailer.createTransport({
          host: process.env.SMTP_HOST,
          port: process.env.SMTP_PORT,
          auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS,
          },
        });
        
        await mailTransporter.sendMail({
          from: process.env.SMTP_FROM,
          to: email,
          subject: "Welcome to RWA Manager",
          html: `
            <p>Hello ${name},</p>
            <p>Your account has been created successfully.</p>
            <p><strong>Email:</strong> ${email}</p>
            <p><strong>Temporary Password:</strong> ${tempPassword}</p>
            <p>Please log in and change your password immediately.</p>
            <p>Best regards,<br>RWA Management</p>
          `,
        });
        emailSent = true;
      } catch (emailErr) {
        console.error("[Email error]:", emailErr.message);
      }
      
      res.json({
        ok: true,
        uid: newUser.uid,
        tempPassword: tempPassword,
        emailSent: emailSent,
      });
    } catch (error) {
      console.error("[createResidentHttp] error:", error);
      res.status(500).json({
        error: {
          code: error.code,
          message: error.message,
        }
      });
    }
  }
);
```

### Admin Adding Resident (admin/members_screen.dart)
```dart
Future<void> _createResident(Map<String, String> data) async {
  final adminUser = FirebaseAuth.instance.currentUser;
  final token = await adminUser?.getIdToken(true);
  
  final response = await http.post(
    Uri.parse('${AppConfig.baseUrl}/createResidentHttp'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'name': data['name'],
      'email': data['email'],
      'phone': data['phone'],
      'houseNo': data['houseNo'],
    }),
  );
  
  final body = jsonDecode(response.body);
  
  if (response.statusCode != 200) {
    final err = body['error'] ?? {};
    throw Exception(err['message'] ?? 'Failed to create resident');
  }
  
  // Show success dialog with temp password
  if (mounted) {
    await _showCreatedDialog(
      name: data['name']!,
      email: data['email']!,
      houseNo: data['houseNo']!,
      tempPassword: body['tempPassword'] ?? '',
      emailSent: body['emailSent'] == true,
    );
  }
}
```

---

## 5. Push Notifications (FCM)

### Initialize Notifications Service (services/notification_service.dart)
```dart
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
    
    // Create Android notification channel
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            'rwa_channel',
            'RWA Notifications',
            description: 'Society dues, notices, complaints',
            importance: Importance.high,
          ),
        );
    
    // Initialize local notifications plugin
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    
    // Request permission (critical on iOS)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Show notifications while app is in foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
    
    // Save FCM token when user is signed in
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) saveToken();
    });
    
    // Refresh token when it rotates
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => saveToken());
  }
  
  // Show local notification while app is in foreground
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    
    await _plugin.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'rwa_channel',
          'RWA Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
  
  // Save FCM token to Firestore for this user
  static Future<void> saveToken([String? token]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      token ??= await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcm_token': token}, SetOptions(merge: true));
      
      debugPrint('[FCM] Token saved for uid=${user.uid}');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }
  
  // Clear token on logout
  static Future<void> clearToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcm_token': FieldValue.delete()});
      
      debugPrint('[FCM] Token cleared');
    } catch (e) {
      debugPrint('[FCM] Failed to clear token: $e');
    }
  }
}
```

### Send FCM Notification (functions/index.js)
```javascript
// Get all resident FCM tokens
async function getAllResidentFcmTokens(db) {
  const usersSnap = await db.collection("users")
    .where("role", "==", "user")
    .select("fcm_token")
    .get();
  
  const tokens = [];
  for (const doc of usersSnap.docs) {
    const token = doc.data().fcm_token;
    if (token) tokens.push(token);
  }
  return tokens;
}

// Send FCM multicast (to multiple users)
async function sendFcmMulticast(tokens, title, body, data = {}) {
  if (tokens.length === 0) return;
  
  const message = {
    notification: { title, body },
    data: data,
  };
  
  // Split into chunks (max 500 per request)
  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    const resp = await admin.messaging().sendMulticast({
      tokens: chunk,
      ...message,
    });
    
    console.log(`[FCM] Sent to ${resp.successCount} users, ${resp.failureCount} failed`);
  }
}

// Usage in Cloud Function
await sendFcmMulticast(
  allTokens,
  "🏠 Maintenance Due — April 2026",
  "Your monthly maintenance invoice of ₹1500 has been generated.",
  { type: "INVOICE_GENERATED", month: "2026-04" }
);
```

---

## 6. PDF Generation & Sharing

### Generate Payment Receipt (user/receipt_pdf_service.dart)
```dart
class ReceiptPdfService {
  static Future<File> generateReceipt({
    required String paymentId,
    required String residentName,
    required String houseNo,
    required int amount,
    required String method,
    required String purpose,
    required DateTime date,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Text(
              'PAYMENT RECEIPT',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Receipt details
            pw.Text('Receipt No: ${paymentId.substring(0, 8).toUpperCase()}'),
            pw.Text('Date: ${DateFormat('dd MMM yyyy').format(date)}'),
            pw.SizedBox(height: 10),
            
            // Resident info
            pw.Text('Resident: $residentName'),
            pw.Text('House No: $houseNo'),
            pw.SizedBox(height: 10),
            
            // Payment details
            pw.Text('Purpose: $purpose'),
            pw.Text('Method: $method'),
            pw.Text('Amount: ₹$amount'),
            pw.SizedBox(height: 20),
            
            // Footer
            pw.Text(
              'Payment verified and approved by Admin',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    );
    
    // Save to device
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/receipt_$paymentId.pdf');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
  
  // Share PDF with other apps
  static Future<void> sharePdf(File file, String fileName) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Payment Receipt',
      text: 'Your payment receipt from RWA Manager',
    );
  }
  
  // Open PDF in viewer
  static Future<void> openPdf(File file) async {
    await OpenFilex.open(file.path);
  }
}
```

---

## 7. Firestore Queries

### Get Invoices for a Month
```dart
// Get all invoices for a specific month
Future<List<DocumentSnapshot>> getInvoicesForMonth(String month) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('invoices')
      .where('month', isEqualTo: month)
      .orderBy('house_no')
      .get();
  
  return snapshot.docs;
}

// Get resident's own invoices
Future<List<DocumentSnapshot>> getMyInvoices(String uid) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('invoices')
      .where('uid', isEqualTo: uid)
      .orderBy('month', descending: true)
      .get();
  
  return snapshot.docs;
}
```

### Get Payments for Verification
```dart
// Admin: Get all pending payments
Future<List<DocumentSnapshot>> getPendingPayments() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('payments')
      .where('status', isEqualTo: 'SUBMITTED')
      .orderBy('created_at', descending: true)
      .get();
  
  return snapshot.docs;
}

// Resident: Get own payment history
Future<List<DocumentSnapshot>> getMyPayments(String uid) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('payments')
      .where('uid', isEqualTo: uid)
      .orderBy('created_at', descending: true)
      .get();
  
  return snapshot.docs;
}
```

### Real-time Listener for Notices
```dart
// Listen to all notices in real-time
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('notices')
      .orderBy('created_at', descending: true)
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final notices = snapshot.data!.docs;
      return ListView.builder(
        itemCount: notices.length,
        itemBuilder: (context, index) {
          final notice = notices[index];
          return NoticeCard(
            title: notice['title'],
            content: notice['content'],
            date: notice['created_at'],
          );
        },
      );
    }
    return const CircularProgressIndicator();
  },
)
```

---

## 8. Error Handling & Logging

### Try-Catch with User Feedback
```dart
Future<void> performAction() async {
  try {
    setState(() => isLoading = true);
    
    // Perform action
    final result = await someAsyncOperation();
    
    // Show success
    _showSnack('Action completed ✅', success: true);
  } on FirebaseAuthException catch (e) {
    _showSnack('Auth Error: ${e.message}');
  } on FirebaseException catch (e) {
    _showSnack('Firebase Error: ${e.message}');
  } catch (e) {
    _showSnack('Error: $e');
    debugPrint(e.toString());
  } finally {
    setState(() => isLoading = false);
  }
}

void _showSnack(String message, {bool success = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
```

---

## 9. Admin Confirmation Dialogs

### Delete Resident Confirmation
```dart
Future<void> _deleteResident(String userId, String name) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete Resident',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Are you sure you want to delete "$name"?\n\n'
        'This will permanently remove their account and login access. '
        'Their payment history will remain.',
        style: const TextStyle(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  
  if (confirmed != true) return;
  
  // Call Cloud Function to delete
  try {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/deleteResidentHttp'),
      headers: {
        'Authorization': 'Bearer ${await _getAuthToken()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'userId': userId}),
    );
    
    if (response.statusCode == 200) {
      _showSnack('✅ $name has been removed', success: true);
    } else {
      _showSnack('Failed to delete resident');
    }
  } catch (e) {
    _showSnack('Error: $e');
  }
}
```

---

## 10. Theme & Styling

### App Theme (theme/app_theme.dart)
```dart
class AppTheme {
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  // Card decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: cardShadow,
  );
  
  // Input styling
  static InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.primaryLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
  
  // Gradient button
  static Widget gradientButton({
    required String label,
    required VoidCallback? onTap,
    double height = 52,
    IconData? icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: onTap == null
                ? const LinearGradient(
                    colors: [Color(0xFFCBD5E1), Color(0xFFCBD5E1)])
                : primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          height: height,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

*These code examples demonstrate the key patterns and practices used throughout the RWA Manager app.*
