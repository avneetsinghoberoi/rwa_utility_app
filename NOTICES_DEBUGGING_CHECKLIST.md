# Notices Not Showing - Debugging Checklist

## Step 1: Verify Admin Role in Firestore ✅

```
1. Firebase Console → Firestore
2. Collections → users
3. Find your admin user document (by email)
4. Check the 'role' field:
   - Should show: admin (lowercase, no quotes)
   - If missing: ADD it
   - If wrong: EDIT it
5. Click Save
```

**Screenshot proof needed:** Show me the admin user document with role: admin visible

---

## Step 2: Clear Cache & Restart App

```bash
# Close the app completely
# Then run:
flutter clean
flutter pub get
flutter run
```

**DO NOT skip this step!**

---

## Step 3: Log Out & Log In Again

```
1. Log out completely (click logout button)
2. Close the app entirely
3. Reopen the app
4. Log in as admin again
5. Check if you see "New Announcement" button
```

---

## Step 4: Verify You're on Admin Dashboard

Look at the bottom navigation bar. You should see exactly **7 items**:

```
1. Members
2. Pay
3. Dues
4. Issues
5. Expense
6. Notices ← Click this
7. Profile
```

If you see FEWER items (like 5 or 6), you're on the User Dashboard, not Admin Dashboard.

---

## Step 5: Check the Notices Collection Exists

```
1. Firebase Console → Firestore
2. Look for 'notices' collection
3. If it doesn't exist: CREATE it
   - Click "Start Collection"
   - Collection ID: notices
   - Click "Add document"
   - Auto ID
   - Leave blank for now
   - Save
```

---

## Step 6: Run the App in Debug Mode

Add logging to see what's happening:

```bash
flutter run -v
```

Then try to click on Notices and watch the console for errors.

Look for:
```
🔵 [Notice] User loaded
🔴 [Notice] Error loading user
E/flutter: Error...
```

---

## If Still Not Working - Check These:

### Check 1: Is Firestore Updated?
```
Firebase Console → Firestore → users → Find admin user
Does it show role: admin? (yes/no)
```

### Check 2: Did You Restart the App?
```
Did you:
- Close app completely? (yes/no)
- Wait 5 seconds? (yes/no)
- Reopen app? (yes/no)
- Log in again? (yes/no)
```

### Check 3: Are You Really on Admin Dashboard?
```
Bottom navigation bar has 7 items? (yes/no)
Items are: Members, Pay, Dues, Issues, Expense, Notices, Profile? (yes/no)
```

### Check 4: Does Notices Collection Exist?
```
Firebase Console → Firestore → notices collection visible? (yes/no)
```

---

## Complete Fix Procedure (Step by Step):

### STEP 1: Update Firestore (2 minutes)
```
1. Firebase Console: firestore.google.com
2. Click your project: rms-app-3d585
3. Firestore → collections → users
4. Find your email address (admin user)
5. Click on that document
6. Look for 'role' field
7. If missing: Click "Add field"
   - Field: role
   - Type: string
   - Value: admin
8. If exists: Click it, change to "admin"
9. Click Save
10. Wait 2 seconds
```

### STEP 2: Clean & Rebuild (5 minutes)
```bash
cd ~/Downloads/rwa_utility_app-main
flutter clean
flutter pub get
flutter run
```

### STEP 3: Fresh Login (2 minutes)
```
1. Wait for app to load
2. Log out (if already logged in)
3. Close app completely (swipe away)
4. Wait 3 seconds
5. Reopen app
6. Log in with admin email
7. Check if you see Admin Dashboard (7 items)
8. Click Notices
9. Look for "New Announcement" button
```

---

## What Should Happen

After these steps, when you click Notices you should see:

```
┌─────────────────────────────┐
│    Community Notices     │ [ ]│
├─────────────────────────────┤
│                             │
│  Announcements    [+ New]   │
│                             │
│  (List of notices or        │
│   "No notices posted yet")  │
│                             │
└─────────────────────────────┘
```

The **"+ New Announcement"** button should be visible at the top right!

---

## Still Not Working?

Tell me:

1. **Firestore role field shows:** ________________
2. **Did you restart the app:** yes / no
3. **Did you clear cache:** yes / no
4. **Bottom nav has how many items:** ___
5. **Can you see "Announcements" text:** yes / no
6. **Any error messages in console:** yes / no (what?)

---

## Copy-Paste Verification Checklist

Please verify and tell me YES to all of these:

- [ ] Admin user in Firestore has role: admin
- [ ] App was completely restarted (flutter clean, flutter run)
- [ ] User was logged out and logged in again
- [ ] Bottom navigation shows 7 items
- [ ] You're on the Notices tab (6th item)
- [ ] Notices collection exists in Firestore
