import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String profilePhoto;
  final String role; // 'admin' | 'resident' (no more 'tenant')
  final UnitInfo unitInfo;
  final AccountLink accountLink;
  final List<String> flatMembers; // All user UIDs on this flat
  final String status; // 'active' | 'inactive' | 'removed'
  final DateTime createdAt;

  User({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.profilePhoto,
    required this.role,
    required this.unitInfo,
    required this.accountLink,
    required this.flatMembers,
    this.status = 'active',
    required this.createdAt,
  });

  // ✅ Computed Properties
  bool get isAdmin => role == 'admin';
  bool get isResident => role == 'resident';

  /// Is this user the primary account owner (not linked to anyone)
  bool get isAccountOwner => accountLink.primaryOwnerUid == null;

  /// Is this user linked to another account
  bool get isLinkedUser => accountLink.primaryOwnerUid != null;

  /// Get the primary owner's UID (self if owner, other's uid if linked)
  String get accountOwnerUid => accountLink.primaryOwnerUid ?? uid;

  /// Can this user manage (add/remove) flat members
  bool get canManageFlatMembers => isAccountOwner;

  /// How many other people have access to this flat account
  int get flatMemberCount => flatMembers.length;

  /// Get other members (excluding self)
  List<String> get otherFlatMembers =>
      flatMembers.where((uid) => uid != this.uid).toList();

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'profile_photo': profilePhoto,
      'role': role,
      // Keep top-level house_no so UserHomeScreen/PayScreen can query invoices & payments
      'house_no': unitInfo.houseNo,
      'unit_info': unitInfo.toMap(),
      'account_link': accountLink.toMap(),
      'flat_members': flatMembers,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.now(),
    };
  }

  // Create from Firestore document
  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Admin-created residents store house_no at top level (no unit_info).
    // Account-sharing users store it inside unit_info.
    // Fall back to top-level house_no so both layouts work correctly.
    final topLevelHouseNo = data['house_no']?.toString() ?? '';
    final rawUnitInfo = (data['unit_info'] as Map<String, dynamic>?) ?? {};
    final resolvedUnitInfo = {
      'house_no': rawUnitInfo['house_no'] ?? topLevelHouseNo,
      'flat_no': rawUnitInfo['flat_no'] ?? topLevelHouseNo,
      'wing': rawUnitInfo['wing'] ?? '',
      'building': rawUnitInfo['building'] ?? '',
    };

    return User(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      profilePhoto: data['profile_photo'] ?? '',
      role: data['role'] ?? 'resident',
      unitInfo: UnitInfo.fromMap(resolvedUnitInfo),
      accountLink: AccountLink.fromMap(data['account_link'] ?? {}),
      flatMembers: List<String>.from(data['flat_members'] ?? [doc.id]),
      status: data['status'] ?? 'active',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  String toString() => 'User(uid: $uid, name: $name, role: $role, isOwner: $isAccountOwner)';
}

/// Unit information (flat/house details)
class UnitInfo {
  final String houseNo;
  final String flatNo;
  final String wing;
  final String building;

  UnitInfo({
    required this.houseNo,
    required this.flatNo,
    required this.wing,
    required this.building,
  });

  Map<String, dynamic> toMap() {
    return {
      'house_no': houseNo,
      'flat_no': flatNo,
      'wing': wing,
      'building': building,
    };
  }

  factory UnitInfo.fromMap(Map<String, dynamic> map) {
    return UnitInfo(
      houseNo: map['house_no'] ?? '',
      flatNo: map['flat_no'] ?? '',
      wing: map['wing'] ?? '',
      building: map['building'] ?? '',
    );
  }

  @override
  String toString() => '$building - $wing/$flatNo';
}

/// Account linking information
class AccountLink {
  /// If null = this user is the primary account owner
  /// If not null = linked to this owner's account
  final String? primaryOwnerUid;

  /// How is this user linked: 'owner' | 'spouse' | 'tenant' | 'roommate' | 'family'
  final String linkedAs;

  /// When was this user linked to the account
  final DateTime? linkedOn;

  /// Who added this user to the account
  final String? linkedBy;

  AccountLink({
    this.primaryOwnerUid,
    required this.linkedAs,
    this.linkedOn,
    this.linkedBy,
  });

  /// Is this the primary owner
  bool get isOwner => primaryOwnerUid == null && linkedAs == 'owner';

  /// Is this a tenant/roommate (linked user)
  bool get isTenant => primaryOwnerUid != null;

  Map<String, dynamic> toMap() {
    return {
      'primary_owner_uid': primaryOwnerUid,
      'linked_as': linkedAs,
      'linked_on': linkedOn != null ? Timestamp.fromDate(linkedOn!) : null,
      'linked_by': linkedBy,
    };
  }

  factory AccountLink.fromMap(Map<String, dynamic> map) {
    return AccountLink(
      primaryOwnerUid: map['primary_owner_uid'],
      linkedAs: map['linked_as'] ?? 'owner',
      linkedOn: map['linked_on'] != null
          ? (map['linked_on'] as Timestamp).toDate()
          : null,
      linkedBy: map['linked_by'],
    );
  }

  @override
  String toString() => 'AccountLink(linkedAs: $linkedAs, owner: $primaryOwnerUid)';
}
