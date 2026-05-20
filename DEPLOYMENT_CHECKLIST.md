# Account Sharing - Deployment Checklist

## 🎯 Pre-Deployment Verification

### Files Already Updated ✅
- [x] `lib/screens/user/dashboard.dart` - Updated with dynamic User loading
- [x] `lib/screens/user/user_home_screen.dart` - Updated invoice/payment queries

### Files Already Available ✅
- [x] `lib/models/user.dart` - Enhanced User model with AccountLink
- [x] `lib/services/account_link_service.dart` - Account linking business logic
- [x] `lib/screens/user/manage_members_screen.dart` - Members management UI
- [x] `firestore_updated.rules` - Security rules with flat_no filtering
- [x] `functions/account_sharing.js` - Cloud Functions for member operations
- [x] `functions/migrations/migrate_to_account_sharing.js` - Migration script

---

## 📋 Step-by-Step Deployment

### STEP 1: Backup Your Current Setup (5 min)
```bash
# Backup Firestore rules
firebase rules:backup

# Backup Cloud Functions (backup to a separate folder)
cp -r functions functions.backup
```

**Checklist:**
- [ ] Firestore rules backed up
- [ ] Cloud Functions backed up

---

### STEP 2: Copy New Model & Service Files (10 min)
```bash
# Copy the enhanced User model
cp lib/models/user.dart lib/models/user.dart.backup
# Update with new version from the implementation folder

# Copy the account linking service
mkdir -p lib/services
cp lib/services/account_link_service.dart lib/services/
```

**Verify:**
```bash
# Check for import errors
flutter pub get
flutter analyze
```

**Checklist:**
- [ ] User.dart copied
- [ ] account_link_service.dart copied
- [ ] No import errors

---

### STEP 3: Copy UI Screens (10 min)
```bash
# Copy the manage members screen
cp lib/screens/user/manage_members_screen.dart lib/screens/user/

# Dashboard was already updated
# Verify it imports ManageMembersScreen
grep "import.*manage_members_screen" lib/screens/user/dashboard.dart
```

**Verify:**
```bash
flutter pub get
flutter analyze
```

**Checklist:**
- [ ] manage_members_screen.dart copied
- [ ] dashboard.dart has correct imports
- [ ] No compilation errors

---

### STEP 4: Deploy Firestore Security Rules (5-10 min)
```bash
# Copy the updated rules
cp firestore_updated.rules firestore.rules
# (Or use the exact file from the implementation)

# Deploy to Firebase
firebase deploy --only firestore:rules
```

**Verify in Firebase Console:**
- Go to Firestore → Rules tab
- Rules should show `isSameFlatMember()` helper function
- Should have rules for flat-based access control

**Checklist:**
- [ ] Rules copied to project
- [ ] Rules deployed successfully
- [ ] Firebase Console shows new rules

---

### STEP 5: Deploy Cloud Functions (10 min)
```bash
# Copy the account sharing functions
cp functions/account_sharing.js functions/

# Deploy functions
firebase deploy --only functions
```

**Verify in Firebase Console:**
- Go to Cloud Functions
- Should see:
  - `onAddFlatMemberRequest`
  - `onRemoveFlatMemberRequest`
  - `runMigration`

**Checklist:**
- [ ] account_sharing.js copied
- [ ] Functions deployed successfully
- [ ] All 3 functions appear in Console
- [ ] No deployment errors in logs

---

### STEP 6: Run Database Migration (10 min)
**Option A: Via Firebase Console (Easiest)**
1. Go to Firebase Console → Cloud Functions
2. Find `runMigration` function
3. Click "Testing" tab
4. Trigger the function with token parameter
5. Check logs for "Migrated X users"

**Option B: Via Firebase CLI**
```bash
# Set migration token
export MIGRATION_TOKEN=your-secret-token

# Trigger the function
curl "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/runMigration?token=your-secret-token"

# Check logs
firebase functions:log
```

**What the migration does:**
- Adds `account_link` field to all users
- Adds `flat_members` array to all users
- Marks all existing users as account owners

**Checklist:**
- [ ] Migration function triggered
- [ ] Migration completed (check logs)
- [ ] Verify X users migrated

---

### STEP 7: Test in Development Environment (30-45 min)

#### Test 1: Add a Member
1. Open app as account owner
2. Go to "Members" tab
3. Click "Add User to This Account"
4. Fill in:
   - Name: John Test
   - Email: john@test.com
   - Relationship: Tenant
5. Click "Add User"

**Expected results:**
- ✅ Request created in Firestore `_requests` collection
- ✅ Cloud Function processes it within 10 seconds
- ✅ New user created in Firebase Auth
- ✅ User document created in Firestore
- ✅ Both users' `flat_members` arrays updated
- ✅ Confirmation message shown in app

**Checklist:**
- [ ] Add member dialog opens
- [ ] Form validation works
- [ ] Request submitted successfully
- [ ] No errors in Firebase logs
- [ ] New user appears in member list

---

#### Test 2: Verify Shared Invoice Access
1. Admin (or you) create an invoice in Firestore:
   ```
   Collection: invoices
   Fields:
   - uid: original_owner_uid
   - flat_no: "101"
   - amount: 5000
   - status: "UNPAID"
   ```

2. Log in as original owner
3. Check Home → Your Dues
4. Should see the invoice

5. Log in as newly added member
6. Check Home → Your Dues
7. Should see the SAME invoice

**Expected results:**
- ✅ Both see identical invoice
- ✅ Same invoice ID
- ✅ Same amount

**Checklist:**
- [ ] Original owner sees invoice
- [ ] New member sees invoice
- [ ] Both see same invoice (not duplicates)

---

#### Test 3: Test Payment Attribution
1. Log in as new member
2. Go to Pay tab
3. Click on invoice
4. Submit payment for ₹2000

5. Check in Firestore `payments` collection:
   - Should have `uid` set to new member's UID
   - Should have `flat_no` set to flat number
   - Should show who paid

6. Log in as owner
7. Check Home → Recent Payments
8. Should show payment by new member

**Expected results:**
- ✅ Payment created with correct uid
- ✅ Shows who made the payment
- ✅ Both members see payment in recent list

**Checklist:**
- [ ] Payment submitted successfully
- [ ] Payment attributed to correct user
- [ ] Shows in recent payments for both users
- [ ] Owner can see who paid

---

#### Test 4: Remove a Member
1. Log in as owner
2. Go to Members tab
3. Find the newly added member
4. Click remove button
5. Confirm removal

**Expected results:**
- ✅ Member removed from list
- ✅ Member's status set to 'removed' in Firestore
- ✅ Removed from all flat_members arrays
- ✅ Removed user can't see flat data anymore

6. Try to log in as removed member
7. Should still be able to log in (auth not deleted)
8. But should not see flat invoices

**Checklist:**
- [ ] Remove button works
- [ ] Confirmation dialog shows
- [ ] Member removed from list
- [ ] Removed member can't see invoices
- [ ] Other members see updated list

---

### STEP 8: Final Verification (10 min)

Run this checklist one more time:

**User Experience**
- [ ] App loads without crashes
- [ ] No errors in console
- [ ] Smooth navigation between screens
- [ ] Add/remove member flows work

**Data Integrity**
- [ ] One invoice per flat (not per person)
- [ ] All members see same invoices
- [ ] Payments tracked by user
- [ ] Members list is correct

**Security**
- [ ] Non-owners can't see Members tab
- [ ] Removed users can't see data
- [ ] Other flats are not visible
- [ ] Only owners can manage members

**Performance**
- [ ] App doesn't feel slower
- [ ] Invoices load quickly
- [ ] No lag when adding members
- [ ] Firestore operations are fast

---

### STEP 9: Prepare for Production Deployment (10 min)

**Before going live:**
- [ ] All tests passed
- [ ] No errors in Firebase logs
- [ ] Cloud Function logs are clean
- [ ] Migration completed successfully
- [ ] Database backup created

**Prepare users:**
- [ ] Create user guide for new feature
- [ ] Document how to add family members
- [ ] Document who can manage members
- [ ] Prepare FAQ

**Deploy to production:**
- [ ] Update app to latest code
- [ ] Ensure all imports are correct
- [ ] Run `flutter pub get` one more time
- [ ] Build and deploy to users

---

## 🎯 Validation Checklist

After deployment, verify all of these work:

### Home Screen
- [ ] All flat members see same invoices
- [ ] Invoices show in "Your Dues" section
- [ ] Recent payments show all flat member payments
- [ ] No duplicate invoices

### Members Screen (Owners Only)
- [ ] Can see all members
- [ ] Member count badge shows correct number
- [ ] Can click "Add User to This Account"
- [ ] Can remove members
- [ ] Can't remove self
- [ ] Can't remove owner

### Pay Screen
- [ ] Can select and pay invoices
- [ ] Payment submission works
- [ ] Shows in recent payments for all members
- [ ] Shows who made the payment

### User Permissions
- [ ] Members can't manage members
- [ ] Members can pay bills
- [ ] Members can report issues
- [ ] Members can view notices
- [ ] Removed members lose access

---

## 📊 Expected Outcomes

After successful deployment:

| Feature | Before | After |
|---------|--------|-------|
| Invoice visibility | Per user | Per flat |
| Payment tracking | By user | By user (shown to all) |
| Member management | N/A | Owner only |
| Permissions | Two roles | Same per flat |
| Dues collection | Individual invoices | Shared invoice |

---

## ✅ Success Criteria

You'll know it's working when:

1. ✅ App launches without errors
2. ✅ Owners see "Members" tab
3. ✅ Can add members
4. ✅ Invoices shared across flat
5. ✅ Payments show attribution
6. ✅ Can remove members
7. ✅ Removed users lose access
8. ✅ No Firebase permission errors
9. ✅ Cloud Functions execute successfully
10. ✅ All members see current data

---

## 📞 If Something Goes Wrong

### Problem: "Permission Denied" Errors
**Solution:**
1. Check Firestore rules are deployed
2. Verify `isSameFlatMember()` function exists
3. Check user has correct role
4. Clear app cache and restart

### Problem: New Members Don't See Invoices
**Solution:**
1. Verify flat_no is set in invoice
2. Check user's flat_members array includes them
3. Clear app cache
4. Restart app

### Problem: Cloud Functions Not Triggering
**Solution:**
1. Check function is deployed
2. Check logs for errors
3. Verify `_requests` collection exists
4. Check function permissions

### Problem: Migration Didn't Run
**Solution:**
1. Check migration function was deployed
2. Verify token is correct
3. Check Cloud Functions logs
4. Run migration again

---

## 🎉 You're Ready!

Follow each step in order, verify at each stage, and you'll have account sharing live in about 2-3 hours.

**Next:** Run STEP 1 (Backup) and let me know when you're done with each step!
