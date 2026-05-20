import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:gate_basic/models/user.dart' as UserModel;
import '../../helpers/test_factories.dart';

void main() {
  group('User — computed properties', () {
    test('owner: isAccountOwner is true when no primaryOwnerUid', () {
      final user = makeOwner();
      expect(user.isAccountOwner, isTrue);
      expect(user.isLinkedUser, isFalse);
      expect(user.canManageFlatMembers, isTrue);
    });

    test('tenant: isLinkedUser is true when primaryOwnerUid is set', () {
      final user = makeTenant();
      expect(user.isLinkedUser, isTrue);
      expect(user.isAccountOwner, isFalse);
      expect(user.canManageFlatMembers, isFalse);
    });

    test('accountOwnerUid returns own uid for owner', () {
      final user = makeOwner(uid: 'owner-uid-1');
      expect(user.accountOwnerUid, equals('owner-uid-1'));
    });

    test('accountOwnerUid returns primaryOwnerUid for tenant', () {
      final user = makeTenant(uid: 'tenant-uid-1', ownerUid: 'owner-uid-1');
      expect(user.accountOwnerUid, equals('owner-uid-1'));
    });

    test('otherFlatMembers excludes self', () {
      final user = UserModel.User(
        uid: 'uid-A',
        name: 'A',
        email: 'a@test.com',
        phone: '',
        profilePhoto: '',
        role: 'user',
        unitInfo: UserModel.UnitInfo(
            houseNo: '1', flatNo: '1', wing: '', building: ''),
        accountLink: UserModel.AccountLink(linkedAs: 'owner'),
        flatMembers: ['uid-A', 'uid-B', 'uid-C'],
        createdAt: DateTime.now(),
      );
      expect(user.otherFlatMembers, containsAll(['uid-B', 'uid-C']));
      expect(user.otherFlatMembers, isNot(contains('uid-A')));
    });

    test('flatMemberCount returns correct count', () {
      final user = makeOwner();
      expect(user.flatMemberCount, equals(1));
    });

    test('isAdmin false for resident', () {
      final user = makeOwner();
      expect(user.isAdmin, isFalse);
      expect(user.isResident, isTrue);
    });
  });

  // ── AccountLink ────────────────────────────────────────────────────────────
  group('AccountLink', () {
    test('isOwner true when no primaryOwnerUid and linkedAs=owner', () {
      final link = UserModel.AccountLink(linkedAs: 'owner');
      expect(link.isOwner, isTrue);
      expect(link.isTenant, isFalse);
    });

    test('isTenant true when primaryOwnerUid is set', () {
      final link = UserModel.AccountLink(
          primaryOwnerUid: 'some-uid', linkedAs: 'tenant');
      expect(link.isTenant, isTrue);
      expect(link.isOwner, isFalse);
    });

    test('fromMap handles missing keys gracefully', () {
      final link = UserModel.AccountLink.fromMap({});
      expect(link.primaryOwnerUid, isNull);
      expect(link.linkedAs, equals('owner'));
    });
  });

  // ── UnitInfo ───────────────────────────────────────────────────────────────
  group('UnitInfo', () {
    test('fromMap parses correctly', () {
      final unit = UserModel.UnitInfo.fromMap({
        'house_no': '101',
        'flat_no': '101A',
        'wing': 'B',
        'building': 'Tower 1',
      });
      expect(unit.houseNo, equals('101'));
      expect(unit.wing, equals('B'));
      expect(unit.building, equals('Tower 1'));
    });

    test('fromMap handles missing keys with empty strings', () {
      final unit = UserModel.UnitInfo.fromMap({});
      expect(unit.houseNo, equals(''));
      expect(unit.flatNo, equals(''));
    });

    test('toMap round-trips correctly', () {
      final unit = UserModel.UnitInfo(
          houseNo: '202', flatNo: '202B', wing: 'C', building: 'Palm');
      final map = unit.toMap();
      final restored = UserModel.UnitInfo.fromMap(map);
      expect(restored.houseNo, equals('202'));
      expect(restored.wing, equals('C'));
    });
  });

  // ── User.fromFirestore ─────────────────────────────────────────────────────
  group('User.fromFirestore', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() async {
      fakeFirestore = await buildFakeFirestore();
    });

    test('parses owner correctly from Firestore doc', () async {
      final doc = await fakeFirestore.collection('users').doc('owner-uid-1').get();
      final user = UserModel.User.fromFirestore(doc);

      expect(user.uid, equals('owner-uid-1'));
      expect(user.name, equals('Ravi Sharma'));
      expect(user.unitInfo.houseNo, equals('101'));
      expect(user.isAccountOwner, isTrue);
      expect(user.status, equals('active'));
    });

    test('parses tenant correctly from Firestore doc', () async {
      final doc =
          await fakeFirestore.collection('users').doc('tenant-uid-1').get();
      final user = UserModel.User.fromFirestore(doc);

      expect(user.isLinkedUser, isTrue);
      expect(user.accountLink.primaryOwnerUid, equals('owner-uid-1'));
      expect(user.accountLink.linkedAs, equals('tenant'));
    });

    test('falls back to top-level house_no when unit_info is missing', () async {
      await fakeFirestore.collection('users').doc('no-unit-uid').set({
        'name': 'Test User',
        'email': 'test@example.com',
        'phone': '',
        'profile_photo': '',
        'role': 'user',
        'house_no': '205',
        'account_link': {},
        'flat_members': ['no-unit-uid'],
        'status': 'active',
        'created_at': DateTime.now(),
      });

      final doc =
          await fakeFirestore.collection('users').doc('no-unit-uid').get();
      final user = UserModel.User.fromFirestore(doc);

      expect(user.unitInfo.houseNo, equals('205'));
    });

    test('toFirestore preserves all fields', () {
      final user = makeOwner();
      final map = user.toFirestore();

      expect(map['name'], equals('Ravi Sharma'));
      expect(map['house_no'], equals('101'));
      expect(map['role'], equals('user'));
      expect(map['status'], equals('active'));
      expect(map['flat_members'], contains('owner-uid-1'));
    });
  });
}
