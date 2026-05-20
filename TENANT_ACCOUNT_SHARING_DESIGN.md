# Tenant Account Sharing Architecture
## Simplified Multi-User Account Model

---

## 🎯 New Concept: Account Sharing

Instead of creating a separate "tenant" role with limited permissions, residents can **share their flat account with multiple tenants** who get **full access to everything the resident can access**.

```
┌─────────────────────────────────────────────────────┐
│              Flat 101 Account                       │
├─────────────────────────────────────────────────────┤
│                                                     │
│  PRIMARY OWNER: Rajesh Kumar (Resident)            │
│  ├─ Can do everything                              │
│  ├─ Manage tenants                                 │
│  └─ Full control                                   │
│                                                     │
│  SHARED USERS:                                      │
│  ├─ Tenant 1: John (Renter) - Full Access         │
│  ├─ Tenant 2: Jane (Spouse) - Full Access         │
│  ├─ Tenant 3: Mike (Roommate) - Full Access       │
│  └─ [Add More Tenants...]                         │
│                                                     │
│  All share access to:                              │
│  ✅ Pay maintenance                                │
│  ✅ Report issues                                  │
│  ✅ View notices                                   │
│  ✅ See receipts                                   │
│  ✅ Download expenses                              │
│  ✅ Generate guest passes                          │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Architecture Overview

### Current System (2 Roles)
```
Flat 101 → Can only log in as: Rajesh Kumar
           Only one person has access
```

### New System (Account Sharing)
```
Flat 101 Account
├─ Owner: Rajesh Kumar (manages tenants)
│  └─ Full access to all features
│
└─ Linked Users:
   ├─ John (Tenant) - Same flat access
   ├─ Jane (Spouse) - Same flat access
   └─ Mike (Roommate) - Same flat access
   
   All see same invoices, issues, notices
   All can pay from same account
   All see same receipts & history
```

---

## Updated Firestore Schema

### Users Collection (Enhanced)

```json
{
  "users": {
    "{userId}": {
      "name": "String",
      "email": "String (unique)",
      "phone": "String",
      "profile_photo": "String (URL)",
      "role": "String", // 'admin' | 'resident'
      "created_at": "Timestamp",
      
      // Unit ownership
      "unit_info": {
        "house_no": "String",
        "flat_no": "String",
        "wing": "String",
        "building": "String"
      },
      
      // NEW: Link to primary account
      "account_link": {
        "primary_owner_uid": "String", // If null = this is the owner
        "linked_as": "String", // 'owner' | 'tenant' | 'spouse' | 'roommate'
        "linked_on": "Timestamp",
        "linked_by": "String" // UID of who added this user
      },
      
      // NEW: List of all users on this flat
      "flat_members": ["uid1", "uid2", "uid3"], // Array of all user UIDs on this flat
      
      "status": "String" // 'active' | 'inactive' | 'removed'
    }
  }
}
```

### Example User Documents

**Primary Owner (Rajesh)**:
```json
{
  "uid": "rajesh_uid",
  "name": "Rajesh Kumar",
  "email": "rajesh@example.com",
  "phone": "9876543210",
  "role": "resident",
  "unit_info": {
    "flat_no": "101",
    "wing": "A",
    "house_no": "GateBasic Heights"
  },
  "account_link": {
    "primary_owner_uid": null,  // He's the owner
    "linked_as": "owner"
  },
  "flat_members": ["rajesh_uid", "john_uid", "jane_uid"],
  "status": "active"
}
```

**Tenant 1 (John - Linked Account)**:
```json
{
  "uid": "john_uid",
  "name": "John (Tenant)",
  "email": "john@example.com",
  "phone": "9123456789",
  "role": "resident",  // ← SAME role, not different
  "unit_info": {
    "flat_no": "101",  // ← SAME flat
    "wing": "A",
    "house_no": "GateBasic Heights"
  },
  "account_link": {
    "primary_owner_uid": "rajesh_uid",  // ← Linked to Rajesh
    "linked_as": "tenant",
    "linked_on": "2026-05-10T10:30:00Z",
    "linked_by": "rajesh_uid"
  },
  "flat_members": ["rajesh_uid", "john_uid", "jane_uid"],  // ← Same list
  "status": "active"
}
```

**Tenant 2 (Jane - Linked Account)**:
```json
{
  "uid": "jane_uid",
  "name": "Jane (Spouse)",
  "email": "jane@example.com",
  "phone": "9987654321",
  "role": "resident",  // ← SAME role
  "unit_info": {
    "flat_no": "101",  // ← SAME flat
    "wing": "A",
    "house_no": "GateBasic Heights"
  },
  "account_link": {
    "primary_owner_uid": "rajesh_uid",
    "linked_as": "spouse",
    "linked_on": "2026-05-08T14:20:00Z",
    "linked_by": "rajesh_uid"
  },
  "flat_members": ["rajesh_uid", "john_uid", "jane_uid"],
  "status": "active"
}
```

---

## Feature Access - All Equal

Since all linked users have `role: 'resident'`, they get **100% same access**:

| Feature | Owner | Tenant 1 | Tenant 2 | Tenant 3 |
|---------|:---:|:---:|:---:|:---:|
| Pay maintenance | ✅ | ✅ | ✅ | ✅ |
| View invoices | ✅ | ✅ | ✅ | ✅ |
| Download receipts | ✅ | ✅ | ✅ | ✅ |
| Report issues | ✅ | ✅ | ✅ | ✅ |
| View issues | ✅ | ✅ | ✅ | ✅ |
| See notices | ✅ | ✅ | ✅ | ✅ |
| View directory | ✅ | ✅ | ✅ | ✅ |
| View expenses | ✅ | ✅ | ✅ | ✅ |
| Generate QR pass | ✅ | ✅ | ✅ | ✅ |
| **Manage tenants** | ✅ | ❌ | ❌ | ❌ |
| Remove tenant | ✅ | ❌ | ❌ | ❌ |

---

## Updated Firestore Rules

### Key Changes

```javascript
// Helper functions
function isAdmin(userId) {
  return get(/databases/$(database)/documents/users/$(userId)).data.role == 'admin';
}

function getFlatInfo(userId) {
  return get(/databases/$(database)/documents/users/$(userId)).data.unit_info;
}

// Check if user belongs to same flat
function isSameFlatMember(userId1, userId2) {
  let user1Flat = getFlatInfo(userId1);
  let user2Flat = getFlatInfo(userId2);
  return user1Flat.flat_no == user2Flat.flat_no && 
         user1Flat.wing == user2Flat.wing;
}

// Check if user is account owner (primary owner of flat)
function isPrimaryOwner(userId) {
  return get(/databases/$(database)/documents/users/$(userId)).data.account_link.primary_owner_uid == null;
}

// Get primary owner UID
function getPrimaryOwnerUid(userId) {
  let user = get(/databases/$(database)/documents/users/$(userId)).data;
  return user.account_link.primary_owner_uid != null 
    ? user.account_link.primary_owner_uid 
    : userId;
}
```

### Updated Collection Rules

```javascript
// Users collection
match /users/{userId} {
  // Anyone can read their own profile
  allow read: if request.auth.uid == userId;
  
  // Can read flat members (all users on same flat)
  allow read: if request.auth.uid != null && 
              isSameFlatMember(request.auth.uid, userId);
  
  // Admin can see all
  allow read: if isAdmin(request.auth.uid);
  
  // Can edit own profile
  allow update: if request.auth.uid == userId &&
                !request.resource.data.diff(resource.data).affectedKeys()
                  .hasAny(['role', 'account_link', 'flat_no']);
  
  // Only primary owner can add/remove tenants
  allow update: if request.auth.uid != null && 
                isPrimaryOwner(request.auth.uid) &&
                userId == request.auth.uid;
}

// Invoices collection
match /invoices/{document=**} {
  allow read: if request.auth.uid != null && (
    isAdmin(request.auth.uid) ||
    // Owner can see their flat's invoices
    (isSameFlatMember(request.auth.uid, resource.data.uid) &&
     resource.data.uid == getPrimaryOwnerUid(request.auth.uid))
  );
  
  allow create: if request.auth.uid != null && 
                isSameFlatMember(request.auth.uid, request.resource.data.uid);
}

// Issues collection
match /issues/{document=**} {
  allow read: if request.auth.uid != null && (
    isAdmin(request.auth.uid) ||
    // Same flat members can read issues from same flat
    isSameFlatMember(request.auth.uid, resource.data.uid)
  );
  
  allow create: if request.auth.uid != null && 
                isSameFlatMember(request.auth.uid, request.resource.data.uid);
  
  allow update: if isAdmin(request.auth.uid);
}

// Payments collection
match /payments/{document=**} {
  allow read: if request.auth.uid != null && (
    isAdmin(request.auth.uid) ||
    isSameFlatMember(request.auth.uid, resource.data.uid)
  );
  
  allow create: if request.auth.uid != null && 
                isSameFlatMember(request.auth.uid, request.resource.data.uid);
}
```

---

## Implementation Steps

### Step 1: Database Migration

```javascript
// Firebase Cloud Function to migrate existing users
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.migrateToAccountSharing = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  const batch = db.batch();
  
  const usersSnapshot = await db.collection('users').get();
  
  usersSnapshot.forEach(doc => {
    const userId = doc.id;
    const userData = doc.data();
    
    batch.update(doc.ref, {
      'account_link': {
        'primary_owner_uid': null,  // All existing are owners
        'linked_as': 'owner',
        'linked_on': admin.firestore.FieldValue.serverTimestamp(),
        'linked_by': 'system_migration'
      },
      'flat_members': [userId],  // Only themselves initially
      'status': 'active'
    });
  });
  
  await batch.commit();
  res.send('Migration complete');
});
```

### Step 2: Update User Model

```dart
class User {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // 'admin' | 'resident' only
  final UnitInfo unitInfo;
  final AccountLink accountLink;
  final List<String> flatMembers;
  final String status;
  
  // Computed properties
  bool get isAccountOwner => accountLink.primaryOwnerUid == null;
  bool get isLinkedUser => accountLink.primaryOwnerUid != null;
  String get accountOwnerUid => accountLink.primaryOwnerUid ?? uid;
  
  // Can this user manage tenants?
  bool get canManageTenants => isAccountOwner;
  
  User({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.unitInfo,
    required this.accountLink,
    required this.flatMembers,
    this.status = 'active',
  });
  
  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'resident',
      unitInfo: UnitInfo.fromMap(data['unit_info'] ?? {}),
      accountLink: AccountLink.fromMap(data['account_link'] ?? {}),
      flatMembers: List<String>.from(data['flat_members'] ?? []),
      status: data['status'] ?? 'active',
    );
  }
}

class AccountLink {
  final String? primaryOwnerUid;  // null = this user is owner
  final String linkedAs;  // 'owner' | 'tenant' | 'spouse' | 'roommate'
  final DateTime? linkedOn;
  final String? linkedBy;
  
  AccountLink({
    this.primaryOwnerUid,
    required this.linkedAs,
    this.linkedOn,
    this.linkedBy,
  });
  
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
}
```

### Step 3: Add "Manage Tenants" Screen

```dart
// lib/screens/user/manage_tenants_screen.dart

class ManageTenantsScreen extends StatefulWidget {
  final User currentUser;
  
  const ManageTenantsScreen({required this.currentUser});
  
  @override
  State<ManageTenantsScreen> createState() => _ManageTenantsScreenState();
}

class _ManageTenantsScreenState extends State<ManageTenantsScreen> {
  late User primaryOwner;
  
  @override
  void initState() {
    super.initState();
    loadPrimaryOwnerData();
  }
  
  Future<void> loadPrimaryOwnerData() async {
    // Get primary owner's document
    final ownerUid = widget.currentUser.accountOwnerUid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUid)
        .get();
    
    setState(() {
      primaryOwner = User.fromFirestore(doc);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Account Access'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current members
            Text(
              'Users with access to this account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            
            // List of flat members
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('flat_members', arrayContains: widget.currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return CircularProgressIndicator();
                }
                
                final members = snapshot.data!.docs
                    .map((doc) => User.fromFirestore(doc))
                    .toList();
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return MemberCard(
                      member: member,
                      isOwner: member.isAccountOwner,
                      canRemove: widget.currentUser.canManageTenants && 
                                !member.isAccountOwner,
                      onRemove: () => removeTenant(member.uid),
                    );
                  },
                );
              },
            ),
            
            SizedBox(height: 32),
            
            // Add new tenant button (only for owner)
            if (widget.currentUser.canManageTenants)
              ElevatedButton.icon(
                onPressed: () => showAddTenantDialog(),
                icon: Icon(Icons.add),
                label: Text('Add User to Account'),
              ),
          ],
        ),
      ),
    );
  }
  
  void showAddTenantDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTenantDialog(
        onAdd: (email, name, relationship) => addTenant(email, name, relationship),
      ),
    );
  }
  
  Future<void> addTenant(String email, String name, String relationship) async {
    try {
      // 1. Create new user account
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: 'temp_password');
      
      final newUserId = userCred.user!.uid;
      
      // 2. Create user document linked to this account
      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUserId)
          .set({
            'name': name,
            'email': email,
            'phone': '',
            'role': 'resident',  // Same role as owner
            'unit_info': widget.currentUser.unitInfo.toMap(),
            'account_link': {
              'primary_owner_uid': widget.currentUser.accountOwnerUid,
              'linked_as': relationship, // 'tenant', 'spouse', 'roommate', etc.
              'linked_on': FieldValue.serverTimestamp(),
              'linked_by': FirebaseAuth.instance.currentUser!.uid,
            },
            'flat_members': widget.currentUser.flatMembers,
            'status': 'active',
            'created_at': FieldValue.serverTimestamp(),
          });
      
      // 3. Update primary owner's flat_members list
      final primaryOwnerUid = widget.currentUser.accountOwnerUid;
      final primaryOwnerDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(primaryOwnerUid);
      
      await primaryOwnerDoc.update({
        'flat_members': FieldValue.arrayUnion([newUserId]),
      });
      
      // 4. Update all current members' flat_members lists
      final batch = FirebaseFirestore.instance.batch();
      for (String memberId in widget.currentUser.flatMembers) {
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(memberId),
          {'flat_members': FieldValue.arrayUnion([newUserId])},
        );
      }
      await batch.commit();
      
      // 5. Send email to new user with setup link
      await sendSetupEmail(email);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User added successfully. Setup link sent via email.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  Future<void> removeTenant(String tenantUid) async {
    try {
      final primaryOwnerUid = widget.currentUser.accountOwnerUid;
      
      // Update primary owner's flat_members
      await FirebaseFirestore.instance
          .collection('users')
          .doc(primaryOwnerUid)
          .update({
            'flat_members': FieldValue.arrayRemove([tenantUid]),
          });
      
      // Update all remaining members' flat_members
      final batch = FirebaseFirestore.instance.batch();
      for (String memberId in widget.currentUser.flatMembers) {
        if (memberId != tenantUid) {
          batch.update(
            FirebaseFirestore.instance.collection('users').doc(memberId),
            {'flat_members': FieldValue.arrayRemove([tenantUid])},
          );
        }
      }
      await batch.commit();
      
      // Mark tenant as removed
      await FirebaseFirestore.instance
          .collection('users')
          .doc(tenantUid)
          .update({'status': 'removed'});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User removed from account')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  Future<void> sendSetupEmail(String email) async {
    // Call Cloud Function to send email
    await FirebaseFunction.httpsCallable('sendUserSetupEmail').call({
      'email': email,
    });
  }
}

class MemberCard extends StatelessWidget {
  final User member;
  final bool isOwner;
  final bool canRemove;
  final VoidCallback onRemove;
  
  const MemberCard({
    required this.member,
    required this.isOwner,
    required this.canRemove,
    required this.onRemove,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(member.name[0]),
        ),
        title: Text(member.name),
        subtitle: Text(member.email),
        trailing: isOwner
            ? Chip(label: Text('Owner'))
            : canRemove
                ? IconButton(
                    icon: Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: onRemove,
                  )
                : null,
      ),
    );
  }
}

class AddTenantDialog extends StatefulWidget {
  final Function(String email, String name, String relationship) onAdd;
  
  const AddTenantDialog({required this.onAdd});
  
  @override
  State<AddTenantDialog> createState() => _AddTenantDialogState();
}

class _AddTenantDialogState extends State<AddTenantDialog> {
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  String selectedRelationship = 'tenant';
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add User to Account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Full Name'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email Address'),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField(
              value: selectedRelationship,
              items: ['tenant', 'spouse', 'roommate', 'family']
                  .map((rel) => DropdownMenuItem(
                    value: rel,
                    child: Text(rel.capitalize()),
                  ))
                  .toList(),
              onChanged: (value) {
                setState(() => selectedRelationship = value ?? 'tenant');
              },
              decoration: InputDecoration(labelText: 'Relationship'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onAdd(
              emailController.text,
              nameController.text,
              selectedRelationship,
            );
            Navigator.pop(context);
          },
          child: Text('Add User'),
        ),
      ],
    );
  }
}
```

### Step 4: Add "Manage Tenants" to Dashboard

```dart
// Update dashboard.dart navigation

class Dashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const Dashboard({required this.userData});
  
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late int _selectedIndex = 0;
  late List<Widget> _screens;
  late User currentUser;
  
  @override
  void initState() {
    super.initState();
    currentUser = User.fromFirestore(userData as DocumentSnapshot);
    
    _screens = [
      UserHomeScreen(),
      PayScreen(),
      IssuesScreen(),
      NoticesScreen(),
      DirectoryScreen(),
      ExpenseScreen(),
      // Add this:
      if (currentUser.canManageTenants)
        ManageTenantsScreen(currentUser: currentUser),
      UserProfileScreen(),
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Pay'),
          BottomNavigationBarItem(icon: Icon(Icons.bug_report), label: 'Issues'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notices'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Directory'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Expenses'),
          // Add this:
          if (currentUser.canManageTenants)
            BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: 'Tenants'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
```

---

## Use Case Example: Adding a Tenant

```
SCENARIO: Rajesh's wife Jane wants to pay bills from her phone

STEP 1: Rajesh opens "Manage Account Access"
        └─ Sees: Only himself listed
        └─ Clicks: "Add User to Account"

STEP 2: Dialog opens asking:
        ├─ Name: "Jane Kumar"
        ├─ Email: "jane@example.com"
        └─ Relationship: "Spouse" [dropdown]

STEP 3: System creates Jane's account:
        ├─ New user document created
        ├─ Linked to Rajesh's primary UID
        ├─ Linked_as: "spouse"
        ├─ Same flat: 101
        ├─ Email sent to Jane with setup link
        └─ Jane's password set by her on first login

STEP 4: Jane receives email with setup link
        └─ Clicks link → Sets her password

STEP 5: Jane logs in with her credentials
        └─ Sees Flat 101 dashboard
        └─ All invoices for Flat 101 (same as Rajesh)
        └─ Can pay maintenance ✅
        └─ Can report issues ✅
        └─ Can see receipts ✅
        └─ Cannot manage tenants (only Rajesh can) ❌

STEP 6: When Jane pays:
        └─ Payment appears in Rajesh's payment history too
        └─ Same invoice marked as paid
        └─ Both get notification

RESULT: Shared account access ✅
        Jane has full resident access
        Both see same data
        Rajesh controls who has access
```

---

## Security Rules Summary

**Key Principle**: Users on same flat (via `flat_members` array) can see each other's data.

```
┌─ Same flat_no + Same wing?
├─ YES → Can read invoices, issues, payments
│        Can report issues
│        Can pay bills
│        (essentially full resident access)
│
└─ NO → Cannot access each other's data
        Can only see shared data (notices)
```

---

## Cloud Functions Needed

### 1. `addTenantToFlat`
- Create user account
- Link to primary owner
- Update all flat_members arrays
- Send setup email

### 2. `removeTenantFromFlat`
- Mark as removed
- Update all flat_members arrays
- Revoke access

### 3. `sendUserSetupEmail`
- Send password setup link via email
- Include flat info

### 4. `syncFlatMembers`
- Keep flat_members arrays in sync
- Called when adding/removing members

---

## Implementation Checklist

### Phase 1: Database
- [ ] Add `account_link` field to users
- [ ] Add `flat_members` array to users
- [ ] Create migration for existing users
- [ ] Update Firestore rules

### Phase 2: Backend
- [ ] Create Cloud Functions for add/remove tenant
- [ ] Create email sending function
- [ ] Test all functions

### Phase 3: Frontend
- [ ] Update User model
- [ ] Create ManageTenantsScreen
- [ ] Create AddTenantDialog
- [ ] Update Dashboard navigation

### Phase 4: Testing
- [ ] Test adding tenant
- [ ] Test removing tenant
- [ ] Test data sharing between users
- [ ] Test security rules

---

## Key Benefits of This Approach

✅ **Simple**: No separate role, just account sharing  
✅ **Flexible**: Can add multiple users, any relationship  
✅ **Secure**: Firestore rules enforce flat membership  
✅ **Intuitive**: Users think of it as "sharing my flat account"  
✅ **Scalable**: Works for any number of people per flat  
✅ **Maintainable**: No special "tenant" logic needed  
✅ **Complete Access**: Shared users get full resident features  

---

## File Structure

```
lib/
├── models/
│   └── user.dart (updated with AccountLink)
│
├── screens/
│   └── user/
│       ├── dashboard.dart (updated)
│       ├── manage_tenants_screen.dart (NEW)
│       └── add_tenant_dialog.dart (NEW)
│
├── services/
│   └── tenant_service.dart (NEW)
│       ├── addTenantToFlat()
│       ├── removeTenantFromFlat()
│       └── getTenants()
│
└── main.dart (no changes needed)
```

---

**Status**: ✅ Simplified Account Sharing Model Ready
