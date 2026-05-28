import 'package:cloud_firestore/cloud_firestore.dart';

// ── Poll Option ──────────────────────────────────────────────────────────────
class PollOption {
  final String id;
  final String text;
  final int voteCount;

  const PollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'vote_count': voteCount,
      };

  factory PollOption.fromMap(Map<String, dynamic> map) => PollOption(
        id: map['id']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        voteCount: (map['vote_count'] as num?)?.toInt() ?? 0,
      );

  PollOption copyWith({String? id, String? text, int? voteCount}) => PollOption(
        id: id ?? this.id,
        text: text ?? this.text,
        voteCount: voteCount ?? this.voteCount,
      );
}

// ── Poll ─────────────────────────────────────────────────────────────────────
class Poll {
  final String id;
  final String title;
  final String description;
  final List<PollOption> options;
  final String status; // 'active' | 'closed'
  final DateTime createdAt;
  final DateTime? endsAt;
  final int totalVotes;
  final String createdBy;

  const Poll({
    required this.id,
    required this.title,
    this.description = '',
    required this.options,
    this.status = 'active',
    required this.createdAt,
    this.endsAt,
    this.totalVotes = 0,
    this.createdBy = '',
  });

  bool get isActive => status == 'active';
  bool get isClosed => status == 'closed';

  /// Returns true if the poll has automatically expired (past endsAt).
  bool get isExpired =>
      endsAt != null && DateTime.now().isAfter(endsAt!) && status == 'active';

  /// Effective active state: admin hasn't closed it AND it hasn't expired.
  bool get isEffectivelyActive => isActive && !isExpired;

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'options': options.map((o) => o.toMap()).toList(),
        'status': status,
        'created_at': Timestamp.fromDate(createdAt),
        if (endsAt != null) 'ends_at': Timestamp.fromDate(endsAt!),
        'total_votes': totalVotes,
        'created_by': createdBy,
      };

  factory Poll.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Poll(
      id: doc.id,
      title: d['title']?.toString() ?? '',
      description: d['description']?.toString() ?? '',
      options: (d['options'] as List<dynamic>? ?? [])
          .map((o) => PollOption.fromMap(Map<String, dynamic>.from(o as Map)))
          .toList(),
      status: d['status']?.toString() ?? 'active',
      createdAt: d['created_at'] is Timestamp
          ? (d['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      endsAt: d['ends_at'] is Timestamp
          ? (d['ends_at'] as Timestamp).toDate()
          : null,
      totalVotes: (d['total_votes'] as num?)?.toInt() ?? 0,
      createdBy: d['created_by']?.toString() ?? '',
    );
  }
}

// ── Poll Vote ────────────────────────────────────────────────────────────────
class PollVote {
  final String optionId;
  final DateTime votedAt;
  final String houseNo;
  final String userName;

  const PollVote({
    required this.optionId,
    required this.votedAt,
    this.houseNo = '',
    this.userName = '',
  });

  Map<String, dynamic> toMap() => {
        'option_id': optionId,
        'voted_at': Timestamp.fromDate(votedAt),
        'house_no': houseNo,
        'user_name': userName,
      };

  factory PollVote.fromMap(Map<String, dynamic> map) => PollVote(
        optionId: map['option_id']?.toString() ?? '',
        votedAt: map['voted_at'] is Timestamp
            ? (map['voted_at'] as Timestamp).toDate()
            : DateTime.now(),
        houseNo: map['house_no']?.toString() ?? '',
        userName: map['user_name']?.toString() ?? '',
      );
}
