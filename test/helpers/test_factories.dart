import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:gate_basic/models/user.dart' as UserModel;

/// Creates a fake Firestore instance pre-populated with test data.
Future<FakeFirebaseFirestore> buildFakeFirestore() async {
  final firestore = FakeFirebaseFirestore();

  // ── Owner resident ──────────────────────────────────────────────────────
  await firestore.collection('users').doc('owner-uid-1').set({
    'name': 'Ravi Sharma',
    'email': 'ravi@example.com',
    'phone': '9876543210',
    'profile_photo': '',
    'role': 'user',
    'house_no': '101',
    'unit_info': {'house_no': '101', 'flat_no': '101', 'wing': 'A', 'building': 'Sunrise'},
    'account_link': {'primary_owner_uid': null, 'linked_as': 'owner'},
    'flat_members': ['owner-uid-1'],
    'status': 'active',
    'created_at': DateTime(2024, 1, 15),
  });

  // ── Tenant linked to owner ──────────────────────────────────────────────
  await firestore.collection('users').doc('tenant-uid-1').set({
    'name': 'Priya Mehta',
    'email': 'priya@example.com',
    'phone': '9123456789',
    'profile_photo': '',
    'role': 'user',
    'house_no': '101',
    'unit_info': {'house_no': '101', 'flat_no': '101', 'wing': 'A', 'building': 'Sunrise'},
    'account_link': {
      'primary_owner_uid': 'owner-uid-1',
      'linked_as': 'tenant',
    },
    'flat_members': ['owner-uid-1', 'tenant-uid-1'],
    'status': 'active',
    'created_at': DateTime(2024, 3, 1),
  });

  // ── Admin user ──────────────────────────────────────────────────────────
  await firestore.collection('users').doc('admin-uid-1').set({
    'name': 'Admin User',
    'email': 'admin@gatebasic.com',
    'phone': '9000000001',
    'profile_photo': '',
    'role': 'admin',
    'house_no': '',
    'unit_info': {'house_no': '', 'flat_no': '', 'wing': '', 'building': ''},
    'account_link': {'primary_owner_uid': null, 'linked_as': 'owner'},
    'flat_members': ['admin-uid-1'],
    'status': 'active',
    'created_at': DateTime(2023, 6, 1),
  });

  // ── Invoices (current month) ────────────────────────────────────────────
  final now = DateTime.now();
  final monthKey =
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  await firestore.collection('invoices').add({
    'uid': 'owner-uid-1',
    'house_no': '101',
    'month': monthKey,
    'amount': 1500.0,
    'status': 'PAID',
  });
  await firestore.collection('invoices').add({
    'uid': 'owner-uid-2',
    'house_no': '102',
    'month': monthKey,
    'amount': 1500.0,
    'status': 'UNPAID',
  });
  await firestore.collection('invoices').add({
    'uid': 'owner-uid-3',
    'house_no': '103',
    'month': monthKey,
    'amount': 1500.0,
    'status': 'SUBMITTED',
  });

  // ── Expenses ────────────────────────────────────────────────────────────
  await firestore.collection('expenses').add({
    'monthKey': monthKey,
    'amount': 800.0,
    'label': 'Cleaning',
    'date': DateTime.now(),
  });
  await firestore.collection('expenses').add({
    'monthKey': monthKey,
    'amount': 400.0,
    'label': 'Security',
    'date': DateTime.now(),
  });

  // ── Complaints ──────────────────────────────────────────────────────────
  await firestore.collection('complaints').add({
    'title': 'Water leakage in lobby',
    'status': 'open',
    'resident_name': 'Ravi Sharma',
    'created_at': DateTime.now(),
  });
  await firestore.collection('complaints').add({
    'title': 'Lift not working',
    'status': 'in_progress',
    'resident_name': 'Priya Mehta',
    'created_at': DateTime.now(),
  });
  await firestore.collection('complaints').add({
    'title': 'Parking issue resolved',
    'status': 'resolved',
    'resident_name': 'Amit Singh',
    'created_at': DateTime.now(),
  });

  return firestore;
}

/// Builds a plain [UserModel.User] for owner — no Firestore needed.
UserModel.User makeOwner({
  String uid = 'owner-uid-1',
  String name = 'Ravi Sharma',
  String houseNo = '101',
}) {
  return UserModel.User(
    uid: uid,
    name: name,
    email: 'ravi@example.com',
    phone: '9876543210',
    profilePhoto: '',
    role: 'user',
    unitInfo: UserModel.UnitInfo(
        houseNo: houseNo, flatNo: houseNo, wing: 'A', building: 'Sunrise'),
    accountLink: UserModel.AccountLink(linkedAs: 'owner'),
    flatMembers: [uid],
    status: 'active',
    createdAt: DateTime(2024, 1, 15),
  );
}

/// Builds a plain [UserModel.User] for a tenant.
UserModel.User makeTenant({
  String uid = 'tenant-uid-1',
  String ownerUid = 'owner-uid-1',
}) {
  return UserModel.User(
    uid: uid,
    name: 'Priya Mehta',
    email: 'priya@example.com',
    phone: '9123456789',
    profilePhoto: '',
    role: 'user',
    unitInfo: UserModel.UnitInfo(
        houseNo: '101', flatNo: '101', wing: 'A', building: 'Sunrise'),
    accountLink: UserModel.AccountLink(
        primaryOwnerUid: ownerUid, linkedAs: 'tenant'),
    flatMembers: [ownerUid, uid],
    status: 'active',
    createdAt: DateTime(2024, 3, 1),
  );
}
