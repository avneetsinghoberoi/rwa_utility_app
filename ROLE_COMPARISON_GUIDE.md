# Role Comparison Guide: Admin vs Resident vs Tenant

## Quick Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GateBasic Role System                            │
├──────────────────────┬──────────────────────┬──────────────────────┤
│      ADMIN           │      RESIDENT        │       TENANT         │
├──────────────────────┼──────────────────────┼──────────────────────┤
│ Society Manager      │ Flat Owner           │ Renter/Tenant        │
│ Manages all units    │ Owns 1 unit          │ Rents 1 unit         │
│ Creates rules        │ Follows rules        │ Follows rules        │
│ Verifies payments    │ Makes payments       │ Cannot make payments │
│ Manages members      │ Self-manages         │ Limited profile      │
│ Posts notices        │ Views notices        │ Views notices        │
│ Handles all issues   │ Reports issues       │ Reports own issues   │
│ Views all expenses   │ Views expenses       │ No expense access    │
└──────────────────────┴──────────────────────┴──────────────────────┘
```

---

## Feature-by-Feature Comparison

### 🔐 Account & Authentication

| Feature | Admin | Resident | Tenant |
|---------|:---:|:---:|:---:|
| Create account | Via Admin setup | Self signup | Self signup |
| Select role during signup | ✅ | ✅ | ✅ |
| Link to flat owner | N/A | N/A | ✅ Required |
| Email verification | ✅ | ✅ | ✅ |
| Phone verification | ✅ | ✅ | Optional |
| Profile photo | ✅ | ✅ | ✅ |

**Signup Flow**:
```
ADMIN:        Admin creates account → Role: admin → Access AdminDashboard
RESIDENT:     Email/pass signup → Select flat → Role: resident → Access UserDashboard  
TENANT:       Email/pass signup → Select flat → Enter owner email → 
              Role: tenant → Awaits owner linking → Access TenantDashboard
```

---

### 👥 Member Management

| Feature | Admin | Resident | Tenant |
|---------|:---:|:---:|:---:|
| **View Members** | | | |
| See all members | ✅ | Limited | Limited |
| See all units | ✅ | ❌ | ❌ |
| Search directory | ✅ | ✅ | ⚠️ Same unit only |
| See contact info | ✅ | ✅ | ⚠️ Owner + unit tenants |
| **Manage Members** | | | |
| Create new account | ✅ | ❌ | ❌ |
| Assign flat to member | ✅ | ❌ | ❌ |
| Change role | ✅ | ❌ | ❌ |
| Remove member | ✅ | ❌ | ❌ |
| **Own Profile** | | | |
| Edit name | ✅ | ✅ | ✅ |
| Edit phone | ✅ | ✅ | ✅ |
| Edit photo | ✅ | ✅ | ✅ |
| View tenant list | ✅ | ✅ | ❌ |

**Example: Directory Access**
```
Admin:
  └── Can search by: Name, Flat#, Wing, Building
  └── Can see: All 100+ residents
  └── Can filter by: Role, Status, Wing

Resident:
  └── Can search by: Name, Flat#, Phone
  └── Can see: All 100+ residents
  └── Can filter by: Wing
  └── Can copy: Phone, Email

Tenant:
  └── Can search by: Name, Phone
  └── Can see: Only other tenants in unit + owner
  └── Can see: Only unit directory (3-4 people max)
  └── Can copy: Phone only
```

---

### 💳 Payment System

| Feature | Admin | Resident | Tenant |
|---------|:---:|:---:|:---:|
| **View Invoices** | | | |
| See all invoices | ✅ | ✅ (own) | ⚠️ See only |
| Filter by status | ✅ | ✅ | ❌ |
| Export invoice | ✅ | ✅ | ❌ |
| **Payment Submission** | | | |
| Submit payment | ✅ | ✅ | ❌ 🔒 Locked |
| Upload proof | ✅ | ✅ | ❌ |
| Choose payment method | ✅ | ✅ | ❌ |
| **Payment Verification** | | | |
| View pending payments | ✅ | ❌ | ❌ |
| Verify payment | ✅ | ❌ | ❌ |
| Reject payment | ✅ | ❌ | ❌ |
| Generate receipt | ✅ | ✅ | ❌ |
| Download receipt | ✅ | ✅ | ❌ |
| View payment history | ✅ | ✅ | ❌ |

**Payment Screen Views**:
```
ADMIN PAYS:              RESIDENT PAYS:           TENANT VIEWS:
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ Invoice #001     │    │ Invoice #001     │    │ Invoice #001     │
│ Amount: ₹5000    │    │ Amount: ₹5000    │    │ Amount: ₹5000    │
│                  │    │                  │    │                  │
│ [PAY NOW]  ✅    │    │ [PAY NOW]  ✅    │    │ [PAY NOW]  🔒    │
│ [UPLOAD PROOF]   │    │ [UPLOAD PROOF]   │    │ STATUS: Unpaid   │
│ [VERIFY]   ✅    │    │ [VERIFY]   ❌    │    │                  │
└──────────────────┘    └──────────────────┘    │ Paid by: Owner   │
  → Can pay for any      → Can pay only own     │ (Contact owner)  │
    resident             → No verification      └──────────────────┘
                         → Can download           → View only
                           receipt                → No download
```

---

### 📋 Maintenance Dues

| Feature | Admin | Resident | Tenant |
|---------|:---:|:---:|:---:|
| Create due cycle | ✅ | ❌ | ❌ |
| Set maintenance amount | ✅ | ❌ | ❌ |
| Create invoices | ✅ | ❌ | ❌ |
| View due dates | ✅ | ✅ | ⚠️ Informational |
| View due amount | ✅ | ✅ | ⚠️ Informational |
| Edit due | ✅ | ❌ | ❌ |
| Delete due | ✅ | ❌ | ❌ |

**Timeline Example**:
```
Admin: Creates dues cycle
   ↓
   Invoices generated for all residents
   ↓
   ├─→ Residents see in Pay tab
   │   └─→ Can pay + verify
   │
   └─→ Tenants see as info only
       └─→ Contact owner to pay
```

---

### 🐛 Issues/Complaints

| Feature | Admin | Resident | Tenant |
|---------|:---:|:---:|:---:|
| **Report Issues** | | | |
| Report new issue | ✅ | ✅ | ✅ |
| Upload photos | ✅ | ✅ | ✅ |
| Select category | ✅ | ✅ | ✅ |
| Add description | ✅ | ✅ | ✅ |
| **View Issues** | | | |
| View own issues | ✅ | ✅ | ✅ |
| View unit issues | ✅ | ✅ | ⚠️ If owner allows |
| View all issues | ✅ | ❌ | ❌ |
| Filter by status | ✅ | ✅ | ✅ |
| **Manage Issues** | | | |
| Add comments | ✅ | ❌ | ❌ |
| Update status | ✅ | ❌ | ❌ |
| Change category | ✅ | ❌ | ❌ |
| Assign to team | ✅ | ❌ | ❌ |
| Close issue | ✅ | ❌ | ❌ |

**Issue Screen Examples**:
```
ADMIN DASHBOARD:
┌─ Issues
│  ├─ Issue #42 (Water leakage)
│  │  └─ Flat 202, Mr. Singh
│  ├─ Issue #41 (Electrical fault)
│  │  └─ Flat 105, Ms. Verma
│  └─ Issue #40 (Pest control)
│     └─ Flat 405, Mr. Patel
│
│  [FILTER] [SORT] [SEARCH]
│  STATUS: Open=5 | In Progress=3 | Resolved=12

RESIDENT DASHBOARD:
┌─ Issues
│  ├─ [My Issues]
│  │  └─ Issue #42 (Water leakage)
│  │     Status: Open → Admin will respond
│  │
│  └─ [Unit Issues] (if shared)
│     └─ Issue #40 (Pest control)
│        Status: Resolved

TENANT DASHBOARD:
┌─ Issues
│  └─ [My Issues Only]
│     └─ Issue #42 (Water leakage)
│        Status: Open
│        Comment from admin: "Plumber assigned"
```

---

### 📢 Notices & Announcements

| Feature | Admin | Resident | Tenant |
|---------|:---:|:---:|:---:|
| **Create/Edit** | | | |
| Post notice | ✅ | ❌ | ❌ |
| Set priority | ✅ | ❌ | ❌ |
| Add images | ✅ | ❌ | ❌ |
| Edit notice | ✅ | ❌ | ❌ |
| Delete notice | ✅ | ❌ | ❌ |
| **View Notices** | | | |
| See all notices | ✅ | ✅ | ✅ |
| Filter by priority | ✅ | ✅ | ✅ |
| Search notices | ✅ | ✅ | ✅ |
| Get notifications | ✅ | ✅ | ✅ |

**Notification Example**:
```
All roles get same notifications:

🔔 NOTICE: Maintenance Payment Due
   "Please pay maintenance fees by 30th June"
   [Read More]

🔴 URGENT: Water Supply Maintenance
   "Water supply will be shut for 2 hours tomorrow"
   [Read More]

🟡 HIGH: Annual General Meeting
   "AGM on Sunday 10 AM at community hall"
   [Read More]
```

---

### 📊 Expenses

| Feature | Admin | Resident | Tenant |
|---------|:---:|:---:|:---:|
| **Manage Expenses** | | | |
| Create expense entry | ✅ | ❌ | ❌ |
| Categorize expense | ✅ | ❌ | ❌ |
| Add receipt | ✅ | ❌ | ❌ |
| Edit expense | ✅ | ❌ | ❌ |
| Delete expense | ✅ | ❌ | ❌ |
| **View Expenses** | | | |
| View all expenses | ✅ | ✅ | ❌ |
| Filter by category | ✅ | ✅ | ❌ |
| See charts/graphs | ✅ | ✅ | ❌ |
| Download report | ✅ | ✅ | ❌ |
| See breakdown | ✅ | ✅ | ❌ |

**Expense View Example**:
```
ADMIN & RESIDENT see:
┌─ Expenses
│  ├─ May 2026
│  │  ├─ Water maintenance: ₹2000
│  │  ├─ Electricity: ₹1500
│  │  └─ Security wages: ₹15000
│  │     Total: ₹18,500
│  │
│  [PIE CHART] [BAR CHART] [DOWNLOAD REPORT]

TENANT:
┌─ Expenses
│  └─ [Access Denied]
│     "Only owners and admin can view expenses"
```

---

### 🎟️ QR Pass (Guest Access)

| Feature | Admin | Resident | Tenant |
|---------|:---:|:---:|:---:|
| Generate pass | ✅ | ✅ | ⚠️ Limited |
| Set duration | ✅ | ✅ | ⚠️ Limited |
| Add guest name | ✅ | ✅ | ✅ |
| View pass QR | ✅ | ✅ | ✅ |
| Manage passes | ✅ | ✅ | ❌ |
| Revoke pass | ✅ | ✅ | ❌ |

**QR Pass Limitation for Tenant**:
```
Tenant can generate QR but:
  ✅ Can create 1-day guest pass
  ✅ Cannot set expiry > 1 day
  ✅ Cannot see list of all passes
  ❌ Cannot delete/revoke passes
  ❌ Cannot manage other tenants' passes
```

---

### 👤 Profile & Settings

| Feature | Admin | Resident | Tenant |
|---------|:---:|:---:|:---:|
| Edit name | ✅ | ✅ | ✅ |
| Edit phone | ✅ | ✅ | ✅ |
| Edit email | ⚠️ Admin | ⚠️ Admin | ⚠️ Admin |
| Change photo | ✅ | ✅ | ✅ |
| View unit info | ✅ | ✅ | ✅ |
| View role | ✅ | ✅ | ✅ |
| View tenant list | ✅ | ✅ | ❌ |
| Logout | ✅ | ✅ | ✅ |
| Delete account | ⚠️ Admin only | ✅ | ✅ |

---

## Data Isolation Examples

### 🔒 What Each Role Can See

```
ADMIN:
  users/
    ├─ User A (resident, Flat 101)
    ├─ User B (resident, Flat 202)
    ├─ User C (tenant, Flat 101)
    └─ User D (tenant, Flat 202)
  
  invoices/
    ├─ Invoice A (Flat 101, ₹5000)
    ├─ Invoice B (Flat 202, ₹5000)
    └─ [All invoices]
  
  payments/
    ├─ Payment 1, 2, 3... [All]
  
  issues/
    ├─ Issue 1 (Resident A reported)
    ├─ Issue 2 (Tenant C reported)
    └─ [All issues]
  
  ✅ Can see EVERYTHING

─────────────────────────────────────────

RESIDENT (Flat 101):
  users/
    ├─ User A (me - resident, Flat 101)
    ├─ User C (tenant in my unit, Flat 101)
    └─ [All members directory]
  
  invoices/
    ├─ Invoice A (my invoice, Flat 101, ₹5000)
    └─ [Only my invoices]
  
  payments/
    ├─ Payment 1 (my payment)
    └─ [Only my payments]
  
  issues/
    ├─ Issue 1 (I reported)
    ├─ Issue 2 (Tenant in my unit reported) - visible if shared
    └─ [My issues + unit issues]
  
  expenses/
    └─ [See all society expenses]
  
  ❌ Cannot see: Other residents' invoices/payments, Admin-only data
  ✅ Can see: Own data, some unit data, all shared data

─────────────────────────────────────────

TENANT (Flat 101):
  users/
    ├─ User A (owner of flat 101)
    ├─ User C (me - tenant, Flat 101)
    └─ [Limited directory - only unit members]
  
  invoices/
    ├─ Invoice A (for Flat 101) - view only
    └─ [Cannot pay]
  
  payments/
    └─ [Cannot see]
  
  issues/
    ├─ Issue 1 (I reported, Flat 101)
    └─ [Only my own issues]
  
  expenses/
    └─ [CANNOT ACCESS]
  
  ❌ Cannot see: Payments, Expenses, Other units
  ✅ Can see: Own issues, unit info, shared notices
```

---

## Use Case Examples

### Scenario 1: Payment Collection

```
MONTHLY CYCLE:

Admin Creates Dues
  ↓
Firestore: invoices/{id} → {uid: resident_A, amount: 5000}
  ↓
  ├─→ Resident A sees invoice
  │   └─→ Clicks "Pay Now"
  │       └─→ Submits ₹5000
  │
  ├─→ Tenant C sees invoice (view only)
  │   └─→ Cannot pay
  │       └─→ Message: "Contact owner"
  │
  └─→ Admin reviews
      └─→ Verifies → generates receipt

Result:
  ✅ Resident pays: Receipt generated
  ✅ Tenant aware: Invoice visible
  ✅ Admin verified: Payment processed
```

### Scenario 2: Pest Control Issue

```
ISSUE REPORTING:

Tenant C reports: "Cockroaches in kitchen"
  ↓
Firestore: issues/{id} → {uid: tenant_C, unit: 101, visible_to_owner: true}
  ↓
  ├─→ Tenant C: Sees her issue (Status: Open)
  │
  ├─→ Resident A (owner): Sees unit issue
  │   └─→ Can read but not modify
  │
  └─→ Admin: Sees all issues
      └─→ Assigns pest control team
      └─→ Updates status: "Scheduled for 15th"
      └─→ Adds comment: "Appointment at 10 AM"
  
  ↓
Both tenant & owner notified:
  🔔 "Pest control scheduled for your unit"

Issue resolved:
  Admin updates: Status = "Resolved"
  Both notified: ✅ Completed
```

### Scenario 3: AGM Notice

```
ANNOUNCEMENT TO ALL:

Admin posts notice:
  Title: "Annual General Meeting - June 20, 2026"
  Content: "Please attend AGM at 10 AM..."
  Priority: HIGH
  
  ↓
All roles get notified:
  🔴 Admin: Can edit/delete
  👤 Resident: Can read
  🏠 Tenant: Can read
  
  ✅ Everyone stays informed
```

---

## Permission Summary Table

| Action | Admin | Resident | Tenant |
|--------|:-----:|:-----:|:-----:|
| Manage members | ✅ | ❌ | ❌ |
| Create dues | ✅ | ❌ | ❌ |
| **Pay invoices** | ✅ | ✅ | ❌ |
| Verify payments | ✅ | ❌ | ❌ |
| Report issues | ✅ | ✅ | ✅ |
| Manage issues | ✅ | ❌ | ❌ |
| Post notices | ✅ | ❌ | ❌ |
| View notices | ✅ | ✅ | ✅ |
| Track expenses | ✅ | ✅ | ❌ |
| Create expenses | ✅ | ❌ | ❌ |
| Generate QR pass | ✅ | ✅ | ⚠️ |
| View directory | ✅ | ✅ | ⚠️ |
| Edit profile | ✅ | ✅ | ✅ |

---

## Key Differences at a Glance

### 🎯 Admin
- **Goal**: Run the society smoothly
- **Scope**: Everything
- **Responsibility**: Manage all operations
- **Access Level**: 100%

### 🏠 Resident  
- **Goal**: Pay bills, report issues
- **Scope**: Own unit + shared data
- **Responsibility**: Maintain property, pay dues
- **Access Level**: ~70%

### 🚪 Tenant
- **Goal**: Live peacefully, report issues
- **Scope**: Own issues + notices
- **Responsibility**: Coexist peacefully
- **Access Level**: ~30%

---

**Design Status**: ✅ Complete and Ready for Implementation
