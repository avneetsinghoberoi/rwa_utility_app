# GateBasic App - Launch Issues & Solutions

## 🔴 CRITICAL ISSUES PREVENTING APP LAUNCH

### Issue 1: Missing Keystore Files (Release Build Blocker)
**Severity:** CRITICAL for Release builds | Medium for Debug builds

**Problem:**
- File `/Users/avneet/gatebasic-release-keystore.jks` referenced in `android/app/build.gradle` **DOES NOT EXIST**
- File `/Users/avneet/rwa-release-keystore.jks` referenced in `android/key.properties` **DOES NOT EXIST**
- **Path mismatch:** build.gradle uses `gatebasic-release-keystore.jks` but key.properties uses `rwa-release-keystore.jks`

**Impact:**
- Release APK/AAB builds will **FAIL**
- The signing configuration cannot be resolved
- App cannot be deployed to Play Store

**Solution:**
1. Create a new Android keystore file using keytool:
   ```bash
   keytool -genkey -v -keystore ~/gatebasic-release-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias gatebasic-key
   ```
2. Update `android/app/build.gradle` to match the keystore path in key.properties, OR
3. Update `android/key.properties` to use the correct path consistently

**Current Configuration:**
- `android/app/build.gradle` line 42:
  ```gradle
  storeFile file('/Users/avneet/gatebasic-release-keystore.jks')
  ```
- `android/key.properties`:
  ```properties
  storeFile=/Users/avneet/rwa-release-keystore.jks
  ```

---

### Issue 2: Missing iOS Permissions in Info.plist
**Severity:** HIGH (App will crash at runtime when accessing certain features)

**Problem:**
The `ios/Runner/Info.plist` is missing required permission descriptions for:
- 📷 Camera access (image_picker dependency)
- 🖼️ Photo Library access (image_picker dependency)
- 🔔 Notification permissions (firebase_messaging & flutter_local_notifications)
- 📄 File access (if needed by pdf and printing dependencies)

**Impact:**
- App will crash when trying to pick images
- Notifications may not work properly
- User privacy warnings won't be shown
- App may be rejected from App Store for missing permissions

**Solution:**
Add the following keys to `ios/Runner/Info.plist` inside the `<dict>` tag:

```xml
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
```

---

### Issue 3: iOS Bundle ID Mismatch
**Severity:** HIGH (iOS app won't launch properly)

**Problem:**
- `ios/Runner/General` settings show bundle ID as: `com.example.rmsApp`
- `lib/firebase_options.dart` iOS config shows: `iosBundleId: 'com.example.rmsApp'`
- This doesn't match Android bundle ID: `com.gatebasic.app`

**Impact:**
- iOS Firebase authentication will fail
- Push notifications won't be received
- Analytics data will be mixed up

**Solution:**
Update `lib/firebase_options.dart` iOS configuration:
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyA6pQ5xLk2ainN0AN61Om-tqun_OlWeni8',
  appId: '1:1085944093717:ios:43370b71e0f785532d421c',
  messagingSenderId: '1085944093717',
  projectId: 'rms-app-3d585',
  storageBucket: 'rms-app-3d585.firebasestorage.app',
  iosBundleId: 'com.gatebasic.app',  // ← CHANGE THIS
);

static const FirebaseOptions macos = FirebaseOptions(
  apiKey: 'AIzaSyA6pQ5xLk2ainN0AN61Om-tqun_OlWeni8',
  appId: '1:1085944093717:ios:43370b71e0f785532d421c',
  messagingSenderId: '1085944093717',
  projectId: 'rms-app-3d585',
  storageBucket: 'rms-app-3d585.firebasestorage.app',
  iosBundleId: 'com.gatebasic.app',  // ← CHANGE THIS
);
```

---

### Issue 4: Missing Android Permissions
**Severity:** MEDIUM (Some features will fail)

**Problem:**
`android/app/src/main/AndroidManifest.xml` is missing several permissions that the app uses:
- `INTERNET` - For Firebase and API calls
- `CAMERA` - For image_picker
- `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` - For photo gallery access
- `WRITE_EXTERNAL_STORAGE` - For saving PDFs
- `ACCESS_FINE_LOCATION` - If location features are used

**Solution:**
Add these permissions to `AndroidManifest.xml` before the `<application>` tag:

```xml
<!-- Internet access for Firebase and API calls -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- Camera permissions for image_picker -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Storage permissions for image and file operations -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<!-- Android 13+ uses READ_MEDIA_* instead -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

<!-- Optional: if location is used -->
<!-- <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" /> -->
<!-- <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" /> -->
```

---

## 📊 ISSUES SUMMARY

| Issue | Platform | Severity | Status |
|-------|----------|----------|--------|
| Missing keystore files | Android | 🔴 CRITICAL | Not Fixed |
| Keystore path mismatch | Android | 🔴 CRITICAL | Not Fixed |
| Missing iOS permissions | iOS | 🔴 CRITICAL | Not Fixed |
| Bundle ID mismatch | iOS | 🔴 CRITICAL | Not Fixed |
| Missing Android permissions | Android | 🟡 MEDIUM | Not Fixed |

---

## ✅ QUICK FIX CHECKLIST

- [ ] Create release keystore files
- [ ] Fix build.gradle keystore path
- [ ] Add iOS permissions to Info.plist
- [ ] Update iOS bundle ID in firebase_options.dart
- [ ] Add missing Android permissions to AndroidManifest.xml
- [ ] Test debug build on Android device/emulator
- [ ] Test debug build on iOS device/simulator
- [ ] Test release build on both platforms

---

## 🚀 NEXT STEPS

1. **Immediately:** Create the keystore file and update configurations
2. **Then:** Add missing permissions to both platforms
3. **Finally:** Test builds using:
   - `flutter run` (debug Android)
   - `flutter run -d ios` (debug iOS)
   - `flutter build apk --release` (release Android APK)
   - `flutter build appbundle --release` (release Android AAB)
   - `flutter build ios --release` (release iOS)

---

*Report Generated: 2026-05-10*
*App: GateBasic (gate_basic)*
*Version: 1.0.0+1*
