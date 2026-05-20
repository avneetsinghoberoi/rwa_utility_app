import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart';
import '../models/user.dart' as UserModel;

class AccountLinkService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Add a new user to the current user's flat account
  ///
  /// Triggers:
  /// 1. Create new user account in Firebase Auth
  /// 2. Create user document in Firestore
  /// 3. Link to primary owner's account
  /// 4. Update all flat members' flat_members arrays
  /// 5. Send setup email via Cloud Function
  static Future<void> addFlatMember({
    required String email,
    required String name,
    required String relationship, // 'spouse', 'tenant', 'roommate', 'family'
    required UserModel.User currentUser,
  }) async {
    try {
      if (!currentUser.canManageFlatMembers) {
        throw Exception('Only account owner can add members');
      }

      // Step 1: Create user account in Firebase Auth
      // Note: This will be created via Cloud Function with custom password
      await _firestore.collection('_requests').add({
        'type': 'add_flat_member',
        'requester_uid': currentUser.uid,
        'email': email,
        'name': name,
        'relationship': relationship,
        'flat_no': currentUser.unitInfo.flatNo,
        'wing': currentUser.unitInfo.wing,
        'building': currentUser.unitInfo.building,
        'primary_owner_uid': currentUser.uid,
        'created_at': FieldValue.serverTimestamp(),
      });

      // The Cloud Function will handle:
      // - Creating Auth user
      // - Creating Firestore document
      // - Updating flat_members arrays
      // - Sending email
    } catch (e) {
      debugPrint('❌ Error adding flat member: $e');
      rethrow;
    }
  }

  /// Remove a user from the current user's flat account
  static Future<void> removeFlatMember({
    required String memberUidToRemove,
    required UserModel.User currentUser,
  }) async {
    try {
      if (!currentUser.canManageFlatMembers) {
        throw Exception('Only account owner can remove members');
      }

      if (memberUidToRemove == currentUser.uid) {
        throw Exception('Cannot remove yourself');
      }

      // Start batch transaction
      final batch = _firestore.batch();

      // Step 1: Mark member as removed
      batch.update(
        _firestore.collection('users').doc(memberUidToRemove),
        {'status': 'removed'},
      );

      // Step 2: Update all flat members to remove this user
      for (String memberId in currentUser.flatMembers) {
        batch.update(
          _firestore.collection('users').doc(memberId),
          {
            'flat_members': FieldValue.arrayRemove([memberUidToRemove]),
          },
        );
      }

      await batch.commit();

      debugPrint('✅ Removed flat member: $memberUidToRemove');
    } catch (e) {
      debugPrint('❌ Error removing flat member: $e');
      rethrow;
    }
  }

  /// Get all members of current user's flat
  static Future<List<UserModel.User>> getFlatMembers({
    required UserModel.User currentUser,
  }) async {
    try {
      final memberDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: currentUser.flatMembers)
          .get();

      return memberDocs.docs.map((doc) => UserModel.User.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error getting flat members: $e');
      rethrow;
    }
  }

  /// Get the primary account owner
  static Future<UserModel.User?> getPrimaryOwner({
    required UserModel.User currentUser,
  }) async {
    try {
      final ownerUid = currentUser.accountOwnerUid;

      if (ownerUid == currentUser.uid) {
        return currentUser; // They are the owner
      }

      final ownerDoc =
          await _firestore.collection('users').doc(ownerUid).get();

      if (ownerDoc.exists) {
        return UserModel.User.fromFirestore(ownerDoc);
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting primary owner: $e');
      rethrow;
    }
  }

  /// Check if two users are on the same flat
  static Future<bool> isSameFlatMember(
    String uid1,
    String uid2,
  ) async {
    try {
      final doc1 = await _firestore.collection('users').doc(uid1).get();
      final doc2 = await _firestore.collection('users').doc(uid2).get();

      if (!doc1.exists || !doc2.exists) return false;

      final flatNo1 = doc1['unit_info']['flat_no'];
      final wing1 = doc1['unit_info']['wing'];
      final flatNo2 = doc2['unit_info']['flat_no'];
      final wing2 = doc2['unit_info']['wing'];

      return flatNo1 == flatNo2 && wing1 == wing2;
    } catch (e) {
      debugPrint('❌ Error checking same flat member: $e');
      return false;
    }
  }

  /// Get shared invoices for the current user's flat
  /// All members of flat can see same invoices
  static Future<List<Map<String, dynamic>>> getSharedInvoices({
    required UserModel.User currentUser,
  }) async {
    try {
      final invoices = await _firestore
          .collection('invoices')
          .where('flat_no', isEqualTo: currentUser.unitInfo.flatNo)
          .orderBy('due_date', descending: true)
          .get();

      return invoices.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error getting shared invoices: $e');
      rethrow;
    }
  }

  /// Get shared issues for the current user's flat
  static Future<List<Map<String, dynamic>>> getSharedIssues({
    required UserModel.User currentUser,
  }) async {
    try {
      final issues = await _firestore
          .collection('issues')
          .where('unit_info.flat_no', isEqualTo: currentUser.unitInfo.flatNo)
          .orderBy('created_at', descending: true)
          .get();

      return issues.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error getting shared issues: $e');
      rethrow;
    }
  }

  /// Get shared payments for the current user's flat
  static Future<List<Map<String, dynamic>>> getSharedPayments({
    required UserModel.User currentUser,
  }) async {
    try {
      // Payments are linked to invoices
      final invoices = await _firestore
          .collection('invoices')
          .where('flat_no', isEqualTo: currentUser.unitInfo.flatNo)
          .get();

      final invoiceIds = invoices.docs.map((doc) => doc.id).toList();

      if (invoiceIds.isEmpty) return [];

      final payments = await _firestore
          .collection('payments')
          .where('invoice_id', whereIn: invoiceIds)
          .orderBy('payment_date', descending: true)
          .get();

      return payments.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error getting shared payments: $e');
      rethrow;
    }
  }
}

// Helper for debugging
void debugPrint(String message) {
  print(message);
}
