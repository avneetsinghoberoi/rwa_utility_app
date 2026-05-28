import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:gate_basic/models/poll.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'package:gate_basic/utils/admin_dashboard_key.dart';

class AdminPollsScreen extends StatefulWidget {
  const AdminPollsScreen({super.key});

  @override
  State<AdminPollsScreen> createState() => _AdminPollsScreenState();
}

class _AdminPollsScreenState extends State<AdminPollsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<Poll>> _pollsStream(String status) {
    return FirebaseFirestore.instance
        .collection('polls')
        .where('status', isEqualTo: status)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Poll.fromDoc).toList());
  }

  Future<void> _closePoll(Poll poll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close Poll'),
        content: Text('Close "${poll.title}"? Residents will no longer be able to vote.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Close Poll', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('polls')
        .doc(poll.id)
        .update({'status': 'closed', 'closed_at': FieldValue.serverTimestamp()});
  }

  Future<void> _deletePoll(Poll poll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Poll'),
        content: Text('Permanently delete "${poll.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseFirestore.instance.collection('polls').doc(poll.id).delete();
  }

  void _openCreatePollSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CreatePollSheet(),
    );
  }

  void _openPollResults(Poll poll) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _PollResultsScreen(poll: poll)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => adminDashboardScaffoldKey.currentState?.openDrawer(),
              ),
        actions: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => adminDashboardScaffoldKey.currentState?.openDrawer(),
            ),
        ],
        title: const Text(
          'Community Polls',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Closed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePollSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Poll', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PollList(
            stream: _pollsStream('active'),
            status: 'active',
            onClose: _closePoll,
            onDelete: _deletePoll,
            onTap: _openPollResults,
          ),
          _PollList(
            stream: _pollsStream('closed'),
            status: 'closed',
            onClose: _closePoll,
            onDelete: _deletePoll,
            onTap: _openPollResults,
          ),
        ],
      ),
    );
  }
}

// ── Poll List ────────────────────────────────────────────────────────────────
class _PollList extends StatelessWidget {
  final Stream<List<Poll>> stream;
  final String status;
  final Future<void> Function(Poll) onClose;
  final Future<void> Function(Poll) onDelete;
  final void Function(Poll) onTap;

  const _PollList({
    required this.stream,
    required this.status,
    required this.onClose,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Poll>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final polls = snap.data ?? [];
        if (polls.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.how_to_vote_outlined,
                    size: 56, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(
                  status == 'active'
                      ? 'No active polls.\nTap + to create one.'
                      : 'No closed polls yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: polls.length,
          itemBuilder: (_, i) => _AdminPollCard(
            poll: polls[i],
            onClose: onClose,
            onDelete: onDelete,
            onTap: onTap,
          ),
        );
      },
    );
  }
}

// ── Admin Poll Card ──────────────────────────────────────────────────────────
class _AdminPollCard extends StatelessWidget {
  final Poll poll;
  final Future<void> Function(Poll) onClose;
  final Future<void> Function(Poll) onDelete;
  final void Function(Poll) onTap;

  const _AdminPollCard({
    required this.poll,
    required this.onClose,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = poll.isActive;
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => onTap(poll),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header band
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.how_to_vote_rounded
                        : Icons.how_to_vote_outlined,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'ACTIVE' : 'CLOSED',
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  // Live vote count from subcollection
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('polls')
                        .doc(poll.id)
                        .collection('votes')
                        .snapshots(),
                    builder: (_, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      return Text(
                        '$count vote${count != 1 ? 's' : ''}',
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                poll.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary),
              ),
            ),
            if (poll.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  poll.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            // Options summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                poll.options.map((o) => o.text).join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
            if (poll.endsAt != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 13, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      isActive
                          ? 'Ends ${DateFormat('dd MMM yyyy').format(poll.endsAt!)}'
                          : 'Ended ${DateFormat('dd MMM yyyy').format(poll.endsAt!)}',
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => onTap(poll),
                    icon: const Icon(Icons.bar_chart_rounded, size: 16),
                    label: const Text('View Results'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  if (isActive)
                    TextButton.icon(
                      onPressed: () => onClose(poll),
                      icon: const Icon(Icons.lock_outline_rounded, size: 16),
                      label: const Text('Close'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  TextButton.icon(
                    onPressed: () => onDelete(poll),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create Poll Sheet ────────────────────────────────────────────────────────
class _CreatePollSheet extends StatefulWidget {
  const _CreatePollSheet();

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionCtrls.length >= 8) return;
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionCtrls.length <= 2) return;
    setState(() {
      _optionCtrls[index].dispose();
      _optionCtrls.removeAt(index);
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _endsAt = picked);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a poll title.')),
      );
      return;
    }

    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least 2 options.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final pollOptions = options.asMap().entries.map((e) {
        return PollOption(
          id: 'opt_${e.key}',
          text: e.value,
          voteCount: 0,
        );
      }).toList();

      final poll = Poll(
        id: '',
        title: title,
        description: _descCtrl.text.trim(),
        options: pollOptions,
        status: 'active',
        createdAt: DateTime.now(),
        endsAt: _endsAt,
        totalVotes: 0,
        createdBy: uid,
      );

      await FirebaseFirestore.instance.collection('polls').add(poll.toMap());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
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
            const Text(
              'Create New Poll',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),

            // Title
            _label('Question / Title *'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: _inputDeco('e.g. Should we hire a new security guard?'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Description
            _label('Description (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              decoration: _inputDeco('Provide more context for residents...'),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),

            // Options
            Row(
              children: [
                _label('Options *'),
                const Spacer(),
                if (_optionCtrls.length < 8)
                  TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Option'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < _optionCtrls.length; i++) ...[
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _optionCtrls[i],
                      decoration: _inputDeco('Option ${i + 1}'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  if (_optionCtrls.length > 2)
                    IconButton(
                      onPressed: () => _removeOption(i),
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          color: AppColors.error, size: 20),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),

            // End date (optional)
            _label('End Date (optional)'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickEndDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      _endsAt == null
                          ? 'No end date (close manually)'
                          : DateFormat('dd MMMM yyyy').format(_endsAt!),
                      style: TextStyle(
                        color: _endsAt == null
                            ? AppColors.textHint
                            : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (_endsAt != null)
                      GestureDetector(
                        onTap: () => setState(() => _endsAt = null),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textHint),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Create Poll',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}

// ── Poll Results Screen ──────────────────────────────────────────────────────
// Counts votes live from the votes subcollection so no poll-document writes
// are needed from the client (residents only write their own vote document).
class _PollResultsScreen extends StatelessWidget {
  final Poll poll;

  const _PollResultsScreen({required this.poll});

  Color _barColor(int index) {
    const colors = [
      AppColors.primary,
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFF06B6D4),
      Color(0xFFF97316),
      Color(0xFFEC4899),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    // Stream the poll document (for status / title changes) AND the votes
    // subcollection (for live counts) in parallel.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('polls')
          .doc(poll.id)
          .snapshots(),
      builder: (context, pollSnap) {
        final livePoll = pollSnap.hasData && pollSnap.data!.exists
            ? Poll.fromDoc(pollSnap.data!)
            : poll;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            surfaceTintColor: Colors.white,
            title: const Text('Poll Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('polls')
                .doc(poll.id)
                .collection('votes')
                .snapshots(),
            builder: (context, votesSnap) {
              final votes = votesSnap.data?.docs ?? [];

              // Count votes per option from the subcollection
              final counts = <String, int>{};
              for (final v in votes) {
                final optId = (v.data() as Map<String, dynamic>)['option_id']
                        ?.toString() ??
                    '';
                if (optId.isNotEmpty) {
                  counts[optId] = (counts[optId] ?? 0) + 1;
                }
              }
              final total = votes.length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status + date
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: livePoll.isActive
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.gray100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            livePoll.isActive ? 'ACTIVE' : 'CLOSED',
                            style: TextStyle(
                              color: livePoll.isActive
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Created ${DateFormat('dd MMM yyyy').format(livePoll.createdAt)}',
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      livePoll.title,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    if (livePoll.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        livePoll.description,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Total votes: $total',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),

                    // Results bars — counts from subcollection
                    ...livePoll.options.asMap().entries.map((entry) {
                      final i = entry.key;
                      final opt = entry.value;
                      final voteCount = counts[opt.id] ?? 0;
                      final pct = total > 0 ? voteCount / total : 0.0;
                      final color = _barColor(i);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    opt.text,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.textPrimary),
                                  ),
                                ),
                                Text(
                                  '$voteCount vote${voteCount != 1 ? 's' : ''}',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${(pct * 100).toStringAsFixed(1)}%)',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: pct.toDouble(),
                                minHeight: 10,
                                backgroundColor: color.withOpacity(0.12),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    if (livePoll.endsAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 14, color: AppColors.textHint),
                          const SizedBox(width: 6),
                          Text(
                            livePoll.isActive
                                ? 'Closes ${DateFormat('dd MMM yyyy').format(livePoll.endsAt!)}'
                                : 'Closed ${DateFormat('dd MMM yyyy').format(livePoll.endsAt!)}',
                            style: const TextStyle(
                                color: AppColors.textHint, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
