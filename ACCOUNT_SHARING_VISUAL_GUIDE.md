# Account Sharing - Visual Guide
## Simple & Powerful Multi-User Model

---

## 🎯 The Core Idea

```
BEFORE (Current System):
┌─ Flat 101 Account
│  └─ Rajesh Kumar
│     ├─ Can pay
│     ├─ Can report issues
│     └─ Only one person can access

AFTER (With Account Sharing):
┌─ Flat 101 Account
│  ├─ Rajesh Kumar (Owner)
│  ├─ Jane Kumar (Spouse) 
│  ├─ John (Tenant)
│  └─ Mike (Roommate)
│
│  All 4 people can:
│  ✅ Pay maintenance
│  ✅ Report issues
│  ✅ View invoices
│  ✅ See receipts
│  
│  Only Rajesh can:
│  ✅ Add/Remove users
```

---

## 📊 Simple Comparison

| Scenario | Current | With Sharing |
|----------|---------|-------------|
| Rajesh pays bill | ✅ Can pay | ✅ Can pay |
| Jane pays bill | ❌ Cannot | ✅ Can pay |
| John sees invoice | ❌ Cannot | ✅ Can see |
| Add new user | ❌ Not possible | ✅ Easy |
| Everyone sees same data | ✅ | ✅ |
| Role-based limits | ❌ | ❌ |

---

## 🔑 Key Differences

### Current System
```
Flat 101
  └─ Rajesh (resident role)
     ├─ Pays maintenance
     ├─ Reports issues
     └─ [Only person]

Jane or John want access?
  → NO WAY TO DO IT
  → Have to share password (bad!)
  → No audit trail
```

### New Account Sharing System
```
Flat 101
  ├─ Rajesh (resident role) - Account Owner
  │   ├─ Can do everything
  │   ├─ Can add/remove users
  │   └─ Linked_as: "owner"
  │
  ├─ Jane (resident role) - Added User
  │  ├─ Can do everything (except add/remove)
  │  └─ Linked_as: "spouse"
  │
  ├─ John (resident role) - Added User
  │  ├─ Can do everything (except add/remove)
  │  └─ Linked_as: "tenant"
  │
  └─ Mike (resident role) - Added User
     ├─ Can do everything (except add/remove)
     └─ Linked_as: "roommate"

Features:
✅ No shared passwords
✅ Audit trail (who added whom)
✅ Easy to add/remove
✅ Clean separation
```

---

## 📱 User Experience

### Rajesh's Perspective (Owner)

```
LOGIN AS RAJESH
  ↓
Dashboard shows:
  🏠 Home
  💳 Pay
  🐛 Issues
  📢 Notices
  👥 Directory
  📊 Expenses
  👨‍👩‍👧 MANAGE TENANTS ← NEW
  👤 Profile

CLICK "MANAGE TENANTS"
  ↓
Shows current members:
  ├─ Rajesh Kumar (Owner) [Can't remove]
  ├─ Jane Kumar (Spouse) [Remove button]
  ├─ John (Tenant) [Remove button]
  └─ Mike (Roommate) [Remove button]

CLICK "ADD USER TO ACCOUNT"
  ↓
Dialog:
  Name: _______________
  Email: ______________
  Relationship: [Spouse ▼]
  
  [Cancel] [Add User]

System:
  ✅ Creates account for Jane's friend
  ✅ Links to Rajesh's flat
  ✅ Sends setup email
  ✅ Adds to flat_members array
  ✅ All existing users see new member
```

### Jane's Perspective (Added User)

```
EMAIL FROM APP:
"Your account is ready! Set password here"

CLICK LINK
  ↓
Setup page:
  Email: jane@example.com
  New Password: ________________
  [Set Password]

LOGIN WITH JANE'S CREDENTIALS
  ↓
Dashboard shows:
  Same as Rajesh! ✅
  
  🏠 Home
  💳 Pay
  🐛 Issues
  📢 Notices
  👥 Directory
  📊 Expenses
  👤 Profile

PAY MAINTENANCE
  ↓
  Payment created
  ✅ Both Jane and Rajesh see it
  ✅ Payment marked as paid
  ✅ Both get notification

REPORT ISSUE
  ↓
  Issue created
  ✅ Both can see issue details
  ✅ Both get comments/updates
```

---

## 🔐 Behind The Scenes (Firestore)

### Rajesh's User Document
```json
{
  "uid": "rajesh_uid_123",
  "name": "Rajesh Kumar",
  "email": "rajesh@example.com",
  "phone": "9876543210",
  "role": "resident",
  "unit_info": {
    "flat_no": "101",
    "wing": "A",
    "building": "GateBasic Heights"
  },
  "account_link": {
    "primary_owner_uid": null,      ← He's the owner
    "linked_as": "owner",
    "linked_on": "2026-05-15T10:00:00Z",
    "linked_by": "system"
  },
  "flat_members": [
    "rajesh_uid_123",               ← His UID
    "jane_uid_456",                 ← Jane's UID
    "john_uid_789",                 ← John's UID
    "mike_uid_012"                  ← Mike's UID
  ]
}
```

### Jane's User Document
```json
{
  "uid": "jane_uid_456",
  "name": "Jane Kumar",
  "email": "jane@example.com",
  "phone": "9123456789",
  "role": "resident",               ← Same role!
  "unit_info": {
    "flat_no": "101",               ← Same flat!
    "wing": "A",
    "building": "GateBasic Heights"
  },
  "account_link": {
    "primary_owner_uid": "rajesh_uid_123",  ← Linked to Rajesh
    "linked_as": "spouse",
    "linked_on": "2026-05-10T14:20:00Z",
    "linked_by": "rajesh_uid_123"   ← Rajesh added her
  },
  "flat_members": [
    "rajesh_uid_123",               ← Same list!
    "jane_uid_456",
    "john_uid_789",
    "mike_uid_012"
  ]
}
```

### Invoice (Shared by All)
```json
{
  "id": "invoice_1",
  "uid": "rajesh_uid_123",          ← Belong to Rajesh's flat
  "title": "May 2026 Maintenance",
  "amount": 5000,
  "due_date": "2026-05-30",
  "flat_no": "101"
}

Who can see this?
  ✅ Rajesh (uid: rajesh_uid_123) - It's his invoice
  ✅ Jane (uid: jane_uid_456) - Same flat_no (101)
  ✅ John (uid: john_uid_789) - Same flat_no (101)
  ✅ Mike (uid: mike_uid_012) - Same flat_no (101)
  ✅ Admin - Can see all
```

### Payment (Made by Any Member)
```json
{
  "id": "payment_1",
  "uid": "jane_uid_456",            ← Made by Jane!
  "invoice_id": "invoice_1",
  "amount": 5000,
  "payment_date": "2026-05-15T10:30:00Z",
  "status": "verified"
}

Who can see this?
  ✅ Rajesh - Same flat
  ✅ Jane - She made it
  ✅ John - Same flat
  ✅ Mike - Same flat
  ✅ Admin - Can see all
```

---

## 🎯 Data Sharing Logic

### Rule: Same Flat Members Can See Each Other's Data

```
FIRESTORE RULE (Simplified):

Can user A see user B's invoice?
  ├─ Is user A an admin?
  │  └─ YES → See it ✅
  │
  └─ Are A and B on same flat?
     ├─ A's flat_no == B's flat_no?
     │  └─ YES → See it ✅
     │
     └─ NO → Cannot see ❌

EXAMPLE:
  User A: jane (flat 101)
  User B: rajesh (flat 101)
  
  jane.flat_no (101) == rajesh.flat_no (101)?
  └─ YES → Jane can see Rajesh's invoices ✅
```

---

## 🚀 Complete Flow Diagram

### Adding a New User to Flat 101

```
1. RAJESH CLICKS "ADD USER"
   ↓
   
2. FILLS FORM
   Name: "Sarah (Friend)"
   Email: "sarah@email.com"
   Relationship: "Guest"
   ↓
   
3. SYSTEM CHECKS
   ✅ Email not registered?
   ✅ Rajesh is account owner?
   ↓
   
4. CREATES SARAH'S ACCOUNT
   ├─ New user doc with:
   │  ├─ role: "resident"
   │  ├─ flat_no: "101"
   │  ├─ primary_owner_uid: "rajesh_uid_123"
   │  ├─ linked_as: "guest"
   │  └─ flat_members: [rajesh, jane, john, mike, SARAH]
   │
   └─ Updates all existing members:
      ├─ Rajesh's flat_members += [sarah]
      ├─ Jane's flat_members += [sarah]
      ├─ John's flat_members += [sarah]
      └─ Mike's flat_members += [sarah]
   
   ↓
   
5. SENDS EMAIL TO SARAH
   Subject: "You've been added to Flat 101 Account"
   "Set your password: [LINK]"
   ↓
   
6. SARAH CLICKS LINK
   ├─ Goes to setup page
   ├─ Sets password
   └─ Account activated ✅
   
   ↓
   
7. SARAH LOGS IN
   ├─ Sees Flat 101 invoices
   ├─ Can pay maintenance
   ├─ Can report issues
   └─ Full resident access ✅
   
   ↓
   
8. RAJESH REMOVES SARAH (Later)
   ├─ Clicks "Remove" next to Sarah
   ├─ Sarah's account marked as removed
   ├─ Sarah's flat_members removed from all
   └─ Sarah can no longer access ✅
```

---

## 💰 Payment Scenario

```
SCENARIO: Jane pays the maintenance bill

STEP 1: Jane logs in
STEP 2: Jane goes to Pay tab
STEP 3: Sees invoice: "May Maintenance - ₹5000"
STEP 4: Clicks "Pay Now"
STEP 5: Uploads proof image
STEP 6: Submits payment

SYSTEM CREATES:
  ├─ payment document
  │  ├─ uid: "jane_uid_456" (Who paid)
  │  ├─ invoice_id: "invoice_1"
  │  ├─ amount: 5000
  │  └─ status: "pending"
  │
  └─ Sends notifications:
     ├─ Jane: "Payment submitted, awaiting verification"
     ├─ Rajesh: "Jane paid ₹5000 for flat, awaiting admin verification"
     └─ Admin: "New payment from Flat 101 to verify"

ADMIN VERIFIES:
  ├─ Clicks "Verify"
  ├─ Status changes to "verified"
  │
  └─ Notifications sent to:
     ├─ Jane: "✅ Payment verified"
     ├─ Rajesh: "✅ Jane's payment verified"
     └─ Both get receipt PDF

RESULT:
  ✅ Payment recorded
  ✅ Invoice marked as paid
  ✅ Both Rajesh and Jane see it
  ✅ Clear audit trail (Jane paid)
```

---

## 👥 Directory With Shared Users

```
WHEN JANE OPENS DIRECTORY:
  
  "All Members"
  
  ├─ Rajesh Kumar
  │  House: 101
  │  Phone: 9876543210
  │  Email: rajesh@example.com
  │  [Copy Phone] [Copy Email]
  │
  ├─ Jane Kumar (You)
  │  House: 101
  │  Phone: 9123456789
  │  Email: jane@example.com
  │  [Copy Phone] [Copy Email]
  │
  ├─ John (Tenant)
  │  House: 101
  │  Phone: 9111111111
  │  Email: john@example.com
  │  [Copy Phone] [Copy Email]
  │
  ├─ Mike (Roommate)
  │  House: 102  ← Different house, not shown
  │  ↓ (Not in same flat, filtered out)

FILTERED FOR JANE:
Only showing people in Flat 101:
  ✅ Rajesh (flat_no: 101)
  ✅ Jane (flat_no: 101)
  ✅ John (flat_no: 101)
  ❌ Mike (flat_no: 102) - different flat
```

---

## 🔒 Security & Privacy

### What Can't Happen

```
❌ Jane can't see Flat 102 data
   (Different flat_no)

❌ Jane can't remove Rajesh
   (Not the account owner)

❌ John can't add new users
   (Not the account owner)

❌ A hacker can't delete Jane
   (Firestore rules prevent it)

❌ Jane can't see other units' invoices
   (Firestore rules filter by flat_no)
```

### What Is Protected

```
✅ Each user has unique password
✅ Firestore rules enforce flat membership
✅ Admin controls can't be hijacked
✅ Audit trail shows who added whom
✅ Users can be easily removed
✅ No shared passwords needed
```

---

## 📋 Change Summary

### What Stays the Same
- ✅ 2 main roles: Admin & Resident
- ✅ All existing features work
- ✅ Dashboard structure unchanged
- ✅ Payment system unchanged
- ✅ Issue reporting unchanged
- ✅ Security model enhanced

### What's New
- ✅ Account sharing capability
- ✅ "Manage Tenants" screen
- ✅ Add/Remove users UI
- ✅ `account_link` field in users
- ✅ `flat_members` array in users
- ✅ Enhanced Firestore rules

### What's Different
- Users on same flat can see each other's data
- Payments/issues attributed to who made them
- Owner can manage flat members
- Setup email for new users

---

## 🎓 Real-World Examples

### Example 1: Family Flat
```
Flat 301 - Nuclear Family
├─ Rajesh Kumar (Owner) - Father
│  └─ Can manage members
├─ Priya Kumar (Spouse) - Mother
│  └─ Can pay bills for family
├─ Arjun (Son) - Uses app to report issues
│  └─ "Water leakage in bathroom"
└─ Isha (Daughter) - Helps with payments
   └─ Pays bill from her bank account

Everyone sees:
  ✅ Same invoices
  ✅ Same payments (who paid what)
  ✅ Same issues (who reported what)
  ✅ Full family transparency
```

### Example 2: Rental Property
```
Flat 202 - Rental Unit
├─ Rajesh Kumar (Owner) - Landlord
│  └─ Can manage tenants
└─ John Smith (Tenant) - Renter
   └─ Full access to pay and report issues

When John pays:
  ✅ Rajesh sees John paid
  ✅ Payment recorded
  ✅ Clear audit trail
  ✅ John gets receipt

When John reports issue:
  ✅ Rajesh and admin see it
  ✅ John marked as reporter
  ✅ John notified of updates
```

### Example 3: Shared Housing
```
Flat 101 - 3 Roommates
├─ Rajesh (Owner-primary)
├─ Jane (Roommate 1)
├─ Mike (Roommate 2)
└─ Sarah (Roommate 3)

Each can independently:
  ✅ Pay maintenance
  ✅ Report issues
  ✅ See all notifications
  ✅ Download receipts

Rajesh can:
  ✅ Remove anyone (except himself)
  ✅ Add new roommates
  ✅ Full control
```

---

## ✨ Key Benefits

| Benefit | Description |
|---------|-------------|
| **Simple** | No complex role system, everyone is "resident" |
| **Flexible** | Any relationship type (spouse, tenant, roommate, etc.) |
| **Secure** | No shared passwords, clear audit trail |
| **Easy to Manage** | One-click to add/remove users |
| **Complete Access** | Shared users get ALL resident features |
| **Transparent** | Everyone sees who did what |
| **Scalable** | Works for 1 person or 10 people per flat |
| **Familiar** | Works like "sharing an account" (like email) |

---

**Status**: ✅ Simple Account Sharing Model Ready for Development
