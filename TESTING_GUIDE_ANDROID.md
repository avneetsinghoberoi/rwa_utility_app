# Testing Members Directory on Android Studio - Complete Guide

## 🎯 Prerequisites

Before you start, make sure you have:

### Required Software
- ✅ Android Studio (Latest version recommended)
- ✅ Flutter SDK (v3.6.1+)
- ✅ Java Development Kit (JDK 11+)
- ✅ Android SDK (API level 21+)
- ✅ Git (for version control)

### Required Accounts
- ✅ Firebase account with access to `rms-app-3d585` project
- ✅ At least 2 test user accounts in Firebase

---

## 🚀 Step 1: Open Project in Android Studio

### 1.1 Open Android Studio
```bash
# If you have Android Studio in your system
# Open it directly from Applications menu
# OR run from terminal:
open -a "Android Studio"  # macOS
# or for Windows/Linux use your file explorer
```

### 1.2 Open the Project
1. Click **File** → **Open**
2. Navigate to: `/Users/avneet/Downloads/rwa_utility_app-main`
3. Click **Open**
4. Android Studio will load the Flutter project

### 1.3 Wait for Project Sync
- Android Studio will automatically sync Gradle files
- Wait for completion (you'll see "Gradle sync finished" message)
- This may take 2-5 minutes on first sync

---

## ✅ Step 2: Verify Flutter & Dependencies

### 2.1 Open Terminal in Android Studio
```
View → Tool Windows → Terminal
OR Press: Ctrl+Alt+A (Windows/Linux) / ⌘+⌥+A (Mac)
```

### 2.2 Check Flutter Installation
```bash
flutter doctor
```

**Expected Output:**
```
[✓] Flutter (Channel stable, 3.6.1, on macOS 14.5)
[✓] Android toolchain
[✓] Xcode (if on Mac)
[✓] Android Studio
[✓] VS Code
[✓] Connected device
```

**If you see any ❌ marks:**
- Follow the instructions to fix them
- Common issue: Android SDK not found → Install via Android Studio

### 2.3 Get Flutter Dependencies
```bash
flutter pub get
```

This installs all packages from `pubspec.yaml`

---

## 🤖 Step 3: Set Up Android Emulator

### 3.1 Open AVD Manager
```
Tools → Device Manager
OR Click the phone icon in toolbar
```

### 3.2 Create New Virtual Device (if needed)
1. Click **Create Device**
2. Select **Phone** category
3. Choose a device (e.g., **Pixel 6**)
4. Click **Next**
5. Select API Level **33 or higher**
6. Click **Next** → **Finish**

### 3.3 Start the Emulator
```
In Device Manager: Click the Play (▶) button next to your device
OR from Terminal:
emulator -avd <device_name>
```

**Wait for emulator to fully boot** (you'll see Android home screen)

---

## 📱 Step 4: Run the App

### 4.1 Option A: Run from Android Studio (Easiest)
1. Make sure emulator is running
2. Click the **▶ Run** button (green play icon in toolbar)
3. Select your emulator from the dialog
4. Click **OK**

### 4.2 Option B: Run from Terminal
```bash
cd /Users/avneet/Downloads/rwa_utility_app-main
flutter run
```

### 4.3 Wait for Build
The app will:
- Compile Dart code
- Build APK
- Install on emulator
- Launch the app

This takes **2-5 minutes** on first run.

**You should see:**
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk (XX MB)
✓ Installing and launching...
✓ Xms (hot reload ready!)
```

---

## 🔐 Step 5: Login & Prepare for Testing

### 5.1 Login as a Resident
1. App loads and shows **Login Screen**
2. Make sure **"Resident"** toggle is selected (NOT "Admin")
3. Enter resident test credentials:
   - **Email:** `resident1@example.com` (or your test account)
   - **Password:** Your Firebase password
4. Tap **Login button**

### 5.2 Navigate to Home Screen
1. You should see **User Dashboard** with 7 tabs
2. The first tab (Home) is selected by default

---

## 📂 Step 6: Test the Directory Feature

### 6.1 Locate Directory Tab
```
Navigation Bar at Bottom:
[🏠] [💳] [🐛] [📢] [👥] [📋] [👤]
               ↑
        This is Directory Tab (5th)
```

### 6.2 Tap Directory Tab
1. Look at the bottom navigation bar
2. Tap the **👥 Directory** icon (or label)
3. The screen should load showing **Members Directory**

### 6.3 Verify Members Load
```
Expected Screen:
┌─────────────────────────────────────┐
│ Members Directory      [Sort 🔽]   │
├─────────────────────────────────────┤
│ ┌──────────────────────────────┐   │
│ │ 🔍 Search by name...  [✕]  │   │
│ └──────────────────────────────┘   │
│                                     │
│  ┌────────────────────────────┐   │
│  │ 👤 John Kumar              │   │
│  │ 🏠 House No. A-201         │   │
│  │ ✅ Resident                │   │
│  │ ─────────────────────────  │   │
│  │ ☎️ +91 9876543210          │   │
│  │ 📧 john@example.com        │   │
│  └────────────────────────────┘   │
│                                     │
│  ┌────────────────────────────┐   │
│  │ 👩 Sarah Patel             │   │
│  │ ... [more members]         │   │
│  └────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

If you see this → **✅ Directory is working!**

---

## 🔍 Step 7: Test Features

### 7.1 Test Search Functionality

**Test 1: Search by Name**
1. Tap search bar at top
2. Type: `john`
3. Should see: Members with "john" in name
4. Other members should disappear
5. Tap **✕** to clear

**Test 2: Search by House Number**
1. Type: `A-2` (or any house prefix)
2. Should see: Only members in that house range
3. Example: A-201, A-202 appear

**Test 3: Search by Phone**
1. Type: `98765` (or any phone digits)
2. Should see: Only members with those digits
3. Non-matching members hidden

**Expected Behavior:**
```
✓ Real-time filtering (updates as you type)
✓ Case-insensitive matching
✓ Clear button appears when text entered
✓ No results message if nothing matches
```

### 7.2 Test Sort Functionality

**Test 1: Sort by House Number (Default)**
1. Tap the sort icon (🔽) in top right
2. Select **"Sort by House No"**
3. List should reorder:
   ```
   A-101, A-102, A-201, B-101, B-102, ...
   ```

**Test 2: Sort by Name**
1. Tap sort icon again
2. Select **"Sort by Name"**
3. List should reorder alphabetically:
   ```
   Ajay, Bhavna, David, Priya, Ravi, ...
   ```

**Expected Behavior:**
```
✓ Sort toggle works instantly
✓ Name sorting is alphabetical
✓ House number sorting is alphanumeric
✓ Icon changes when sort changes
```

### 7.3 Test Member Cards

**Test 1: Verify Card Display**
1. Tap on any member card
2. Should see all details:
   - Avatar with first letter
   - Name in bold
   - House number with 🏠 icon
   - Green "Resident" badge
   - Phone and email below divider

**Test 2: Copy Phone Number**
1. Tap on phone number in any member card
2. Should see snackbar: ✅ "Copied: +91 XXXXXXXXXX"
3. Phone number copied to clipboard

**Test 3: Copy Email**
1. Tap on email in any member card
2. Should see snackbar: ✅ "Copied: email@example.com"
3. Email copied to clipboard

**Expected Behavior:**
```
✓ Phone number shows correctly formatted
✓ Email displays properly
✓ Copy confirmation appears
✓ No errors in console
```

### 7.4 Test Avatar Colors
1. Scroll through multiple members
2. Notice each person has a different color avatar
3. Same person always gets same color
4. Colors are: Blue, Purple, Green, Orange, Red, Cyan

**Expected Behavior:**
```
✓ Different members get different colors
✓ Same member always same color
✓ Avatar colors attractive and varied
```

---

## 🐛 Step 8: Check Console for Errors

### 8.1 Open Flutter Console
```
View → Tool Windows → Logcat
OR Press: Ctrl+6 (Windows/Linux) / ⌘+6 (Mac)
```

### 8.2 Monitor Logs
Look for any errors while testing directory:

**Good Logs (Expected):**
```
I/flutter: [Directory] Loaded members successfully
I/Firestore: Reading from collection: users
I/flutter: Member count: 15
```

**Bad Logs (Problems):**
```
E/flutter: Error loading members: Permission denied
E/Firestore: Failed to read users collection
E/flutter: Exception: ...
```

### 8.3 Fix Permission Errors
If you see **"Permission denied"**:
1. Check Firestore rules were deployed
2. Deploy again: `firebase deploy --only firestore:rules`
3. Restart app: Press **R** in terminal (or restart emulator)

---

## ✅ Step 9: Test Different Scenarios

### Scenario 1: Empty Directory
**If no members show:**
1. Check if your Firestore has resident accounts
2. Make sure they have `role: "user"` (not "admin")
3. View Firestore in Firebase Console to verify data

### Scenario 2: Large Member List
**If you have 50+ members:**
1. Test scrolling performance
2. Search should still be fast
3. No lag when scrolling

### Scenario 3: Real-time Updates
1. Keep directory open in emulator
2. Use Firebase Console to add new resident
3. New member should appear automatically (after 1-2 seconds)

### Scenario 4: New User Creation
1. Use admin account to create new resident
2. New resident account appears in directory
3. Old resident sees new member immediately

---

## 📊 Step 10: Test on Multiple Accounts

### 10.1 Test as Different Residents
```bash
# Logout current account
# Navigate to Settings/Profile → Logout

# Or manually:
# Restart app by pressing R in terminal
```

1. Login as **resident1@example.com**
2. Check directory
3. Logout
4. Login as **resident2@example.com**
5. Check directory (should be same members)
6. Verify both see all residents

### 10.2 Test as Admin
1. Toggle login to **"Admin"** (not Resident)
2. Login with admin account
3. Go to Admin Dashboard (should have 7 different tabs)
4. Check if members visible in admin view (should work)

---

## 🔧 Step 11: Troubleshooting

### Issue: App Won't Run
```bash
# Solution 1: Clean build
flutter clean
flutter pub get
flutter run

# Solution 2: Kill emulator and restart
adb kill-server
adb start-server
```

### Issue: Directory Tab Not Showing
```
Cause: Modified files not saved properly
Solution:
1. Close Android Studio
2. Reopen project
3. Check dashboard.dart has directory_screen import
4. Run: flutter clean && flutter pub get && flutter run
```

### Issue: Members Not Loading
```
Cause: Firestore rules not deployed
Solution:
1. Deploy rules: firebase deploy --only firestore:rules
2. Wait 1 minute
3. Restart app: Press R in terminal
4. Check Firestore rules in Firebase Console
```

### Issue: Search Not Working
```
Cause: Widget state issue
Solution:
1. Hot restart: Press Shift+R in terminal
2. If still broken, full rebuild: flutter clean && flutter run
3. Check console for errors
```

### Issue: Copy to Clipboard Not Working
```
Cause: Clipboard permission
Solution:
1. On Android 6+, clipboard access usually works
2. Try on real device instead of emulator
3. Check Android manifest has proper permissions
```

---

## 📱 Step 12: Test on Real Device (Optional)

### 12.1 Connect Physical Android Phone
1. Enable **Developer Mode**:
   - Settings → About Phone
   - Tap "Build Number" 7 times
   - You'll see "Developer Mode Enabled"

2. Enable **USB Debugging**:
   - Settings → Developer Options → USB Debugging
   - Toggle it ON
   - Accept the debugging prompt

3. Connect via USB cable

### 12.2 Run on Physical Device
```bash
# List connected devices
adb devices

# Run on device
flutter run
```

### 12.3 Benefits of Real Device Testing
- ✅ Actual touch interactions
- ✅ Real network conditions
- ✅ Actual app performance
- ✅ Better UI testing

---

## 📝 Testing Checklist

Print this or keep it open while testing:

```
DIRECTORY FEATURE TESTING CHECKLIST
═══════════════════════════════════════

Navigation
  ☐ Directory tab visible in navigation bar
  ☐ Tapping directory tab loads the screen
  ☐ Screen title shows "Members Directory"
  ☐ Switching to other tabs and back works

Member Display
  ☐ All members load and display
  ☐ Member cards show correct layout
  ☐ Avatar circles show first letter
  ☐ Avatar colors are varied
  ☐ Names display correctly
  ☐ House numbers display with icon
  ☐ "Resident" badge appears
  ☐ Phone numbers display
  ☐ Email addresses display

Search Functionality
  ☐ Search bar visible and interactive
  ☐ Search by name works
  ☐ Search by house number works
  ☐ Search by phone works
  ☐ Search is real-time
  ☐ Clear (✕) button appears when typing
  ☐ Clear button clears search
  ☐ "No results" message shows for no matches
  ☐ Case-insensitive search works

Sort Functionality
  ☐ Sort button visible in top right
  ☐ Clicking sort shows popup menu
  ☐ "Sort by House No" option works
  ☐ "Sort by Name" option works
  ☐ Sorting changes list order
  ☐ House number sort is alphanumeric
  ☐ Name sort is alphabetical

Copy Actions
  ☐ Tapping phone number shows snackbar
  ☐ Snackbar confirms "Copied"
  ☐ Phone copied to clipboard
  ☐ Tapping email shows snackbar
  ☐ Email copied to clipboard

Error Handling
  ☐ Loading spinner shows while loading
  ☐ Error message if Firestore fails
  ☐ Empty state if no members exist
  ☐ No results state for failed search

Performance
  ☐ Directory loads quickly (< 2 seconds)
  ☐ Scrolling is smooth
  ☐ Search filtering is instant
  ☐ Sorting is instant
  ☐ No lag with 50+ members

Console
  ☐ No errors in Logcat
  ☐ No warnings in console
  ☐ Firestore reads succeeding
  ☐ Real-time updates working

User Experience
  ☐ UI looks professional
  ☐ Colors match app theme
  ☐ Animations are smooth
  ☐ Buttons are responsive
  ☐ Text is readable

Multiple Accounts
  ☐ Different residents see same members
  ☐ Real-time updates work
  ☐ Admin account works too
  ☐ Logout/login works smoothly
```

---

## 🎥 Step 13: Recording a Test Session

### Record Your Testing (Optional)
```bash
# Using Android Studio built-in recorder:
1. Click on Logcat (bottom)
2. Click Settings icon (⚙️)
3. Select "Screen Recorder"
4. Click "Start Recording"
5. Perform your tests
6. Click "Stop Recording"
7. Video saves to ~/Downloads
```

---

## 📊 Sample Test Results Table

Create this table and fill as you test:

| Feature | Expected | Actual | Status | Notes |
|---------|----------|--------|--------|-------|
| Members Load | All members visible | ___ | ✓/✗ | ___ |
| Search Name | Filters correctly | ___ | ✓/✗ | ___ |
| Search House | Filters correctly | ___ | ✓/✗ | ___ |
| Search Phone | Filters correctly | ___ | ✓/✗ | ___ |
| Sort House | Orders by house | ___ | ✓/✗ | ___ |
| Sort Name | Orders alphabetically | ___ | ✓/✗ | ___ |
| Copy Phone | Copies to clipboard | ___ | ✓/✗ | ___ |
| Copy Email | Copies to clipboard | ___ | ✓/✗ | ___ |
| Performance | < 2 seconds | ___ | ✓/✗ | ___ |
| No Errors | No console errors | ___ | ✓/✗ | ___ |

---

## 🚀 Final Verification

### Before Deploying to Production

Run through this final checklist:

```
✓ Directory feature works on emulator
✓ Directory feature works on real device
✓ No console errors
✓ Firestore rules deployed correctly
✓ Search works on all fields
✓ Sort works both ways
✓ Copy functions work
✓ Real-time updates work
✓ Error states handled gracefully
✓ Performance is acceptable
✓ All members display correctly
✓ UI matches app design
✓ No sensitive data exposed
✓ Security rules are correct
```

If all ✓, you're ready to deploy!

---

## 💡 Tips for Better Testing

1. **Test Early & Often**
   - Don't wait until end to test
   - Test after small changes

2. **Test Real Data**
   - Use actual member data from Firestore
   - Don't just use mock data

3. **Test Edge Cases**
   - Empty list
   - Single member
   - 100+ members
   - Special characters in names

4. **Test on Device**
   - Emulator is good but real device is better
   - Performance different on real hardware

5. **Clear App Cache**
   - Sometimes old data cached
   - Settings → Apps → RWA Manager → Clear Cache

6. **Keep Console Open**
   - Watch for errors in Logcat
   - Real-time insights into issues

7. **Take Screenshots**
   - Document successful tests
   - Useful for bug reports

---

## 📞 Common Questions

**Q: How do I add test members to Firestore?**
A: Use Firebase Console:
1. Go to Firebase Console
2. Select rms-app-3d585 project
3. Go to Firestore Database
4. Collection "users" → Add Document
5. Add fields: email, name, house_no, phone, role: "user"

**Q: How do I test multiple accounts?**
A: Create multiple test users in Firebase Auth:
1. Firebase Console → Authentication
2. Users tab → Add User
3. Enter email and password
4. Create corresponding document in users collection

**Q: Can I test offline?**
A: No, directory requires Firestore connection.
You need internet for testing.

**Q: How do I speed up testing?**
A: Use hot reload:
- Press R in terminal for hot reload
- Press Shift+R for hot restart
- Much faster than full rebuild

**Q: Where do I find test credentials?**
A: In your Firebase Console:
1. Authentication section
2. Users tab shows all test accounts
3. Create new ones as needed

---

## 📚 Additional Resources

- **Flutter Docs:** https://flutter.dev/docs
- **Firebase Console:** https://console.firebase.google.com
- **Android Studio Docs:** https://developer.android.com/studio/intro
- **Flutter Testing:** https://flutter.dev/docs/testing

---

**Version:** 1.0.0  
**Created:** May 1, 2026  
**Status:** Complete & Ready to Use
