# GateBasic App - Step-by-Step Fixes

## Fix #1: Create Release Keystore (Required for Release Builds)

### Step 1: Generate the Keystore File
Run this command in your terminal:

```bash
keytool -genkey -v -keystore ~/gatebasic-release-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias gatebasic-key
```

You'll be prompted for passwords and information. Use these defaults or create your own:
```
Keystore password: gatebasic@123
Key password: gatebasic@123
First and Last Name: GateBasic
Organizational Unit: GateBasic
Organization: GateBasic
City: New Delhi
State/Province: Delhi
Country Code: IN
```

**This creates:** `/Users/avneet/gatebasic-release-keystore.jks`

---

## Fix #2: Update Android Build Configuration

### File: `android/app/build.gradle`

**Current (WRONG):**
```gradle
signingConfigs {
    release {
        keyAlias 'gatebasic-key'
        keyPassword 'gatebasic@123'
        storeFile file('/Users/avneet/gatebasic-release-keystore.jks')
        storePassword 'gatebasic@123'
    }
}
```

**After Fix (matches key.properties):**
```gradle
signingConfigs {
    release {
        keyAlias 'rwa_key'
        keyPassword 'RwaApp@2026'
        storeFile file('/Users/avneet/rwa-release-keystore.jks')
        storePassword 'RwaApp@2026'
    }
}
```

OR create the keystore with matching credentials:
```bash
keytool -genkey -v -keystore ~/rwa-release-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias rwa_key
```

---

## Fix #3: Add iOS Permissions

### File: `ios/Runner/Info.plist`

**Add this entire block inside the `<dict>` section (before closing `</dict>`):**

```xml
	<!-- Camera permissions -->
	<key>NSCameraUsageDescription</key>
	<string>We need access to your camera to take photos for your profile and property issues.</string>

	<!-- Photo Library permissions -->
	<key>NSPhotoLibraryUsageDescription</key>
	<string>We need access to your photo library to select images for your profile and property issues.</string>
	<key>NSPhotoLibraryAddUsageDescription</key>
	<string>We need permission to save photos to your photo library.</string>

	<!-- Notification permissions -->
	<key>NSUserNotificationsUsageDescription</key>
	<string>We send notifications about society dues, notices, complaints, and payment updates.</string>

	<!-- Local network access -->
	<key>NSLocalNetworkUsageDescription</key>
	<string>App requires local network access for communication.</string>
	<key>NSBonjourServiceTypes</key>
	<array>
		<string>_http._tcp</string>
		<string>_https._tcp</string>
	</array>
```

**Your Info.plist should now look like:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<!-- ... existing keys ... -->
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>

	<!-- ADD NEW PERMISSIONS HERE -->
	<key>NSCameraUsageDescription</key>
	<string>We need access to your camera to take photos for your profile and property issues.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>We need access to your photo library to select images for your profile and property issues.</string>
	<key>NSPhotoLibraryAddUsageDescription</key>
	<string>We need permission to save photos to your photo library.</string>
	<key>NSUserNotificationsUsageDescription</key>
	<string>We send notifications about society dues, notices, complaints, and payment updates.</string>
	<key>NSLocalNetworkUsageDescription</key>
	<string>App requires local network access for communication.</string>
	<key>NSBonjourServiceTypes</key>
	<array>
		<string>_http._tcp</string>
		<string>_https._tcp</string>
	</array>
</dict>
</plist>
```

---

## Fix #4: Update iOS Bundle ID in Firebase Config

### File: `lib/firebase_options.dart`

**Find and update these two configurations:**

**Current (WRONG):**
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyA6pQ5xLk2ainN0AN61Om-tqun_OlWeni8',
  appId: '1:1085944093717:ios:43370b71e0f785532d421c',
  messagingSenderId: '1085944093717',
  projectId: 'rms-app-3d585',
  storageBucket: 'rms-app-3d585.firebasestorage.app',
  iosBundleId: 'com.example.rmsApp',  // ❌ WRONG
);
```

**After Fix:**
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyA6pQ5xLk2ainN0AN61Om-tqun_OlWeni8',
  appId: '1:1085944093717:ios:43370b71e0f785532d421c',
  messagingSenderId: '1085944093717',
  projectId: 'rms-app-3d585',
  storageBucket: 'rms-app-3d585.firebasestorage.app',
  iosBundleId: 'com.gatebasic.app',  // ✅ CORRECT
);

static const FirebaseOptions macos = FirebaseOptions(
  apiKey: 'AIzaSyA6pQ5xLk2ainN0AN61Om-tqun_OlWeni8',
  appId: '1:1085944093717:ios:43370b71e0f785532d421c',
  messagingSenderId: '1085944093717',
  projectId: 'rms-app-3d585',
  storageBucket: 'rms-app-3d585.firebasestorage.app',
  iosBundleId: 'com.gatebasic.app',  // ✅ CORRECT
);
```

---

## Fix #5: Add Android Permissions

### File: `android/app/src/main/AndroidManifest.xml`

**Current (INCOMPLETE):**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.gatebasic.app">

    <!-- Required for push notifications on Android 13+ (API 33+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application>
```

**After Fix (ADD THESE PERMISSIONS):**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.gatebasic.app">

    <!-- Network and Firebase -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- Notifications -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <!-- Camera for image picker -->
    <uses-permission android:name="android.permission.CAMERA" />

    <!-- Storage for images and PDF files -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <!-- Android 13+ (API 33+) uses these instead -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

    <!-- Optional: Location (uncomment if needed) -->
    <!-- <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" /> -->
    <!-- <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" /> -->

    <application
```

---

## 📋 Testing Checklist

After applying all fixes, test the following:

### Debug Build Test
```bash
# Android
flutter clean
flutter pub get
flutter run -d <android-device-id>

# iOS
flutter clean
flutter pub get
flutter run -d <ios-device-id>
```

### Release Build Test
```bash
# Android APK
flutter clean
flutter pub get
flutter build apk --release

# Android Bundle (for Play Store)
flutter build appbundle --release

# iOS
flutter clean
flutter pub get
flutter build ios --release
```

### Feature Tests
- [ ] Launch app successfully
- [ ] Login with Firebase Auth
- [ ] Navigate to all screens without crashes
- [ ] Test image picker (camera and gallery)
- [ ] Test PDF generation and printing
- [ ] Receive push notifications
- [ ] Check app analytics in Firebase Console

---

## 🆘 If You Get Build Errors

### Android Build Fails
1. Check `android/key.properties` - ensure paths match your system
2. Run `flutter clean` and try again
3. Check Gradle wrapper: `./gradlew --version`
4. Try: `flutter pub get && flutter clean && flutter build apk --release -v`

### iOS Build Fails
1. Ensure Xcode is updated: `xcode-select --install`
2. Run `cd ios && pod install --repo-update && cd ..`
3. Clear iOS build: `rm -rf ios/Pods ios/Podfile.lock`
4. Try: `flutter clean && flutter pub get && flutter run -d ios`

### Firebase Issues
1. Ensure Firebase project is created
2. Verify `google-services.json` (Android) is in `android/app/src/`
3. Verify `GoogleService-Info.plist` (iOS) is added to Xcode
4. Check Firebase Console for app registration

---

## 📞 Support Resources

- Flutter Documentation: https://flutter.dev/docs
- Firebase Setup: https://firebase.flutter.dev
- Android Keystore: https://developer.android.com/studio/publish/app-signing
- iOS Permissions: https://developer.apple.com/documentation/bundleresources/information_property_list

---

*Last Updated: 2026-05-10*
