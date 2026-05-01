# RWA App - Architecture Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUTTER MOBILE APP                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │               LOGIN SCREEN (Role Toggle)                    │    │
│  │  ┌──────────────────────────────┐                           │    │
│  │  │ Email/Password Authentication │                          │    │
│  │  │ Firebase Auth                 │                          │    │
│  │  └──────────────────────────────┘                           │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                           │                                           │
│                ┌──────────┴──────────┐                               │
│                │                     │                               │
│         ┌──────▼──────┐      ┌───────▼────────┐                    │
│         │ ADMIN PANEL │      │ RESIDENT PANEL │                    │
│         ├──────────────┤      ├────────────────┤                    │
│         │ • Members    │      │ • Home         │                    │
│         │ • Payments   │      │ • Pay Dues     │                    │
│         │ • Dues       │      │ • Issues       │                    │
│         │ • Issues     │      │ • Notices      │                    │
│         │ • Expenses   │      │ • Expenses     │                    │
│         │ • Notices    │      │ • QR Pass      │                    │
│         │ • Reports    │      │ • Profile      │                    │
│         └──────┬───────┘      └───────┬────────┘                    │
│                │                      │                              │
│                └──────────┬───────────┘                              │
│                           │                                           │
└───────────────────────────┼───────────────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │   FIREBASE     │
                    │   BACKEND      │
                    └───────┬────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼─────┐    ┌───────▼──────┐   ┌───────▼──────┐
   │ FIRESTORE│    │   FIREBASE   │   │  CLOUD       │
   │ DATABASE │    │     AUTH     │   │  FUNCTIONS  │
   │          │    │              │   │              │
   │• users   │    │ • Email/Pwd  │   │• Monthly     │
   │• invoices│    │ • Login      │   │  invoices    │
   │• payments│    │ • Reset pwd  │   │• Verify      │
   │• notices │    │ • Tokens     │   │  payments    │
   │• issues  │    │              │   │• Notifications
   │• expenses│    └──────────────┘   │• Reports     │
   │• demands │                        │• Email       │
   └──────────┘                        └──────────────┘
        │                                    │
        │           ┌──────────┐            │
        └──────────►│          │◄───────────┘
                    │ SECURITY │
                    │  RULES   │
                    └──────────┘
```

## Data Flow: Payment Verification

```
┌──────────────────────────────────────────────────────────────┐
│ STEP 1: RESIDENT SUBMITS PAYMENT                             │
│                                                               │
│  Resident App                                                 │
│  └─► Select invoice/demand                                  │
│  └─► Enter amount & UTR                                     │
│  └─► Upload proof image                                     │
│  └─► POST to Firestore: payments collection                 │
│      ├─ uid: resident UID                                   │
│      ├─ amount: ₹ amount                                    │
│      ├─ status: "SUBMITTED"                                 │
│      └─ proof_url: Firebase Storage path                    │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 2: ADMIN REVIEWS PAYMENT                                │
│                                                               │
│  Admin App → Payments Tab                                    │
│  └─► View pending payments                                  │
│  └─► Click proof image (view screenshot)                    │
│  └─► Click "Verify" button                                  │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 3: CLOUD FUNCTION PROCESSES                             │
│                                                               │
│  verifyPaymentManualHttp(Cloud Function)                    │
│  └─► Verify Firebase Auth token                            │
│  └─► Update payments.status = "VERIFIED"                   │
│  └─► Find related invoice/demand                           │
│  └─► Update invoice.paid_amount += amount                  │
│  └─► Check if fully paid:                                   │
│      ├─ YES: invoice.status = "PAID"                       │
│      └─ NO: invoice.status = "PARTIAL"                     │
│  └─► Generate receipt PDF                                   │
│  └─► Save to receipts collection                            │
│  └─► Send FCM notification to resident                      │
│  └─► Email confirmation                                     │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ STEP 4: RESIDENT NOTIFIED                                    │
│                                                               │
│  Resident receives:                                          │
│  ├─ 🔔 Push notification: "Payment Verified!"              │
│  ├─ 📧 Email confirmation                                  │
│  ├─ 📄 PDF receipt (downloadable)                          │
│  └─► Updated balance on Pay screen                         │
└──────────────────────────────────────────────────────────────┘
```

## Database Schema

```
FIRESTORE DATABASE (rms-app-3d585)
│
├─► users/
│   ├─ {uid}
│   │  ├─ email: string
│   │  ├─ name: string
│   │  ├─ house_no: string
│   │  ├─ phone: string
│   │  ├─ role: "admin" | "user"
│   │  ├─ fcm_token: string
│   │  └─ created_at: timestamp
│   │
│   └─ Example Document:
│      └─ 1GxH7k2mF9... (UID)
│         ├─ name: "Raj Kumar"
│         ├─ house_no: "A-201"
│         ├─ email: "raj@example.com"
│         ├─ role: "user"
│         └─ fcm_token: "eEP4ZN..."
│
├─► invoices/
│   ├─ {invoiceId}
│   │  ├─ uid: string (resident)
│   │  ├─ month: string ("2026-05")
│   │  ├─ amount: number (1500)
│   │  ├─ paid_amount: number
│   │  ├─ status: "UNPAID" | "PARTIAL" | "PAID"
│   │  └─ created_at: timestamp
│   │
│   └─ Example: All residents get one per month
│
├─► payments/
│   ├─ {paymentId}
│   │  ├─ uid: string
│   │  ├─ amount: number
│   │  ├─ utr: string
│   │  ├─ status: "SUBMITTED" | "VERIFIED" | "REJECTED"
│   │  ├─ proof_url: string (Firebase Storage)
│   │  ├─ invoice_id: string
│   │  └─ created_at: timestamp
│   │
│   └─ Example: Multiple per resident over time
│
├─► demand_dues/
│   ├─ {dueId}
│   │  ├─ uid: string
│   │  ├─ title: string ("Painting Q2 2026")
│   │  ├─ description: string
│   │  ├─ amount: number
│   │  ├─ due_date: timestamp
│   │  ├─ status: "OPEN" | "CLOSED"
│   │  └─ created_at: timestamp
│   │
│   └─ Special one-off charges from admin
│
├─► notices/
│   ├─ {noticeId}
│   │  ├─ title: string
│   │  ├─ content: string
│   │  ├─ posted_by: string (admin uid)
│   │  └─ created_at: timestamp
│   │
│   └─ Broadcast to all residents
│
├─► issues/ (or complaints/)
│   ├─ {issueId}
│   │  ├─ uid: string (reporter)
│   │  ├─ title: string
│   │  ├─ description: string
│   │  ├─ status: "Open" | "In Progress" | "Resolved"
│   │  ├─ admin_feedback: string
│   │  └─ created_at: timestamp
│   │
│   └─ Resident-reported problems
│
├─► expenses/
│   ├─ {expenseId}
│   │  ├─ title: string
│   │  ├─ amount: number
│   │  ├─ category: string
│   │  └─ created_at: timestamp
│   │
│   └─ Admin-logged expenditures
│
└─► receipts/
    ├─ {receiptId}
    │  ├─ uid: string
    │  ├─ payment_id: string
    │  ├─ amount: number
    │  └─ generated_at: timestamp
    │
    └─ Generated after payment verification
```

## Cloud Functions Endpoints

```
Firebase Cloud Functions
Region: us-central1
Base URL: https://us-central1-rms-app-3d585.cloudfunctions.net

SCHEDULED FUNCTIONS
├─► generateMonthlyInvoices
│   ├─ Trigger: Cron "5 0 1 * *" (1st of month, 00:05 IST)
│   └─ Action: Create invoice for each resident
│
└─ (Runs automatically, no API call needed)

CALLABLE FUNCTIONS (from Flutter app)
├─► generateInvoicesManual
│   ├─ Auth: Admin only
│   ├─ Input: { month: "2026-05" }
│   └─ Output: { created: 342, month: "2026-05" }
│
├─► verifyPaymentManual
│   ├─ Auth: Admin only
│   ├─ Input: { paymentId, invoiceId }
│   └─ Output: { ok: true, receiptId, ... }
│
├─► rejectPaymentManual
│   ├─ Auth: Admin only
│   ├─ Input: { paymentId, reason }
│   └─ Output: { ok: true }
│
└─► exportMonthCsv
    ├─ Auth: Admin only
    ├─ Input: { month: "2026-05" }
    └─ Output: CSV data (name, house_no, amount, paid, status)

HTTP FUNCTIONS (with CORS, for webhooks/external)
├─► POST /createResidentHttp
│   ├─ Auth: Bearer {idToken}
│   ├─ Body: { name, email, phone, houseNo }
│   └─ Returns: { ok, tempPassword, emailSent }
│
├─► POST /deleteResidentHttp
│   ├─ Auth: Bearer {idToken}
│   ├─ Body: { userId }
│   └─ Returns: { ok, deleted: true }
│
├─► POST /verifyPaymentManualHttp
│   ├─ Auth: Bearer {idToken}
│   ├─ Body: { paymentId, invoiceId }
│   └─ Returns: { ok, receiptId }
│
├─► POST /rejectPaymentManualHttp
│   ├─ Auth: Bearer {idToken}
│   ├─ Body: { paymentId, reason }
│   └─ Returns: { ok }
│
├─► POST /createDemandDueHttp
│   ├─ Auth: Bearer {idToken}
│   ├─ Body: { title, description, amount, due_date, uids[] }
│   └─ Returns: { ok, created: 5 }
│
├─► POST /closeDemandDueHttp
│   ├─ Auth: Bearer {idToken}
│   ├─ Body: { dueId }
│   └─ Returns: { ok }
│
├─► POST /postNoticeHttp
│   ├─ Auth: Bearer {idToken}
│   ├─ Body: { title, content }
│   └─ Returns: { ok, noticeId }
│
├─► POST /updateComplaintStatusHttp
│   ├─ Auth: Bearer {idToken}
│   ├─ Body: { complaintId, status, adminFeedback }
│   └─ Returns: { ok }
│
├─► POST /createResidentHttp
│   ├─ Auth: Bearer {idToken}
│   ├─ Body: { name, email, phone, houseNo }
│   └─ Returns: { ok, tempPassword }
│
└─► POST /generateInvoicesManualHttp
    ├─ Auth: Bearer {idToken}
    ├─ Body: { month?: "2026-05" }
    └─ Returns: { created, skipped, month }
```

## Firebase Notifications Flow

```
NOTIFICATION SYSTEM (FCM + Local Notifications)

┌────────────────────────────────────────────────────┐
│ FCM TOKEN MANAGEMENT                               │
├────────────────────────────────────────────────────┤
│                                                    │
│ On App Start:                                      │
│ ├─ Get FCM token from Firebase Messaging           │
│ ├─ Save to Firestore: users/{uid}.fcm_token       │
│ ├─ Listen for token refresh                        │
│ └─ Update Firestore when token changes             │
│                                                    │
│ On Logout:                                         │
│ └─ Delete FCM token from Firestore                │
└────────────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────────┐
│ NOTIFICATION TRIGGERS                              │
├────────────────────────────────────────────────────┤
│                                                    │
│ 1. Monthly Invoices Generated                      │
│    └─ sendFcmMulticast(all residents)             │
│       Message: "Maintenance Due - April 2026"      │
│                                                    │
│ 2. Payment Verified                                │
│    └─ sendFcm(resident)                           │
│       Message: "Payment Verified! Receipt sent"   │
│                                                    │
│ 3. Payment Rejected                                │
│    └─ sendFcm(resident)                           │
│       Message: "Payment Rejected - Reason..."     │
│                                                    │
│ 4. Complaint Resolved                              │
│    └─ sendFcm(resident)                           │
│       Message: "Your issue resolved"              │
│                                                    │
│ 5. Notice Published                                │
│    └─ sendFcmMulticast(all residents)             │
│       Message: "New Notice: ..."                   │
└────────────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────────┐
│ NOTIFICATION DELIVERY                              │
├────────────────────────────────────────────────────┤
│                                                    │
│ App in Foreground:                                 │
│ └─ Local notification (heads-up)                  │
│    Handles via: _showLocalNotification()          │
│                                                    │
│ App in Background:                                │
│ └─ System notification (tray)                     │
│    Handles via: _fcmBackgroundHandler()           │
│                                                    │
│ App Closed:                                        │
│ └─ System shows notification                      │
│    Tap → Opens app → Shows message content        │
└────────────────────────────────────────────────────┘
```

## Security Architecture

```
AUTHENTICATION & AUTHORIZATION

┌──────────────────────────────────┐
│ CLIENT (Flutter App)              │
├──────────────────────────────────┤
│                                  │
│ 1. Email/Password Login          │
│    └─ FirebaseAuth.signIn()      │
│                                  │
│ 2. Get ID Token                  │
│    └─ user.getIdToken()          │
│                                  │
│ 3. Send with API calls           │
│    └─ Header: "Authorization: Bearer {token}"
│                                  │
└──────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────┐
│ CLOUD FUNCTIONS                  │
├──────────────────────────────────┤
│                                  │
│ 1. Verify ID Token              │
│    └─ admin.auth().verifyIdToken()
│                                  │
│ 2. Extract UID & Email          │
│    └─ decoded.uid, decoded.email│
│                                  │
│ 3. Check Role                    │
│    └─ Get from Firestore        │
│    └─ Verify is "admin"         │
│                                  │
│ 4. Enforce Authorization        │
│    └─ If not admin: throw error │
│                                  │
│ 5. Process Request              │
│    └─ Execute business logic    │
│                                  │
└──────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────┐
│ FIRESTORE SECURITY RULES         │
├──────────────────────────────────┤
│                                  │
│ Match /users/{userId}            │
│  ├─ allow read: if own or admin │
│  ├─ allow update: if own or admin
│  └─ allow delete: if admin       │
│                                  │
│ Match /invoices/{docId}          │
│  ├─ allow read: own or admin     │
│  └─ allow write: false (CF only) │
│                                  │
│ Match /payments/{docId}          │
│  ├─ allow create: by own UID     │
│  ├─ allow read: own or admin     │
│  └─ allow update: false (CF only)│
│                                  │
│ ... (all other collections)      │
│                                  │
└──────────────────────────────────┘
```

## UI Component Hierarchy

```
MyApp (Material App with Poppins Font)
│
├─► LoginScreen (Entry Point)
│   ├─ Gradient header
│   ├─ Role toggle (Resident/Admin)
│   ├─ Email input
│   ├─ Password input
│   ├─ Forgot password button
│   └─ Login button
│
├─► AdminDashboard (if admin role)
│   └─ NavigationBar (7 tabs)
│       ├─ MembersScreen
│       ├─ AdminPayScreen
│       ├─ AdminDuesScreen
│       ├─ AdminIssuesScreen
│       ├─ AdminExpenseScreen
│       ├─ AdminNoticesScreen
│       └─ AdminProfileScreen
│
└─► Dashboard (if user role)
    └─ NavigationBar (6 tabs)
        ├─ UserHomeScreen
        │   ├─ SliverAppBar (gradient header)
        │   ├─ Due amount card
        │   ├─ Quick action buttons
        │   └─ Recent notices section
        ├─ UserPayScreen
        │   ├─ Invoice banner
        │   ├─ Amount input
        │   ├─ UTR input
        │   ├─ Proof image picker
        │   └─ Submit button
        ├─ IssuesScreen
        ├─ NoticesScreen
        ├─ ExpenseScreen
        └─ ProfileScreen
```

## Development Setup

```
PROJECT STRUCTURE:

rwa_utility_app-main/
├── lib/
│   ├── main.dart
│   ├── config/
│   ├── firebase_options.dart
│   ├── theme/
│   ├── services/
│   └── screens/
│       ├── login/
│       ├── admin/
│       └── user/
│
├── android/
│   └── app/
│       ├── google-services.json (Firebase config)
│       └── src/
│
├── ios/
│   ├── GoogleService-Info.plist (Firebase config)
│   └── Runner/
│
├── functions/ (Cloud Functions)
│   ├── index.js
│   ├── package.json
│   └── .env
│
├── firestore.rules (Security rules)
├── firebase.json (Firebase config)
├── pubspec.yaml (Dependencies)
└── pubspec.lock (Locked versions)
```

---

*This diagram provides a complete visual understanding of the RWA Manager app architecture.*
