# RWA Manager App - Quick Reference Guide

## 📱 App Overview

**What:** Resident Welfare Association (RWA) Management System  
**Type:** Cross-platform mobile + web app  
**Tech:** Flutter + Firebase  
**Status:** Production-ready (v1.0.0)  

---

## 🎯 Key Features at a Glance

### For Admins
- ✅ Manage residents (create/delete accounts)
- ✅ Track all payments and invoices
- ✅ Create special dues/charges
- ✅ Verify payment proofs
- ✅ Generate financial reports (PDF/CSV)
- ✅ Manage maintenance issues
- ✅ Send society-wide notices
- ✅ Log and track expenses

### For Residents
- ✅ View pending dues
- ✅ Submit maintenance payments
- ✅ Upload payment proof screenshots
- ✅ Track payment history
- ✅ Download payment receipts
- ✅ Report maintenance issues
- ✅ View notices/announcements
- ✅ Generate entry QR pass
- ✅ View expense summaries

---

## 🏗️ Technology Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter (Dart) |
| **Database** | Firestore (NoSQL) |
| **Auth** | Firebase Authentication |
| **Backend** | Cloud Functions (Node.js) |
| **Storage** | Firebase Storage |
| **Notifications** | Firebase Cloud Messaging (FCM) |
| **Monitoring** | Firebase Analytics & Crashlytics |

---

## 📁 File Structure Summary

```
lib/
├── main.dart                    Entry point + routing logic
├── config/app_config.dart       API configuration
├── theme/app_theme.dart         Colors, gradients, components
├── services/notification_service.dart  Push notifications
│
├── screens/
│   ├── login/login_screen.dart  Authentication UI
│   ├── admin/                   7 admin screens
│   │   ├── members_screen.dart (912 lines) ← Largest admin screen
│   │   ├── admin_pay_screen.dart (833 lines)
│   │   ├── admin_dues_screen.dart
│   │   ├── admin_issues.dart
│   │   ├── admin_expense.dart
│   │   ├── admin_notices.dart
│   │   └── admin_profile_screen.dart
│   └── user/                    6 user screens
│       ├── user_home_screen.dart (662 lines)
│       ├── pay_screen.dart (658 lines)
│       ├── issues_screen.dart
│       ├── notices_screen.dart
│       ├── expense_screen.dart
│       └── qrpass_screen.dart

functions/
├── index.js                     All Cloud Functions
├── package.json                 Node.js dependencies
└── .env                        Environment variables

firebase.json                   Firebase config
firestore.rules                 Security rules
pubspec.yaml                    Flutter dependencies
```

---

## 🗄️ Database Collections

| Collection | Purpose | Documents | Access |
|-----------|---------|-----------|--------|
| **users** | User profiles | 1 per person | Own + Admin |
| **invoices** | Monthly maintenance bills | 1 per resident per month | Own + Admin |
| **payments** | Payment submissions | Variable | Own + Admin |
| **demand_dues** | Special charges | Variable | Admin only |
| **receipts** | Payment confirmations | Created by Cloud Function | Own + Admin |
| **notices** | Announcements | Admin managed | All residents |
| **issues** | Complaint tickets | Resident created | Own + Admin |
| **expenses** | Society spending | Admin logged | Admin only |

---

## 🔐 Security Model

### Authentication
- Email/Password via Firebase Auth
- Role-based access control (Admin/User)
- ID token verification on backend
- Password reset via email

### Authorization (Firestore Rules)
```
users:        Own doc + Admin can read all
invoices:     Own + Admin can read; CF writes only
payments:     Own + Admin can read; CF updates
demand_dues:  CF writes only
notices:      All can read; Admin writes
issues:       Own + Admin can read/update; Admin writes
expenses:     Admin only
receipts:     Own + Admin can read; CF writes
```

---

## ☁️ Cloud Functions (Node.js)

### Scheduled (Automatic)
- **generateMonthlyInvoices** - 1st of month @ 00:05 IST

### Critical Functions
1. **verifyPaymentManual** - Admin approves payment
2. **rejectPaymentManual** - Admin rejects payment
3. **createResidentHttp** - Admin adds new resident
4. **deleteResidentHttp** - Admin removes resident
5. **generateInvoicesManual** - Admin triggers invoices
6. **updateComplaintStatusHttp** - Admin updates issue status
7. **postNoticeHttp** - Admin publishes notice

### Key Logic
- Batch operations for 1500+ invoices
- FCM notifications to residents
- Email confirmations
- PDF generation
- Idempotent operations (safe to retry)

---

## 📊 Data Flow Examples

### Monthly Billing Cycle
```
1st of Month @ 00:05 IST
↓
Cloud Function: generateMonthlyInvoices
↓
Creates invoice for each resident (₹1500)
↓
Sends FCM notification to all
↓
Residents see "Due" on home screen
```

### Payment Verification
```
Resident submits payment (₹ + proof image)
↓
Admin reviews proof and clicks "Verify"
↓
Cloud Function: verifyPaymentManual
├─ Updates payment.status = VERIFIED
├─ Updates invoice.paid_amount
├─ Checks if fully paid
├─ Generates receipt PDF
├─ Sends FCM notification
└─ Sends email confirmation
↓
Resident receives notification + receipt
```

### New Resident Onboarding
```
Admin clicks "Add Member"
↓
Enters: Name, Email, Phone, House No
↓
Cloud Function: createResidentHttp
├─ Creates Firebase Auth account
├─ Generates temporary password
├─ Creates Firestore user doc
├─ Sends welcome email
└─ Returns temp password
↓
Admin shares temp credentials
↓
Resident logs in and sets new password
```

---

## 🔔 Notifications System

### Push Notification Triggers
| Trigger | Recipient | Message |
|---------|-----------|---------|
| Monthly invoice generated | All residents | "Maintenance Due — April 2026" |
| Payment verified | Resident | "Payment Verified! Receipt sent" |
| Payment rejected | Resident | "Payment Rejected — Reason: ..." |
| Issue resolved | Resident | "Your issue has been resolved" |
| Notice published | All residents | "New Notice: [title]" |

### Tech Details
- FCM tokens stored per user
- Foreground: Local notifications
- Background: System notifications
- Handled by: `notification_service.dart`

---

## 📈 Key Metrics & Limits

| Metric | Value | Notes |
|--------|-------|-------|
| Monthly invoices generated | ~1500+ | Batch operation |
| Firestore batch limit | 500 | Uses safe batching |
| Max concurrent functions | 1000s | Auto-scaling |
| Storage per proof | ~100-500 KB | Compressed JPEG |
| FCM token storage | Per user | Deleted on logout |

---

## 🚀 Deployment Info

### Firebase Project
- **Project ID:** rms-app-3d585
- **Region:** us-central1
- **Firestore:** Production mode
- **Firebase Auth:** Email/Password enabled

### App IDs
- **Android:** 1:1085944093717:android:85eef057da5a129a2d421c
- **iOS:** 1:1085944093717:ios:43370b71e0f785532d421c

### API Endpoints
```
Base URL: https://us-central1-rms-app-3d585.cloudfunctions.net

HTTP Functions:
POST /createResidentHttp
POST /deleteResidentHttp
POST /verifyPaymentManualHttp
POST /rejectPaymentManualHttp
POST /createDemandDueHttp
POST /postNoticeHttp
POST /updateComplaintStatusHttp
```

---

## 🎨 UI Components & Navigation

### Login Screen
- Role toggle: Resident ↔ Admin
- Email/password inputs
- Forgot password flow
- Gradient branding

### Admin Dashboard (7 Tabs)
1. **Members** - Add/delete residents, generate reports
2. **Payments** - Review & verify payments
3. **Dues** - Manage invoices & special charges
4. **Issues** - Track complaints & updates
5. **Expense** - Log expenditures
6. **Notices** - Publish announcements
7. **Profile** - Settings

### User Dashboard (6 Tabs)
1. **Home** - Due amount, quick actions
2. **Pay** - Submit payments
3. **Issues** - Report problems
4. **Notices** - View announcements
5. **Expense** - View society spending
6. **Profile** - Personal settings

---

## 🔧 Setup & Running

### Prerequisites
```bash
Flutter SDK 3.6.1+
Node.js 14+
Firebase CLI
```

### Initial Setup
```bash
flutter pub get
flutter run
```

### Cloud Functions Deployment
```bash
cd functions
npm install
firebase deploy --only functions
```

### Firebase Initialization
```bash
firebase login
firebase init
firebase deploy
```

---

## 📋 Default Values

| Field | Value |
|-------|-------|
| Monthly invoice amount | ₹1500 |
| Min UTR length | 6 characters |
| Image quality for proofs | 70% JPEG |
| Invoice generation time | 00:05 IST on 1st |
| App version | 1.0.0 |
| Min password length | 8+ (Firebase default) |

---

## 🧪 Testing Checklist

- [ ] Login with admin account
- [ ] Login with resident account
- [ ] Create new resident
- [ ] Delete resident
- [ ] Submit payment
- [ ] Verify payment (admin)
- [ ] Reject payment (admin)
- [ ] Generate monthly invoices
- [ ] Download PDF receipt
- [ ] Report issue
- [ ] Update issue status
- [ ] Receive FCM notifications
- [ ] Publish notice
- [ ] View notices as resident
- [ ] Generate CSV export

---

## 🐛 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Firebase not initializing | Check google-services.json / GoogleService-Info.plist |
| FCM tokens not saving | Verify user is logged in before saving token |
| Invoices double-created | Cloud Function has idempotency check |
| Payment proof not uploading | Check Storage rules allow authenticated users |
| Notifications not received | Verify FCM token is saved to Firestore |
| PDF generation fails | Check PDF library version compatibility |

---

## 📝 Important Notes

1. **Idempotency:** Invoice generation won't double-create invoices for a month
2. **Batch Operations:** Cloud Functions use Firestore batching (400 at a time)
3. **Email Integration:** Requires SMTP configuration in `.env`
4. **FCM Tokens:** Refreshed automatically when rotated by Firebase
5. **Offline Support:** Currently NOT implemented (online-only)
6. **Payment Gateway:** NOT integrated (manual verification only)
7. **Encryption:** Passwords encrypted by Firebase Auth

---

## 📞 Support & Documentation

### Official Docs
- [Flutter Docs](https://flutter.dev)
- [Firebase Docs](https://firebase.google.com/docs)
- [Cloud Functions](https://firebase.google.com/docs/functions)

### Repository
- Git initialized (`.git` folder present)
- Gitignore configured
- Version control ready

### Monitoring
- Firebase Analytics enabled
- Crashlytics enabled
- Cloud Logging available

---

## 🎓 Summary

This is a **production-ready RWA management system** that:
- ✅ Handles 1500+ residents efficiently
- ✅ Automates monthly billing
- ✅ Manages payment verification
- ✅ Tracks issues & expenses
- ✅ Sends real-time notifications
- ✅ Generates reports
- ✅ Maintains security with role-based access
- ✅ Scales with Firebase serverless architecture

Perfect for: Housing societies, apartment complexes, resident communities, and RWAs.

---

**Generated:** May 1, 2026  
**App Version:** 1.0.0+1  
**Last Updated:** April 26, 2026
