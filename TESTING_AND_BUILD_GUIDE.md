# GateBasic App - Complete Testing & Build Guide

## ✅ Configuration Fixes Applied

All 5 critical fixes have been applied to your project:

1. ✅ **android/key.properties** - Updated with correct keystore configuration
2. ✅ **android/app/build.gradle** - Fixed signing configuration to use key.properties
3. ✅ **ios/Runner/Info.plist** - Added all 6 required iOS permissions
4. ✅ **lib/firebase_options.dart** - Fixed iOS bundle ID to com.gatebasic.app
5. ✅ **android/app/src/main/AndroidManifest.xml** - Added 6 required Android permissions

---

## 🔑 STEP 1: Create the Keystore (CRITICAL!)

**This is the most important step.** Copy and paste ONE of these commands into Terminal:

### Option A: Using Python Script (Recommended)
```bash
cd ~/Downloads/rwa_utility_app-main && python3 create_keystore.py
```

### Option B: Direct keytool Command
```bash
keytool -genkey -v -keystore ~/gatebasic-release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias gatebasic-key -keypass gatebasic@123 -storepass gatebasic@123 -dname "CN=GateBasic, OU=GateBasic, O=GateBasic, L=New Delhi, ST=Delhi, C=IN"
```

**Expected output:**
```
Generating 2,048 bit RSA key pair and self-signed certificate...
Storing /Users/avneet/gatebasic-release-keystore.jks
✅ SUCCESS! Keystore created successfully!
```

---

## 🧹 STEP 2: Clean Up Previous Build Cache

Run this command in Terminal:

```bash
cd ~/Downloads/rwa_utility_app-main
flutter clean
flutter pub get
```

This removes old build artifacts and re-downloads dependencies.

---

## 🤖 STEP 3: Test Android Debug Build

### 3a. Check Connected Devices

```bash
flutter devices
```

You should see your Android device or emulator listed. Example output:
```
Found 2 connected devices:
  Android (mobile)   • emulator-5554   • android-x86_64   • Android 13 (API 33)
  Web Server Local   • web-server      • web              • Chrome
```

### 3b. Run on Android Device/Emulator

```bash
flutter run
```

**What to watch for:**
- ✅ App launches and shows splash screen
- ✅ Firebase authentication initializes
- ✅ Navigation works smoothly
- ❌ No crash on startup
- ❌ No permission errors

### 3c. Test App Features

Once app is running, test:
- [ ] Tap login button - should open Firebase auth
- [ ] Try image picker (if available in UI) - should request camera/photo permissions
- [ ] Check console logs in Android Studio/Terminal for errors

---

## 🍎 STEP 4: Test iOS Debug Build (Optional, if you have iOS device/simulator)

### 4a. List iOS Devices

```bash
flutter devices
```

### 4b. Install iOS Pods

```bash
cd ~/Downloads/rwa_utility_app-main/ios
pod install --repo-update
cd ../
```

### 4c. Run on iOS

```bash
flutter run -d <ios-device-id>
```

Or if you have simulator running:
```bash
open -a Simulator
flutter run
```

---

## 📦 STEP 5: Build Release APK (for Play Store testing)

Once debug build is successful, test release:

```bash
cd ~/Downloads/rwa_utility_app-main
flutter build apk --release
```

**Expected output:**
```
✓ Built build/app/outputs/flutter-apk/app-release.apk (XX.XMB)
```

Location: `build/app/outputs/flutter-apk/app-release.apk`

### Install Release APK on Device

```bash
flutter install build/app/outputs/flutter-apk/app-release.apk
```

---

## 📱 STEP 6: Build Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

**Expected output:**
```
✓ Built build/app/outputs/bundle/release/app-release.aab (XX.XMB)
```

Location: `build/app/outputs/bundle/release/app-release.aab`

This is what you upload to Google Play Store.

---

## 🔍 Troubleshooting Common Issues

### Issue: "keystore file not found"
**Solution:** Run the keystore creation command from Step 1

### Issue: "Gradle build failed"
**Solution:**
```bash
flutter clean
rm -rf pubspec.lock
flutter pub get
flutter run
```

### Issue: "Device not found"
**Solution:**
- Android: Make sure USB debugging is enabled and device is connected
- iOS: Make sure Xcode is installed and updated

### Issue: "Firebase initialization failed"
**Solution:**
- Ensure `google-services.json` exists in `android/app/src/`
- Ensure `GoogleService-Info.plist` is added to iOS Xcode project

### Issue: "Pod installation failed"
**Solution:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter clean
flutter pub get
```

### Issue: "Java not found"
**Solution:**
- Install Java: `brew install openjdk@17`
- Verify: `java -version`

---

## ✅ Testing Checklist

### Before First Test
- [ ] Keystore file created at `~/gatebasic-release-keystore.jks`
- [ ] `flutter clean` completed
- [ ] `flutter pub get` completed
- [ ] Device/emulator connected
- [ ] No build cache errors

### During Debug Test
- [ ] App launches without crashing
- [ ] Splash screen shows
- [ ] Firebase initializes successfully
- [ ] No red error screens visible
- [ ] Navigation works
- [ ] Terminal shows no exceptions

### During Release Build
- [ ] `flutter build apk --release` succeeds
- [ ] APK file generated at expected location
- [ ] APK can be installed on device
- [ ] Release app works same as debug

### Final Verification
- [ ] App launches on cold start
- [ ] All screens are accessible
- [ ] Network operations work (Firebase queries)
- [ ] Permissions requested correctly
- [ ] No crashes in console

---

## 🚀 Commands Quick Reference

```bash
# Navigate to project
cd ~/Downloads/rwa_utility_app-main

# Create keystore
python3 create_keystore.py

# Clean and prepare
flutter clean && flutter pub get

# Test on device
flutter run

# Build release
flutter build apk --release
flutter build appbundle --release

# Check devices
flutter devices

# View logs
flutter logs
```

---

## 📊 Build Output Locations

```
build/
├── app/
│   ├── outputs/
│   │   ├── flutter-apk/
│   │   │   └── app-release.apk          ← For Play Store testing
│   │   └── bundle/
│   │       └── release/
│   │           └── app-release.aab      ← For Play Store upload
│   └── intermediates/                   ← Temporary build files
└── ... (other platforms)
```

---

## 🎯 Next Steps After Testing

1. Once debug APK runs successfully → test on real Android device
2. Once release APK builds → test on real device
3. Once everything works → upload to Google Play Store
4. For iOS → repeat same process with iOS simulator/device

---

## 📞 Support

If you encounter any issues:
1. Check troubleshooting section above
2. Check console logs: `flutter logs`
3. Run with verbose output: `flutter run -v`
4. Check Firebase Console for auth issues
5. Check Android Studio/Xcode for build errors

---

*Last Updated: 2026-05-10*
*App: GateBasic (gate_basic)*
*Version: 1.0.0+1*
