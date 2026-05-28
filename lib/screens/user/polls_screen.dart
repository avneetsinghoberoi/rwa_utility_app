import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:gate_basic/models/poll.dart';
import 'package:gate_basic/theme/app_theme.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen>
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Community Polls',
          style: TextStyle(
            fontSize: 20,
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
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PollsTab(filterStatus: 'active'),
          _PollsTab(filterStatus: 'closed'),
        ],
      ),
    );
  }
}

// ── Polls Tab ────────────────────────────────────────────────────────────────
class _PollsTab extends StatelessWidget {
  final String filterStatus;

  const _PollsTab({required this.filterStatus});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('polls')
          .where('status', isEqualTo: filterStatus)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final polls = (snap.data?.docs ?? []).map(Poll.fromDoc).toList();

        if (polls.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  filterStatus == 'active'
                      ? Icons.how_to_vote_outlined
                      : Icons.lock_outline_rounded,
                  size: 56,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 12),
                Text(
                  filterStatus == 'active'
                      ? 'No active polls right now.\nCheck back later!'
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: polls.length,
          itemBuilder: (_, i) => _UserPollCard(poll: polls[i]),
        );
      },
    );
  }
}

// ── User Poll Card ───────────────────────────────────────────────────────────
class _UserPollCard extends StatefulWidget {
  final Poll poll;

  const _UserPollCard({required this.poll});

  @override
  State<_UserPollCard> createState() => _UserPollCardState();
}

class _UserPollCardState extends State<_UserPollCard> {
  String? _myVoteOptionId;
  bool _loadingVote = true;
  bool _submitting = false;
  String? _selectedOptionId;
  bool _hasVoted = false;

  @override
  void initState() {
    super.initState();
    _loadMyVote();
  }

  Future<void> _loadMyVote() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingVote = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('polls')
          .doc(widget.poll.id)
          .collection('votes')
          .doc(uid)
          .get();
      if (mounted) {
        setState(() {
          _loadingVote = false;
          if (doc.exists) {
            _myVoteOptionId = doc.data()?['option_id']?.toString();
            _hasVoted = true;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVote = false);
    }
  }

  Future<void> _castVote() async {
    if (_selectedOptionId == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (!widget.poll.isEffectivelyActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This poll is no longer active.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Fetch user info for vote metadata (outside transaction — read-only)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data() ?? {};
      final houseNo = userData['house_no']?.toString() ?? '';
      final userName = userData['name']?.toString() ?? '';

      final voteRef = FirebaseFirestore.instance
          .collection('polls')
          .doc(widget.poll.id)
          .collection('votes')
          .doc(uid);

      // Use a transaction only to enforce the "one vote per user" check atomically.
      // We do NOT update the poll document here — residents don't have write
      // permission on the polls collection. Vote counts are computed live from
      // the votes subcollection when displaying results.
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final voteSnap = await txn.get(voteRef);
        if (voteSnap.exists) throw Exception('Already voted');

        txn.set(voteRef, PollVote(
          optionId: _selectedOptionId!,
          votedAt: DateTime.now(),
          houseNo: houseNo,
          userName: userName,
        ).toMap());
      });

      if (mounted) {
        setState(() {
          _myVoteOptionId = _selectedOptionId;
          _hasVoted = true;
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote cast successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('Already voted')
                ? 'You have already voted on this poll.'
                : 'Error casting vote. Please try again.'),
          ),
        );
      }
    }
  }

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
    final poll = widget.poll;
    final canVote = !_hasVoted && poll.isEffectivelyActive && !_loadingVote;
    final showResults = _hasVoted || !poll.isEffectivelyActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          _PollHeader(poll: poll),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              poll.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          if (poll.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                poll.description,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ),

          if (poll.endsAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.schedule_outlined,
                      size: 13, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    poll.isEffectivelyActive
                        ? 'Ends ${DateFormat('dd MMM yyyy').format(poll.endsAt!)}'
                        : 'Ended ${DateFormat('dd MMM yyyy').format(poll.endsAt!)}',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 12),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          if (_loadingVote)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (showResults)
            // ── Live results from votes subcollection ──────────────
            _LiveResults(
              pollId: poll.id,
              options: poll.options,
              myVoteOptionId: _myVoteOptionId,
              colorFn: _barColor,
            )
          else
            // ── Voting UI ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...poll.options.asMap().entries.map((entry) {
                    final i = entry.key;
                    final opt = entry.value;
                    final isSelected = _selectedOptionId == opt.id;
                    final color = _barColor(i);

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedOptionId = opt.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected ? color : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? color
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 13)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                opt.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? color
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed:
                          (_selectedOptionId != null && !_submitting)
                              ? _castVote
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Cast Vote',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Poll Header (streams live vote count from subcollection) ─────────────────
class _PollHeader extends StatelessWidget {
  final Poll poll;
  const _PollHeader({required this.poll});

  @override
  Widget build(BuildContext context) {
    final isActive = poll.isEffectivelyActive;
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('polls')
          .doc(poll.id)
          .collection('votes')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(
            children: [
              Icon(
                isActive
                    ? Icons.how_to_vote_rounded
                    : Icons.lock_outline_rounded,
                color: color,
                size: 18,
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
                  isActive ? 'OPEN' : 'CLOSED',
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text(
                '$count vote${count != 1 ? 's' : ''}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Live Results (streams votes subcollection and counts per option) ──────────
class _LiveResults extends StatelessWidget {
  final String pollId;
  final List<PollOption> options;
  final String? myVoteOptionId;
  final Color Function(int) colorFn;

  const _LiveResults({
    required this.pollId,
    required this.options,
    required this.myVoteOptionId,
    required this.colorFn,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('polls')
          .doc(pollId)
          .collection('votes')
          .snapshots(),
      builder: (context, snap) {
        final votes = snap.data?.docs ?? [];
        final counts = <String, int>{};
        for (final v in votes) {
          final optId =
              (v.data() as Map<String, dynamic>)['option_id']?.toString() ??
                  '';
          if (optId.isNotEmpty) counts[optId] = (counts[optId] ?? 0) + 1;
        }
        final total = votes.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (myVoteOptionId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'You have voted',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ...options.asMap().entries.map((entry) {
                final i = entry.key;
                final opt = entry.value;
                final voteCount = counts[opt.id] ?? 0;
                final pct = total > 0 ? voteCount / total : 0.0;
                final isMyVote = opt.id == myVoteOptionId;
                final color = colorFn(i);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMyVote
                        ? color.withOpacity(0.08)
                        : AppColors.gray50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMyVote
                          ? color.withOpacity(0.35)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isMyVote)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.check_circle_rounded,
                                  color: color, size: 16),
                            ),
                          Expanded(
                            child: Text(
                              opt.text,
                              style: TextStyle(
                                fontWeight: isMyVote
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct.toDouble(),
                          minHeight: 7,
                          backgroundColor: color.withOpacity(0.12),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$voteCount vote${voteCount != 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: AppColors.textHint, fontSize: 11),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
