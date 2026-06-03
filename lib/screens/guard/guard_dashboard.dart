import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'package:gate_basic/screens/login/login_screen.dart';

class GuardDashboard extends StatefulWidget {
  const GuardDashboard({super.key});

  @override
  State<GuardDashboard> createState() => _GuardDashboardState();
}

class _GuardDashboardState extends State<GuardDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    _QrScannerTab(),
    _ManualEntryTab(),
    _TodayLogsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Guard Portal',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded,
                color: AppColors.primary),
            label: 'Scan QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon:
                Icon(Icons.edit_note_rounded, color: AppColors.primary),
            label: 'Log Entry',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon:
                Icon(Icons.list_alt_rounded, color: AppColors.primary),
            label: "Today's Log",
          ),
        ],
      ),
    );
  }
}

// ── QR Scanner Tab ───────────────────────────────────────────────────────────
class _QrScannerTab extends StatefulWidget {
  const _QrScannerTab();

  @override
  State<_QrScannerTab> createState() => _QrScannerTabState();
}

class _QrScannerTabState extends State<_QrScannerTab> {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false, // don't open camera until guard taps the button
  );
  bool _cameraOpen = false; // camera stays closed until button tapped
  bool _scanning = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCamera() {
    setState(() {
      _cameraOpen = true;
      _scanning = true;
    });
    _controller.start();
  }

  void _closeCamera() {
    _controller.stop();
    setState(() {
      _cameraOpen = false;
      _scanning = false;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _scanning = false);
    _controller.stop();
    _showResultSheet(raw);
  }

  void _showResultSheet(String raw) {
    // Try parsing as JSON (resident QR format)
    Map<String, dynamic>? parsed;
    try {
      parsed = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      parsed = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _QrResultSheet(
        rawValue: raw,
        parsed: parsed,
        onLogEntry: () {
          Navigator.pop(context);
          _logQrEntry(parsed, raw);
        },
        onScanAgain: () {
          Navigator.pop(context);
          setState(() => _scanning = true);
          _controller.start(); // resume same camera session
        },
      ),
    );
  }

  Future<void> _logQrEntry(
      Map<String, dynamic>? parsed, String raw) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now = DateTime.now();

    await FirebaseFirestore.instance.collection('visitor_logs').add({
      'visitor_name': parsed?['name']?.toString() ?? 'Unknown',
      'vehicle_no': '',
      'apartment': parsed?['house_no']?.toString() ?? '',
      'phone': parsed?['phone']?.toString() ?? '',
      'entry_time': Timestamp.fromDate(now),
      'entry_type': 'qr_scan',
      'logged_by_uid': uid,
      'created_at': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry logged via QR scan.'),
          backgroundColor: AppColors.success,
        ),
      );
      // Return to the button screen after logging
      _closeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _cameraOpen ? _buildCameraView() : _buildIdleView();
  }

  // ── Idle screen: shown before guard taps the button ──────────────────────
  Widget _buildIdleView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 52,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scan Resident QR',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask the resident to show their QR code from the app, then tap the button below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _openCamera,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                label: const Text(
                  'Scan QR Code',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
    );
  }

  // ── Camera view: shown after guard taps the button ────────────────────────
  Widget _buildCameraView() {
    return Stack(
      children: [
        // Camera feed
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),

        // Top close bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black54,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _closeCamera,
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 24),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Point at a resident\'s QR code',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        // Viewfinder
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(
                  color: Colors.white.withOpacity(0.85), width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                for (final pos in [
                  Alignment.topLeft,
                  Alignment.topRight,
                  Alignment.bottomLeft,
                  Alignment.bottomRight,
                ])
                  Align(
                    alignment: pos,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        border: Border(
                          top: pos == Alignment.topLeft ||
                                  pos == Alignment.topRight
                              ? const BorderSide(
                                  color: AppColors.primary, width: 4)
                              : BorderSide.none,
                          bottom: pos == Alignment.bottomLeft ||
                                  pos == Alignment.bottomRight
                              ? const BorderSide(
                                  color: AppColors.primary, width: 4)
                              : BorderSide.none,
                          left: pos == Alignment.topLeft ||
                                  pos == Alignment.bottomLeft
                              ? const BorderSide(
                                  color: AppColors.primary, width: 4)
                              : BorderSide.none,
                          right: pos == Alignment.topRight ||
                                  pos == Alignment.bottomRight
                              ? const BorderSide(
                                  color: AppColors.primary, width: 4)
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Torch toggle
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: IconButton(
              onPressed: () => _controller.toggleTorch(),
              icon: const Icon(Icons.flashlight_on_rounded,
                  color: Colors.white, size: 32),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black38,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── QR Result Bottom Sheet ────────────────────────────────────────────────────
class _QrResultSheet extends StatelessWidget {
  final String rawValue;
  final Map<String, dynamic>? parsed;
  final VoidCallback onLogEntry;
  final VoidCallback onScanAgain;

  const _QrResultSheet({
    required this.rawValue,
    required this.parsed,
    required this.onLogEntry,
    required this.onScanAgain,
  });

  @override
  Widget build(BuildContext context) {
    final isResident = parsed != null &&
        parsed!.containsKey('house_no') &&
        parsed!.containsKey('name');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Result icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isResident
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isResident
                  ? Icons.check_circle_rounded
                  : Icons.qr_code_2_rounded,
              color: isResident ? AppColors.success : AppColors.warning,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            isResident ? 'Resident QR Verified' : 'QR Code Scanned',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Data card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: isResident
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dataRow(Icons.person_outline_rounded, 'Name',
                          parsed!['name']?.toString() ?? '-'),
                      const SizedBox(height: 10),
                      _dataRow(Icons.home_outlined, 'Apartment',
                          parsed!['house_no']?.toString() ?? '-'),
                      const SizedBox(height: 10),
                      _dataRow(Icons.phone_outlined, 'Phone',
                          parsed!['phone']?.toString() ?? '-'),
                    ],
                  )
                : Text(
                    rawValue,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onScanAgain,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Scan Again',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onLogEntry,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Log Entry',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Manual Entry Tab ─────────────────────────────────────────────────────────
class _ManualEntryTab extends StatefulWidget {
  const _ManualEntryTab();

  @override
  State<_ManualEntryTab> createState() => _ManualEntryTabState();
}

class _ManualEntryTabState extends State<_ManualEntryTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _apartmentCtrl = TextEditingController();
  DateTime _entryTime = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vehicleCtrl.dispose();
    _apartmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final picked = await showDateTimePicker(context, _entryTime);
    if (picked != null) setState(() => _entryTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance.collection('visitor_logs').add({
        'visitor_name': _nameCtrl.text.trim(),
        'vehicle_no': _vehicleCtrl.text.trim(),
        'apartment': _apartmentCtrl.text.trim(),
        'phone': '',
        'entry_time': Timestamp.fromDate(_entryTime),
        'entry_type': 'manual',
        'logged_by_uid': uid,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _nameCtrl.clear();
        _vehicleCtrl.clear();
        _apartmentCtrl.clear();
        setState(() {
          _entryTime = DateTime.now();
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visitor entry logged successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visitor Entry',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy  •  hh:mm a')
                            .format(DateTime.now()),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Visitor Name
            _fieldLabel('Visitor Name *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDeco(
                  hint: 'Full name of visitor',
                  icon: Icons.person_outline_rounded),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            // Apartment
            _fieldLabel('Going to Apartment *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _apartmentCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDeco(
                  hint: 'e.g. A-101, B-204',
                  icon: Icons.home_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Apartment is required' : null,
            ),
            const SizedBox(height: 16),

            // Vehicle Number
            _fieldLabel('Vehicle Number (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _vehicleCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDeco(
                  hint: 'e.g. MH 01 AB 1234',
                  icon: Icons.directions_car_outlined),
            ),
            const SizedBox(height: 16),

            // Entry Time
            _fieldLabel('Entry Time'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('dd MMM yyyy  •  hh:mm a')
                          .format(_entryTime),
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_outlined,
                        color: AppColors.textHint, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline_rounded,
                        size: 20),
                label: Text(
                  _saving ? 'Logging...' : 'Log Entry',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
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
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary),
      );

  InputDecoration _inputDeco(
          {required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
      );
}

// ── Today's Log Tab ──────────────────────────────────────────────────────────
class _TodayLogsTab extends StatelessWidget {
  const _TodayLogsTab();

  @override
  Widget build(BuildContext context) {
    // Start of today
    final todayStart = DateTime.now();
    final startOfDay = DateTime(
        todayStart.year, todayStart.month, todayStart.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('visitor_logs')
          .where('entry_time',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('entry_time', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];

        return Column(
          children: [
            // Summary strip
            Container(
              width: double.infinity,
              color: AppColors.primaryDark,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Today's visitors: ${docs.length}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd MMM yyyy').format(DateTime.now()),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            if (docs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.no_accounts_outlined,
                          size: 52, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      const Text(
                        'No entries logged today.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data =
                        docs[i].data() as Map<String, dynamic>;
                    return _LogCard(data: data);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Log Card ─────────────────────────────────────────────────────────────────
class _LogCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LogCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['visitor_name']?.toString() ?? '-';
    final apartment = data['apartment']?.toString() ?? '-';
    final vehicle = data['vehicle_no']?.toString() ?? '';
    final type = data['entry_type']?.toString() ?? 'manual';
    final ts = data['entry_time'];
    final time = ts is Timestamp
        ? DateFormat('hh:mm a').format(ts.toDate())
        : '-';
    final isQr = type == 'qr_scan';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Type icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isQr
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isQr
                  ? Icons.qr_code_scanner_rounded
                  : Icons.edit_note_rounded,
              color: isQr ? AppColors.primary : AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.home_outlined,
                        size: 12, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text(apartment,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    if (vehicle.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.directions_car_outlined,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(vehicle,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Time + type badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isQr
                      ? AppColors.primaryLight
                      : AppColors.successLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isQr ? 'QR' : 'Manual',
                  style: TextStyle(
                      color: isQr ? AppColors.primary : AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Date-Time Picker helper ──────────────────────────────────────────────────
Future<DateTime?> showDateTimePicker(
    BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(hours: 1)),
  );
  if (date == null) return null;

  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
