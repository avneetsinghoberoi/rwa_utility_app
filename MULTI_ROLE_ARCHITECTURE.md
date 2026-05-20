# Multi-Role Architecture Design: GateBasic with Tenant Support

## Current State (2-Role System)

### Existing Roles
```
ADMIN (Society Management)
├── Create/Edit members
├── Verify payments
├── Create dues (maintenance demands)
├── Manage issues
├── Post notices
├── Track expenses
└── View all data

RESIDENT/USER (Flat Owner)
├── Pay maintenance
├── Report issues
├── View notices
├── See directory
├── View expenses
├── Generate receipts
└── View own data only
```

---

## Proposed 3-Role Architecture

### Role Hierarchy & Responsibilities

```
┌─────────────────────────────────────────────────────────────────┐
│                         SOCIETY SYSTEM                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐   ┌──────────────────┐   ┌────────────┐ │
│  │     ADMIN        │   │    RESIDENT      │   │   TENANT   │ │
│  │  (Administrator) │   │  (Flat Owner)    │   │  (Renter)  │ │
│  └──────────────────┘   └──────────────────┘   └────────────┘ │
│                                                                 │
│  Type: 1 per society   Type: 1 per flat      Type: M to 1 flat│
│  UID: society_admin    UID: unit owner       UID: renter      │
│  Email: verified       Email: verified       Email: verified   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Feature Permission Matrix

| Feature | Admin | Resident | Tenant |
|---------|:-----:|:--------:|:------:|
| **User Management** | | | |
| Create members | ✅ | ❌ | ❌ |
| Edit own profile | ✅ | ✅ | ✅ |
| Edit other profiles | ✅ | ❌ | ❌ |
| View directory | ✅ | ✅ | ⚠️ (limited) |
| **Payment System** | | | |
| View invoices | ✅ | ✅ | ⚠️ (if linked) |
| Submit payment | ✅ | ✅ | ❌ |
| Verify payment | ✅ | ❌ | ❌ |
| Download receipts | ✅ | ✅ | ❌ |
| **Maintenance Dues** | | | |
| Create dues | ✅ | ❌ | ❌ |
| View dues | ✅ | ✅ | ⚠️ (informational) |
| **Issues/Complaints** | | | |
| Report issues | ✅ | ✅ | ✅ |
| View own issues | ✅ | ✅ | ✅ |
| View all issues | ✅ | ❌ | ❌ |
| Respond to issues | ✅ | ❌ | ❌ |
| Close issues | ✅ | ❌ | ❌ |
| **Notices** | | | |
| Post notices | ✅ | ❌ | ❌ |
| View notices | ✅ | ✅ | ✅ |
| **Expenses** | | | |
| View expenses | ✅ | ✅ | ❌ |
| Create expenses | ✅ | ❌ | ❌ |
| **QR Pass** | | | |
| Generate passes | ✅ | ✅ | ⚠️ (limited) |
| Manage passes | ✅ | ✅ | ❌ |
| **Profile** | | | |
| View own profile | ✅ | ✅ | ✅ |
| Edit own profile | ✅ | ✅ | ✅ |
| View settings | ✅ | ✅ | ✅ |

**Legend**: ✅ = Full Access | ⚠️ = Limited Access | ❌ = No Access

---

## Updated Firestore Schema

### 1. Users Collection (Enhanced)

```json
{
  "users": {
    "{userId}": {
      "name": "String",
      "email": "String (unique)",
      "phone": "String",
      "profile_photo": "String (URL)",
      "role": "String", // NEW FIELD: 'admin' | 'resident' | 'tenant'
      "status": "String", // 'active' | 'inactive'
      "created_at": "Timestamp",
      "updated_at": "Timestamp",
      
      // FOR RESIDENT & TENANT USERS
      "unit_info": {
        "house_no": "String",
        "flat_no": "String",
        "wing": "String",
        "building": "String"
      },
      
      // FOR TENANT USERS ONLY (NEW)
      "tenant_info": {
        "owner_uid": "String", // Reference to flat owner (resident)
        "move_in_date": "Timestamp",
        "move_out_date": "Timestamp (optional)",
        "is_active": "Boolean",
        "contract_url": "String (optional)"
      },
      
      // FOR ADMIN USERS ONLY
      "admin_info": {
        "permissions": ["Array of permission strings"],
        "created_by": "String",
        "society_id": "String"
      }
    }
  }
}
```

### 2. New: Tenant-Owner Mapping Collection (NEW)

```json
{
  "tenant_mappings": {
    "{mappingId}": {
      "tenant_uid": "String",
      "owner_uid": "String",
      "house_no": "String",
      "flat_no": "String",
      "move_in_date": "Timestamp",
      "move_out_date": "Timestamp (optional)",
      "is_active": "Boolean",
      "created_at": "Timestamp",
      "created_by": "String (admin who created)"
    }
  }
}
```

### 3. Issues Collection (Enhanced)

```json
{
  "issues": {
    "{issueId}": {
      "uid": "String", // Can be resident or tenant
      "reporter_name": "String",
      "reporter_role": "String", // 'resident' | 'tenant'
      "unit_info": {
        "house_no": "String",
        "flat_no": "String"
      },
      "category": "String",
      "description": "String",
      "status": "String",
      "created_at": "Timestamp",
      "comments": ["Array"],
      "images": ["Array of URLs"],
      
      // NEW FIELD
      "visible_to_residents": "Boolean" // Can owner see this issue?
    }
  }
}
```

### 4. Invoices Collection (Enhanced)

```json
{
  "invoices": {
    "{invoiceId}": {
      "uid": "String", // Only for residents/owners
      "title": "String",
      "amount": "Number",
      "due_date": "Timestamp",
      "created_at": "Timestamp",
      
      // NEW FIELD: Who can view this?
      "visibility": "String", // 'owner_only' | 'owner_and_tenant'
      
      // If tenant can see it
      "tenant_visible": "Boolean"
    }
  }
}
```

---

## Updated Firestore Security Rules

### Key Rule Changes

```javascript
// Helper functions
function isAdmin(userId) {
  return get(/databases/$(database)/documents/users/$(userId)).data.role == 'admin';
}

function isResident(userId) {
  return get(/databases/$(database)/documents/users/$(userId)).data.role == 'resident';
}

function isTenant(userId) {
  return get(/databases/$(database)/documents/users/$(userId)).data.role == 'tenant';
}

function isOwner(userId, flatId) {
  return isResident(userId) && 
         get(/databases/$(database)/documents/users/$(userId)).data.unit_info.flat_no == flatId;
}

function getTenantOwner(tenantId) {
  let tenantUser = get(/databases/$(database)/documents/users/$(tenantId)).data;
  return tenantUser.tenant_info.owner_uid;
}

// Tenant can only access their owner's data
function canAccessUnitData(userId, ownerUid) {
  return userId == ownerUid || 
         (isTenant(userId) && getTenantOwner(userId) == ownerUid);
}

// Updated invoices rules
match /invoices/{document=**} {
  allow read: if request.auth.uid != null && (
    isAdmin(request.auth.uid) ||
    resource.data.uid == request.auth.uid ||
    // Tenant can see if visibility allows it
    (isTenant(request.auth.uid) && 
     resource.data.visibility == 'owner_and_tenant' &&
     getTenantOwner(request.auth.uid) == resource.data.uid)
  );
  allow create: if request.auth.uid != null && isResident(request.auth.uid);
  allow update: if isAdmin(request.auth.uid);
}

// Updated issues rules
match /issues/{document=**} {
  allow read: if request.auth.uid != null && (
    isAdmin(request.auth.uid) ||
    resource.data.uid == request.auth.uid ||
    // Resident/tenant can see unit issues
    resource.data.unit_info.flat_no == getUnitInfo(request.auth.uid).flat_no
  );
  allow create: if request.auth.uid != null && (
    isResident(request.auth.uid) || isTenant(request.auth.uid)
  );
}
```

---

## Screen Navigation Changes

### Updated Dashboard Routing

```dart
// main.dart - Enhanced role checking

Future<Widget> _getLandingPage() async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) return LoginScreen();
  
  final doc = await Firestore.collection('users')
    .doc(user.uid)
    .get();
  
  final role = doc['role']; // 'admin' | 'resident' | 'tenant'
  
  switch(role) {
    case 'admin':
      return AdminDashboard();
    case 'resident':
      return ResidentDashboard(userData: doc.data());
    case 'tenant':
      return TenantDashboard(userData: doc.data());
    default:
      return LoginScreen();
  }
}
```

### New Dashboards

#### **Admin Dashboard** (7 screens - unchanged)
```
┌─────────────────────┐
│   Admin Dashboard   │
├─────────────────────┤
│ 👥 Members          │
│ 💳 Pay (verify)     │
│ 📋 Dues             │
│ 🐛 Issues           │
│ 📊 Expenses         │
│ 📢 Notices          │
│ 👤 Profile          │
└─────────────────────┘
```

#### **Resident Dashboard** (6 screens - unchanged)
```
┌─────────────────────┐
│ Resident Dashboard  │
├─────────────────────┤
│ 🏠 Home             │
│ 💳 Pay              │
│ 🐛 Issues           │
│ 📢 Notices          │
│ 👥 Directory        │
│ 📋 Expenses         │
└─────────────────────┘
```

#### **Tenant Dashboard** (NEW - 5 screens)
```
┌─────────────────────┐
│  Tenant Dashboard   │
├─────────────────────┤
│ 🏠 Home             │
│ 🐛 Issues           │
│ 📢 Notices          │
│ 👥 Directory        │
│ 👤 Profile          │
└─────────────────────┘
```

---

## Implementation Strategy

### Phase 1: Database & Backend Setup

**Step 1.1: Update Firestore Collections**
- Add `role` field to users collection
- Add `tenant_info` object to users
- Create `tenant_mappings` collection
- Update `issues`, `invoices` schema

**Step 1.2: Update Firestore Security Rules**
- Add helper functions for role checks
- Update collection rules for tenant access
- Test all permission scenarios

**Step 1.3: Create Cloud Functions**
```
functions/
├── onTenantCreated.js          // Create mapping, send email
├── onTenantDeleted.js          // Archive mapping
├── getTenantsByOwner.js        // List all tenants for owner
├── syncTenantData.js           // Keep tenant sync'd with owner unit
└── notifyTenantOfIssue.js      // Notify tenant of relevant issues
```

### Phase 2: Login & Authentication

**Step 2.1: Update LoginScreen**
- Add role selection during signup
- If tenant → show flat selection dropdown
- If tenant → require owner email verification
- Store role in Firestore

**Step 2.2: Enhanced User Creation**
```dart
// During signup:
if (role == 'tenant') {
  // Show form to enter owner email
  // Look up owner in Firestore
  // Create tenant_mapping document
  // Send email to owner for approval (optional)
}
```

### Phase 3: UI Components

**Step 3.1: Create TenantDashboard**
```
lib/screens/tenant/
├── tenant_dashboard.dart        // Main navigation
├── tenant_home_screen.dart      // Home/overview
├── tenant_issues_screen.dart    // Report issues (simplified)
├── tenant_notices_screen.dart   // View notices
├── tenant_directory_screen.dart // Limited directory view
└── tenant_profile_screen.dart   // Profile management
```

**Step 3.2: Create Shared Components**
```
lib/widgets/
├── role_badge.dart              // Display user role
├── unit_card.dart               // Show unit info
├── issue_card_tenant.dart       // Tenant-specific issue view
└── notice_card_shared.dart      // Shared notice component
```

**Step 3.3: Update Existing Screens**
- `pay_screen.dart` - Hide from tenant
- `directory_screen.dart` - Limit to unit members for tenant
- `issues_screen.dart` - Show/hide tenant-reported issues
- `notices_screen.dart` - Show to all roles

### Phase 4: Features by Role

**Step 4.1: Issue Reporting**
```dart
// When tenant reports issue:
- Pre-fill with tenant's unit info
- Owner can see tenant issues (optional checkbox)
- Admin sees all issues with reporter role
- Issues tagged with reporter type
```

**Step 4.2: Payment Visibility**
```dart
// Tenant options:
- Can view but not pay (locked payment button)
- Or see "Contact owner to pay"
- Show owner UID for reference
```

**Step 4.3: Directory Access**
```dart
// Tenant limited view:
- Only see other tenants in same unit
- Cannot search entire directory
- Cannot copy contact info
- Can see owner (flat contact)
```

---

## Database Migration Plan

### Step-by-Step for Existing Users

```sql
-- 1. Add new fields to existing users
UPDATE users SET 
  role = 'resident',  // Assume existing are residents
  tenant_info = NULL,
  updated_at = NOW()
WHERE role IS NULL;

-- 2. Update admin users if needed
UPDATE users SET 
  role = 'admin',
  admin_info = {...},
  updated_at = NOW()
WHERE email IN ('admin1@society.com', 'admin2@society.com');

-- 3. Backup old data
// Export users collection before migration
```

---

## API/Cloud Functions Updates

### New Endpoints Needed

```javascript
// 1. Create Tenant
POST /createTenant
{
  "email": "tenant@example.com",
  "name": "Tenant Name",
  "phone": "9999999999",
  "owner_uid": "owner_id",
  "flat_no": "101"
}
Response: { success: true, tenantUid: "xxx" }

// 2. Assign Tenant to Owner
POST /assignTenantToOwner
{
  "tenant_uid": "tenant_id",
  "owner_uid": "owner_id"
}

// 3. Get Owner's Tenants
GET /getTenants/{ownerUid}
Response: [{ uid, name, flat_no, move_in_date, ... }]

// 4. Remove Tenant
DELETE /removeTenant/{tenantUid}
{
  "owner_uid": "owner_id"
}

// 5. Tenant Statistics
GET /getTenantStats/{societyId}
Response: { total: 50, by_building: {...}, occupancy: 85% }
```

---

## Frontend State Changes

### Update User Model

```dart
class User {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // 'admin' | 'resident' | 'tenant'
  final UnitInfo unitInfo;
  final TenantInfo? tenantInfo; // Null if not tenant
  final AdminInfo? adminInfo;   // Null if not admin
  
  bool get isAdmin => role == 'admin';
  bool get isResident => role == 'resident';
  bool get isTenant => role == 'tenant';
}

class TenantInfo {
  final String ownerUid;
  final DateTime moveInDate;
  final DateTime? moveOutDate;
  final bool isActive;
  final String? contractUrl;
}

class AdminInfo {
  final List<String> permissions;
  final String createdBy;
  final String societyId;
}
```

### Update Provider (if using)

```dart
class UserProvider extends ChangeNotifier {
  User? _user;
  
  bool get canPay => _user?.isResident ?? false;
  bool get canManageMembers => _user?.isAdmin ?? false;
  bool get canReportIssues => _user?.isResident ?? false || _user?.isTenant ?? false;
  
  List<String> getAccessibleScreens() {
    if (_user?.isAdmin ?? false) {
      return ['members', 'pay', 'dues', 'issues', 'expenses', 'notices', 'profile'];
    } else if (_user?.isResident ?? false) {
      return ['home', 'pay', 'issues', 'notices', 'directory', 'expenses', 'profile'];
    } else if (_user?.isTenant ?? false) {
      return ['home', 'issues', 'notices', 'directory', 'profile'];
    }
    return [];
  }
}
```

---

## Testing Checklist

### Unit Testing
- [ ] Role-based access control for each feature
- [ ] Tenant can only see own unit data
- [ ] Resident can see tenant issues (if enabled)
- [ ] Admin sees all data

### Integration Testing
- [ ] Tenant signup flow
- [ ] Owner-tenant mapping
- [ ] Issue visibility for tenant
- [ ] Payment visibility for tenant
- [ ] Directory filtering

### Security Testing
- [ ] Tenant can't access other unit invoices
- [ ] Tenant can't create dues
- [ ] Tenant can't verify payments
- [ ] Tenant can't view expenses
- [ ] Firestore rules block unauthorized access

---

## Deployment Plan

### Release Phases

**Phase 1 (Week 1-2)**: Backend
- Deploy Firestore schema changes
- Deploy Cloud Functions
- Update security rules
- Test thoroughly

**Phase 2 (Week 3)**: Frontend
- Update login/signup screens
- Create TenantDashboard
- Update existing screens
- Internal testing

**Phase 3 (Week 4)**: Rollout
- Beta test with pilot users
- Monitor for issues
- Full deployment
- Provide documentation

---

## Configuration File Updates

### Updated app_config.dart

```dart
const class AppConfig {
  // Supported user roles
  static const List<String> SUPPORTED_ROLES = ['admin', 'resident', 'tenant'];
  
  // Role-based features
  static const Map<String, List<String>> ROLE_FEATURES = {
    'admin': ['members', 'pay', 'dues', 'issues', 'expenses', 'notices', 'profile'],
    'resident': ['home', 'pay', 'issues', 'notices', 'directory', 'expenses', 'profile'],
    'tenant': ['home', 'issues', 'notices', 'directory', 'profile'],
  };
  
  // Feature access matrix
  static const Map<String, Map<String, bool>> FEATURE_ACCESS = {
    'payment': {'admin': true, 'resident': true, 'tenant': false},
    'expenses': {'admin': true, 'resident': true, 'tenant': false},
    'issues': {'admin': true, 'resident': true, 'tenant': true},
    'notices': {'admin': true, 'resident': true, 'tenant': true},
  };
}
```

---

## Summary

| Aspect | Current | With Tenant | Benefit |
|--------|---------|-------------|---------|
| Roles | 2 | 3 | More granular control |
| Collections | 7 | 8 (+tenant_mappings) | Better data modeling |
| Screens | 13 | 18 (+5 tenant screens) | Complete tenant UX |
| Rules | Simple | Complex but secure | Better data isolation |
| Complexity | Medium | High | Production-ready |

---

## Next Steps

1. **Validate Design**: Review this architecture with stakeholders
2. **Create Detailed Tasks**: Break down Phase 1-4 into Git issues
3. **Database Migration**: Plan data migration for existing users
4. **Timeline**: Estimate development time per phase
5. **Testing**: Create comprehensive test cases
6. **Documentation**: Update user guides for each role

---

**Status**: Design Complete ✅  
**Ready for**: Development Phase 1
