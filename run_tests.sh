#!/bin/bash
# Run all GateBasic tests with coverage report

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GateBasic — Test Runner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "▶ Unit tests — User model"
flutter test test/unit/models/user_model_test.dart --reporter=expanded

echo ""
echo "▶ Unit tests — Login validation"
flutter test test/unit/auth/login_validation_test.dart --reporter=expanded

echo ""
echo "▶ Unit tests — Finance calculator"
flutter test test/unit/reports/finance_calculator_test.dart --reporter=expanded

echo ""
echo "▶ Widget tests — Admin reports"
flutter test test/widget/admin_reports_test.dart --reporter=expanded

echo ""
echo "▶ Widget tests — Login screen"
flutter test test/widget/login_screen_test.dart --reporter=expanded

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  All test suites complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
