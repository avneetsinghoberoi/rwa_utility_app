# Quick Directory Feature Test - 5 Minutes

## ⚡ Super Quick Start

### 1. Open Terminal & Navigate
```bash
cd /Users/avneet/Downloads/rwa_utility_app-main
```

### 2. Run the App
```bash
flutter run
```
Wait 1-2 minutes for build to complete.

---

## 🔐 Login (Use Your Existing Test Account)

When app loads:
- **Toggle:** Select "Resident" 
- **Email:** Your test resident account (e.g., `resident1@example.com`)
- **Password:** Your password
- **Tap:** Login

---

## 📂 Test the Directory Feature

### Step 1: Navigate to Directory Tab
Look at the **bottom navigation bar** - you should see **7 tabs** now:

```
🏠  💳  🐛  📢  👥  📋  👤
                 ↑
           Tap this (Directory)
```

### Step 2: Tap Directory Tab (👥)
The **Members Directory** screen should load showing:
- List of all residents
- Name, house number, phone, email for each
- Search bar at top
- Sort button in top right

---

## ✅ Quick Tests

### ✓ Test 1: See All Members (30 seconds)
```
Expected: See list of residents with details
- Names visible
- House numbers visible  
- Phone numbers visible
- Email addresses visible
- Avatar circles with initials

If this works → ✅ Directory loads correctly
```

### ✓ Test 2: Search by Name (30 seconds)
```
Action: Tap search bar, type a resident's name (e.g., "john")
Expected: List filters to show only that name
Result shows "john" matches like "John Kumar"

If this works → ✅ Search works
```

### ✓ Test 3: Search by House (30 seconds)
```
Action: Clear search, type house number (e.g., "A-20")
Expected: Shows all houses starting with "A-20" like "A-201", "A-202"

If this works → ✅ House search works
```

### ✓ Test 4: Sort by Name (30 seconds)
```
Action: Tap sort icon (top right) → Select "Sort by Name"
Expected: List reorders alphabetically (Ajay, Bhavna, David, etc.)

If this works → ✅ Sort by name works
```

### ✓ Test 5: Sort by House (30 seconds)
```
Action: Tap sort icon → Select "Sort by House No"
Expected: List reorders by house (A-101, A-102, B-101, etc.)

If this works → ✅ Sort by house works
```

### ✓ Test 6: Copy Phone (30 seconds)
```
Action: Tap any resident's phone number
Expected: Green snackbar appears with ✅ "Copied: +91..."

If this works → ✅ Copy works
```

### ✓ Test 7: Copy Email (30 seconds)
```
Action: Tap any resident's email
Expected: Green snackbar appears with ✅ "Copied: email@..."

If this works → ✅ Copy email works
```

---

## 🎯 Summary - All Tests Pass If:

```
✅ Directory tab appears in navigation (7 tabs total)
✅ Members list displays with names, houses, phones, emails
✅ Search filters by name correctly
✅ Search filters by house correctly
✅ Sort by name works (A-Z)
✅ Sort by house works
✅ Can copy phone number
✅ Can copy email
✅ No red errors in console
```

---

## 🚨 If Something's Wrong

| Problem | Quick Fix |
|---------|-----------|
| Directory tab missing | Press **R** in terminal (hot reload) |
| No members show | Firestore needs resident accounts with role="user" |
| Permission denied error | Run: `firebase deploy --only firestore:rules` |
| Search doesn't work | Press **Shift+R** (hot restart) |
| Copy doesn't work | Normal in emulator, works on real phone |

---

## 📱 Quick Commands

```bash
# Hot reload (fast)
R

# Hot restart (also fast)
Shift+R

# Stop
Q

# If broken, full rebuild
Ctrl+C
flutter clean
flutter pub get
flutter run
```

---

## ✨ Done!

If all 8 tests pass → **Directory feature is working perfectly!** 🎉

Need more details? Check:
- `TESTING_GUIDE_ANDROID.md` - Full testing guide
- `DIRECTORY_FEATURE.md` - Feature documentation
- `UPDATED_DASHBOARD.md` - UI changes
