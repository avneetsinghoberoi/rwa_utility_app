#!/bin/bash

# GateBasic Release Keystore Creation Script
# This script creates the keystore file required for signing Android release builds

echo "═══════════════════════════════════════════════════════════════"
echo "Creating GateBasic Release Keystore"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Create the keystore file
keytool -genkey -v \
  -keystore ~/gatebasic-release-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias gatebasic-key \
  -keypass gatebasic@123 \
  -storepass gatebasic@123 \
  -dname "CN=GateBasic, OU=GateBasic, O=GateBasic, L=New Delhi, ST=Delhi, C=IN"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Keystore created successfully!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Keystore location: ~/gatebasic-release-keystore.jks"
echo "Keystore password: gatebasic@123"
echo "Key alias: gatebasic-key"
echo "Key password: gatebasic@123"
echo ""
echo "You can now run: flutter build apk --release"
echo "═══════════════════════════════════════════════════════════════"
