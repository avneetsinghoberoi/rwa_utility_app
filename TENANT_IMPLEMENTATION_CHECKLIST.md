# Tenant Role Implementation Checklist

## Phase-by-Phase Development Guide

---

## 📋 PHASE 1: Database & Backend (Week 1-2)

### Task 1.1: Update Firestore Users Collection
- [ ] Add `role` field (String: 'admin' | 'resident' | 'tenant')
- [ ] Add `tenant_info` object (optional)
  - [ ] `owner_uid` (String)
  - [ ] `move_in_date` (Timestamp)
  - [ ] `move_out_date` (Timestamp, optional)
  - [ ] `is_active` (Boolean)
- [ ] Add `admin_info` object (optional)
  - [ ] `permissions` (Array)
  - [ ] `created_by` (String)
- [ ] Create migration script for existing users

**Code Example**:
```dart
// Migration function
Future<void> migrateUsersToNewSchema() async {
  final batch = FirebaseFirestore.instance.batch();
  final usersRef = FirebaseFirestore.instance.collection('users');
  
  final snapshot = await usersRef.get();
  
  for (var doc in snapshot.docs) {
    batch.update(doc.reference, {
      'role': 'resident', // Default existing users to resident
      'tenant_info': null,
      'admin_info': null,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
  
  await batch.commit();
}
```

### Task 1.2: Create tenant_mappings Collection
- [ ] Create collection: `tenant_mappings`
- [ ] Document structure:
  ```
  {
    tenant_uid: String,
    owner_uid: String,
    house_no: String,
    flat_no: String,
    move_in_date: Timestamp,
    move_out_date: Timestamp,
    is_active: Boolean,
    created_at: Timestamp,
    created_by: String
  }
  ```

### Task 1.3: Update Firestore Security Rules
- [ ] Add role helper functions:
  ```javascript
  function isAdmin(userId) {
    return get(/databases/$(database)/documents/users/$(userId)).data.role == 'admin';
  }
  
  function isTenant(userId) {
    return get(/databases/$(database)/documents/users/$(userId)).data.role == 'tenant';
  }
  
  function getTenantOwner(tenantId) {
    let tenantDoc = get(/databases/$(database)/documents/users/$(tenantId)).data;
    return tenantDoc.tenant_info.owner_uid;
  }
  
  function canAccessUnitData(userId, ownerUid) {
    return userId == ownerUid || 
           (isTenant(userId) && getTenantOwner(userId) == ownerUid);
  }
  ```

- [ ] Update collection rules:
  - [ ] `users`: Add tenant access rules
  - [ ] `invoices`: Add tenant read-only rules
  - [ ] `issues`: Add tenant visibility rules
  - [ ] `tenant_mappings`: Add tenant/owner access rules

- [ ] Test rules with Firebase emulator:
  ```bash
  firebase emulators:start
  ```

### Task 1.4: Deploy Cloud Functions
- [ ] Create `onTenantCreated` function
  ```javascript
  exports.onTenantCreated = functions.firestore
    .document('users/{userId}')
    .onCreate(async (snap, context) => {
      const user = snap.data();
      
      if (user.role === 'tenant' && user.tenant_info) {
        // Create tenant mapping
        await admin.firestore().collection('tenant_mappings').add({
          tenant_uid: context.params.userId,
          owner_uid: user.tenant_info.owner_uid,
          flat_no: user.unit_info.flat_no,
          is_active: true,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Send email to owner
        // await sendEmailToOwner(...)
      }
    });
  ```

- [ ] Create `getTenantsByOwner` function
- [ ] Create `removeTenant` function
- [ ] Deploy to Firebase

### Task 1.5: Test Database Changes
- [ ] Create test users (admin, resident, tenant)
- [ ] Verify role assignments
- [ ] Test Firestore rules with different roles
- [ ] Test Cloud Functions triggers

---

## 🔐 PHASE 2: Authentication & Login (Week 2-3)

### Task 2.1: Update LoginScreen
- [ ] Add role selection during signup
- [ ] Create role selection UI component
  ```dart
  // screens/login/role_selection_screen.dart
  class RoleSelectionScreen extends StatefulWidget {
    @override
    State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
  }
  
  class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
    String selectedRole = '';
    
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: Column(
          children: [
            Text('Select Your Role'),
            RoleCard(
              role: 'admin',
              title: 'Administrator',
              description: 'Manage society',
              onTap: () => setState(() => selectedRole = 'admin'),
              isSelected: selectedRole == 'admin',
            ),
            RoleCard(
              role: 'resident',
              title: 'Resident',
              description: 'Flat owner',
              onTap: () => setState(() => selectedRole = 'resident'),
              isSelected: selectedRole == 'resident',
            ),
            RoleCard(
              role: 'tenant',
              title: 'Tenant',
              description: 'Renter',
              onTap: () => setState(() => selectedRole = 'tenant'),
              isSelected: selectedRole == 'tenant',
            ),
            ElevatedButton(
              onPressed: selectedRole.isEmpty ? null : () => handleRoleSelected(selectedRole),
              child: Text('Continue'),
            ),
          ],
        ),
      );
    }
  }
  ```

### Task 2.2: Create Tenant Signup Flow
- [ ] Show flat selection dropdown
- [ ] Show owner email input field
- [ ] Validate owner exists in Firestore
- [ ] Create tenant_info during signup
  ```dart
  Future<void> signupAsTenant({
    required String email,
    required String password,
    required String name,
    required String flatNo,
    required String ownerEmail,
  }) async {
    // 1. Create user account
    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    
    // 2. Lookup owner
    final ownerQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: ownerEmail)
        .limit(1)
        .get();
    
    if (ownerQuery.docs.isEmpty) {
      throw Exception('Owner not found');
    }
    
    final ownerUid = ownerQuery.docs.first.id;
    
    // 3. Create user document with tenant role
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .set({
          'email': email,
          'name': name,
          'role': 'tenant',
          'unit_info': {
            'flat_no': flatNo,
            'house_no': '', // Get from owner's unit
          },
          'tenant_info': {
            'owner_uid': ownerUid,
            'move_in_date': Timestamp.now(),
            'move_out_date': null,
            'is_active': true,
          },
          'created_at': Timestamp.now(),
        });
  }
  ```

### Task 2.3: Update main.dart Route Logic
- [ ] Modify `_getLandingPage()` to check role
  ```dart
  Future<Widget> _getLandingPage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        return const LoginScreen();
      }
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final role = doc['role'] ?? 'user';
      
      switch(role) {
        case 'admin':
          return const AdminDashboard();
        case 'resident':
          return Dashboard(userData: doc.data());
        case 'tenant':
          return const TenantDashboard(userData: doc.data());
        default:
          return const LoginScreen();
      }
    } catch (e) {
      debugPrint('Error: $e');
      return ErrorScreen(error: e.toString());
    }
  }
  ```

### Task 2.4: Create User Model with Roles
- [ ] Update user.dart model
  ```dart
  class User {
    final String uid;
    final String name;
    final String email;
    final String phone;
    final String role; // 'admin' | 'resident' | 'tenant'
    final UnitInfo unitInfo;
    final TenantInfo? tenantInfo;
    final AdminInfo? adminInfo;
    
    bool get isAdmin => role == 'admin';
    bool get isResident => role == 'resident';
    bool get isTenant => role == 'tenant';
    
    User({
      required this.uid,
      required this.name,
      required this.email,
      required this.phone,
      required this.role,
      required this.unitInfo,
      this.tenantInfo,
      this.adminInfo,
    });
    
    factory User.fromFirestore(DocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>;
      return User(
        uid: doc.id,
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        role: data['role'] ?? 'user',
        unitInfo: UnitInfo.fromMap(data['unit_info'] ?? {}),
        tenantInfo: data['tenant_info'] != null 
          ? TenantInfo.fromMap(data['tenant_info']) 
          : null,
        adminInfo: data['admin_info'] != null
          ? AdminInfo.fromMap(data['admin_info'])
          : null,
      );
    }
  }
  
  class TenantInfo {
    final String ownerUid;
    final DateTime moveInDate;
    final DateTime? moveOutDate;
    final bool isActive;
    
    TenantInfo({
      required this.ownerUid,
      required this.moveInDate,
      this.moveOutDate,
      this.isActive = true,
    });
    
    factory TenantInfo.fromMap(Map<String, dynamic> map) {
      return TenantInfo(
        ownerUid: map['owner_uid'] ?? '',
        moveInDate: (map['move_in_date'] as Timestamp).toDate(),
        moveOutDate: map['move_out_date'] != null 
          ? (map['move_out_date'] as Timestamp).toDate()
          : null,
        isActive: map['is_active'] ?? true,
      );
    }
  }
  ```

### Task 2.5: Test Authentication
- [ ] Test admin login
- [ ] Test resident signup
- [ ] Test tenant signup with valid owner
- [ ] Test tenant signup with invalid owner (should fail)
- [ ] Test role-based routing

---

## 🎨 PHASE 3: UI Components (Week 3-4)

### Task 3.1: Create TenantDashboard
- [ ] Create file: `lib/screens/tenant/tenant_dashboard.dart`
  ```dart
  class TenantDashboard extends StatefulWidget {
    final Map<String, dynamic> userData;
    
    const TenantDashboard({required this.userData});
    
    @override
    State<TenantDashboard> createState() => _TenantDashboardState();
  }
  
  class _TenantDashboardState extends State<TenantDashboard> {
    int _selectedIndex = 0;
    
    late List<Widget> _screens;
    
    @override
    void initState() {
      super.initState();
      _screens = [
        const TenantHomeScreen(),
        const TenantIssuesScreen(),
        const TenantNoticesScreen(),
        TenantDirectoryScreen(userData: widget.userData),
        TenantProfileScreen(userData: widget.userData),
      ];
    }
    
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.bug_report), label: 'Issues'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notices'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Directory'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );
    }
  }
  ```

### Task 3.2: Create Tenant Home Screen
- [ ] File: `lib/screens/tenant/tenant_home_screen.dart`
- [ ] Show welcome message
- [ ] Show unit info
- [ ] Show recent issues
- [ ] Show recent notices
- [ ] Show "Contact Owner" button (for payments)
  ```dart
  class TenantHomeScreen extends StatelessWidget {
    const TenantHomeScreen();
    
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: Text('Welcome')),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Unit Info Card
              Card(
                child: Column(
                  children: [
                    Text('Your Unit'),
                    Text('Flat 101, Building A'),
                  ],
                ),
              ),
              
              // Active Issues Section
              Section(
                title: 'Active Issues',
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('issues')
                      .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                      .where('status', whereIn: ['open', 'in_progress'])
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return CircularProgressIndicator();
                    return Column(
                      children: snapshot.data!.docs.map((doc) {
                        return IssueCard(issue: doc.data());
                      }).toList(),
                    );
                  },
                ),
              ),
              
              // Payment Info
              Card(
                child: Column(
                  children: [
                    Text('Need to Pay?'),
                    Text('Contact your flat owner'),
                    ElevatedButton(
                      onPressed: () => contactOwner(),
                      child: Text('Contact Owner'),
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
  ```

### Task 3.3: Create Tenant Issues Screen
- [ ] File: `lib/screens/tenant/tenant_issues_screen.dart`
- [ ] Show only tenant's own issues
- [ ] Allow reporting new issues
- [ ] Show issue details with comments from admin
- [ ] Cannot edit/manage issues

### Task 3.4: Create Tenant Notices Screen
- [ ] File: `lib/screens/tenant/tenant_notices_screen.dart`
- [ ] Same as resident notices screen
- [ ] Show all society notices
- [ ] Filter by priority

### Task 3.5: Create Tenant Directory Screen
- [ ] File: `lib/screens/tenant/tenant_directory_screen.dart`
- [ ] Show only unit members (owner + other tenants)
- [ ] Cannot copy contact info
- [ ] Limited search (name, phone only)
  ```dart
  class TenantDirectoryScreen extends StatefulWidget {
    final Map<String, dynamic> userData;
    
    const TenantDirectoryScreen({required this.userData});
    
    @override
    State<TenantDirectoryScreen> createState() => _TenantDirectoryScreenState();
  }
  
  class _TenantDirectoryScreenState extends State<TenantDirectoryScreen> {
    late String ownerUid;
    late String flatNo;
    
    @override
    void initState() {
      super.initState();
      ownerUid = userData['tenant_info']['owner_uid'];
      flatNo = userData['unit_info']['flat_no'];
    }
    
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: Text('Unit Members')),
        body: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('unit_info.flat_no', isEqualTo: flatNo)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CircularProgressIndicator();
            
            final members = snapshot.data!.docs;
            return ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index].data();
                return TenantMemberCard(
                  member: member,
                  canCopy: false, // Cannot copy contact info
                );
              },
            );
          },
        ),
      );
    }
  }
  ```

### Task 3.6: Create Tenant Profile Screen
- [ ] File: `lib/screens/tenant/tenant_profile_screen.dart`
- [ ] Show profile info
- [ ] Edit name, phone, photo
- [ ] Show owner info
- [ ] Show move-in date
- [ ] Show move-out date (if applicable)
- [ ] Logout button

### Task 3.7: Create Shared Components
- [ ] `RoleBadge` widget
- [ ] `TenantLimitedAccessCard` widget
- [ ] `ContactOwnerCard` widget

---

## 🔒 PHASE 4: Security & Permissions (Week 4)

### Task 4.1: Update app_config.dart
- [ ] Add tenant to supported roles
- [ ] Add role-based feature access
- [ ] Add permission constants

### Task 4.2: Update Existing Screens for Tenant Awareness
- [ ] `pay_screen.dart`: Hide from tenant (show "Contact Owner" instead)
- [ ] `expense_screen.dart`: Hide from tenant
- [ ] `directory_screen.dart`: Filter for tenant
- [ ] `issues_screen.dart`: Show/hide based on visibility settings
- [ ] `notices_screen.dart`: Same for all

### Task 4.3: Add Feature Guards
- [ ] Create feature check widget
  ```dart
  class FeatureGuard extends StatelessWidget {
    final String requiredRole;
    final Widget child;
    final Widget? fallback;
    
    const FeatureGuard({
      required this.requiredRole,
      required this.child,
      this.fallback,
    });
    
    @override
    Widget build(BuildContext context) {
      final userRole = getUserRole(context); // Get from provider/stream
      
      if (userRole == requiredRole || userRole == 'admin') {
        return child;
      } else {
        return fallback ?? RestrictedAccessWidget();
      }
    }
  }
  
  // Usage:
  FeatureGuard(
    requiredRole: 'resident',
    child: PaymentScreen(),
    fallback: TenantPaymentLockedCard(),
  )
  ```

### Task 4.4: Implement Permission Checks
- [ ] Create permission service
  ```dart
  class PermissionService {
    static bool canPay(String role) => role == 'resident' || role == 'admin';
    static bool canCreateDues(String role) => role == 'admin';
    static bool canReportIssues(String role) => ['admin', 'resident', 'tenant'].contains(role);
    static bool canManageIssues(String role) => role == 'admin';
    static bool canViewExpenses(String role) => ['admin', 'resident'].contains(role);
    static bool canPostNotices(String role) => role == 'admin';
    static bool canViewAllDirectory(String role) => ['admin', 'resident'].contains(role);
    static bool canCreateMembers(String role) => role == 'admin';
  }
  ```

### Task 4.5: Test Permissions
- [ ] Test each feature with each role
- [ ] Verify Firestore rules block unauthorized access
- [ ] Test data isolation (tenant can't see other units)
- [ ] Test feature guards work properly

---

## 🧪 PHASE 5: Testing (Week 5)

### Task 5.1: Unit Tests
- [ ] Test role checking functions
- [ ] Test permission service
- [ ] Test user model parsing
- [ ] Test tenant info validation

### Task 5.2: Integration Tests
- [ ] Test complete signup flow for each role
- [ ] Test login and routing for each role
- [ ] Test role switching (sign out, sign in as different role)
- [ ] Test feature access for each role

### Task 5.3: E2E Tests
- [ ] Test tenant signup flow end-to-end
- [ ] Test tenant reporting issue
- [ ] Test resident viewing tenant issue
- [ ] Test admin managing all roles
- [ ] Test data isolation scenarios

### Task 5.4: Security Tests
- [ ] Test Firestore rules with emulator
- [ ] Test tenant cannot access other unit data
- [ ] Test tenant cannot modify data
- [ ] Test rules enforce role-based access

### Task 5.5: Performance Tests
- [ ] Test large directory queries (1000+ members)
- [ ] Test multiple tenants per unit
- [ ] Test issue reporting performance
- [ ] Test real-time sync speed

---

## 📊 PHASE 6: Deployment & Documentation (Week 6)

### Task 6.1: Pre-Deployment Checklist
- [ ] All tests passing
- [ ] No console errors/warnings
- [ ] Firestore rules tested in production mode
- [ ] Cloud Functions deployed
- [ ] Database backup created

### Task 6.2: Documentation
- [ ] Update README with tenant features
- [ ] Create tenant user guide
- [ ] Create admin guide for managing tenants
- [ ] Create resident guide for tenant management
- [ ] Update API documentation

### Task 6.3: Release Notes
- [ ] Document new features
- [ ] Document breaking changes (if any)
- [ ] Document migration steps
- [ ] Create FAQ for tenants

### Task 6.4: Beta Release
- [ ] Release to beta users
- [ ] Collect feedback
- [ ] Fix critical issues
- [ ] Monitor for bugs

### Task 6.5: Full Release
- [ ] Deploy to production
- [ ] Monitor Firebase logs
- [ ] Be ready for support queries
- [ ] Document lessons learned

---

## 🎯 Success Criteria

- [ ] All 3 roles working independently
- [ ] Data isolation working correctly
- [ ] No security vulnerabilities
- [ ] All features accessible/hidden appropriately
- [ ] User feedback positive
- [ ] No production incidents
- [ ] Documentation complete

---

## 📝 Estimated Timeline

| Phase | Duration | Priority |
|-------|----------|----------|
| Phase 1: Database | 3-4 days | 🔴 CRITICAL |
| Phase 2: Auth | 3-4 days | 🔴 CRITICAL |
| Phase 3: UI | 5-6 days | 🟡 HIGH |
| Phase 4: Security | 2-3 days | 🔴 CRITICAL |
| Phase 5: Testing | 4-5 days | 🟡 HIGH |
| Phase 6: Deploy | 2-3 days | 🟡 HIGH |
| **Total** | **3-4 weeks** | ✅ |

---

## 🚀 Go-Live Checklist

Before launching tenant features:

- [ ] Database migration complete
- [ ] All Firestore rules deployed
- [ ] All Cloud Functions tested
- [ ] UI fully responsive on mobile/web
- [ ] All edge cases tested
- [ ] Performance acceptable
- [ ] Security audit passed
- [ ] Documentation reviewed
- [ ] Support team trained
- [ ] Monitoring/alerts configured
- [ ] Rollback plan ready

---

**Last Updated**: May 2026  
**Status**: Ready for Development Phase 1 ✅
