import 'package:flutter_test/flutter_test.dart';
import 'package:gate_basic/utils/login_validator.dart';

void main() {
  group('LoginValidator', () {
    // ── Valid input ──────────────────────────────────────────────────────────
    test('returns null for valid email and password', () {
      expect(
        LoginValidator.validate(
            email: 'user@example.com', password: 'secret123'),
        isNull,
      );
    });

    test('trims whitespace before validating', () {
      expect(
        LoginValidator.validate(
            email: '  user@example.com  ', password: '  pass123  '),
        isNull,
      );
    });

    // ── Empty fields ─────────────────────────────────────────────────────────
    test('returns error when both fields are empty', () {
      expect(
        LoginValidator.validate(email: '', password: ''),
        equals('Please enter email and password'),
      );
    });

    test('returns error when email is empty', () {
      expect(
        LoginValidator.validate(email: '', password: 'pass123'),
        equals('Please enter email and password'),
      );
    });

    test('returns error when password is empty', () {
      expect(
        LoginValidator.validate(email: 'user@example.com', password: ''),
        equals('Please enter email and password'),
      );
    });

    // ── Email format ──────────────────────────────────────────────────────────
    test('returns error when email has no @', () {
      expect(
        LoginValidator.validate(
            email: 'userexample.com', password: 'pass123'),
        equals('Please enter a valid email'),
      );
    });

    test('returns error when email has no dot after @', () {
      expect(
        LoginValidator.validate(email: 'user@example', password: 'pass123'),
        equals('Please enter a valid email'),
      );
    });

    // ── Password length ───────────────────────────────────────────────────────
    test('returns error when password is shorter than 6 characters', () {
      expect(
        LoginValidator.validate(
            email: 'user@example.com', password: '12345'),
        equals('Password must be at least 6 characters'),
      );
    });

    test('accepts password of exactly 6 characters', () {
      expect(
        LoginValidator.validate(
            email: 'user@example.com', password: '123456'),
        isNull,
      );
    });
  });
}
