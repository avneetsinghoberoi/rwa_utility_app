#!/usr/bin/env python3
"""
GateBasic Release Keystore Creator
Run this script to create the keystore file needed for Android release builds
"""

import subprocess
import sys
from pathlib import Path

def create_keystore():
    home_dir = Path.home()
    keystore_path = home_dir / "gatebasic-release-keystore.jks"

    print("=" * 70)
    print("🔐 GateBasic Release Keystore Creator")
    print("=" * 70)
    print()
    print(f"Creating keystore at: {keystore_path}")
    print()

    # Check if keystore already exists
    if keystore_path.exists():
        print(f"⚠️  WARNING: Keystore file already exists at {keystore_path}")
        response = input("Do you want to overwrite it? (yes/no): ").strip().lower()
        if response != "yes":
            print("❌ Operation cancelled.")
            return False

    # Create the keystore using keytool
    cmd = [
        'keytool', '-genkey', '-v',
        '-keystore', str(keystore_path),
        '-keyalg', 'RSA',
        '-keysize', '2048',
        '-validity', '10000',
        '-alias', 'gatebasic-key',
        '-keypass', 'gatebasic@123',
        '-storepass', 'gatebasic@123',
        '-dname', 'CN=GateBasic, OU=GateBasic, O=GateBasic, L=New Delhi, ST=Delhi, C=IN'
    ]

    try:
        print("Creating keystore (this may take a moment)...")
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

        if result.returncode == 0:
            print()
            print("=" * 70)
            print("✅ SUCCESS! Keystore created successfully!")
            print("=" * 70)
            print()
            print(f"📍 Location: {keystore_path}")
            print(f"🔑 Keystore Password: gatebasic@123")
            print(f"🏷️  Key Alias: gatebasic-key")
            print(f"🔐 Key Password: gatebasic@123")
            print()
            print("You can now run:")
            print("  flutter clean")
            print("  flutter pub get")
            print("  flutter run          # for debug on Android")
            print("  flutter build apk --release   # for release APK")
            print()
            return True
        else:
            print(f"❌ Error creating keystore:")
            print(result.stderr)
            return False

    except subprocess.TimeoutExpired:
        print("❌ Timeout: keystore creation took too long")
        return False
    except FileNotFoundError:
        print("❌ Error: 'keytool' not found. Make sure Java is installed.")
        print("   Install Java from: https://www.java.com/")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = create_keystore()
    sys.exit(0 if success else 1)
