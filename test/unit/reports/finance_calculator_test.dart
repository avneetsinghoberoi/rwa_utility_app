import 'package:flutter_test/flutter_test.dart';
import 'package:gate_basic/utils/finance_calculator.dart';

void main() {
  // ── summariseInvoices ────────────────────────────────────────────────────
  group('FinanceCalculator.summariseInvoices', () {
    test('correctly counts paid, submitted, and unpaid', () {
      final invoices = [
        {'status': 'PAID', 'amount': 1500.0},
        {'status': 'PAID', 'amount': 1500.0},
        {'status': 'SUBMITTED', 'amount': 1500.0},
        {'status': 'UNPAID', 'amount': 1500.0},
      ];

      final summary = FinanceCalculator.summariseInvoices(invoices);

      expect(summary.paidCount, equals(2));
      expect(summary.submittedCount, equals(1));
      expect(summary.unpaidCount, equals(1));
      expect(summary.totalInvoices, equals(4));
    });

    test('totalBilled equals sum of all invoice amounts', () {
      final invoices = [
        {'status': 'PAID', 'amount': 1500.0},
        {'status': 'UNPAID', 'amount': 1500.0},
        {'status': 'SUBMITTED', 'amount': 1500.0},
      ];

      final summary = FinanceCalculator.summariseInvoices(invoices);
      expect(summary.totalBilled, equals(4500.0));
    });

    test('totalCollected only sums PAID invoices', () {
      final invoices = [
        {'status': 'PAID', 'amount': 1500.0},
        {'status': 'PAID', 'amount': 1500.0},
        {'status': 'UNPAID', 'amount': 1500.0},
      ];

      final summary = FinanceCalculator.summariseInvoices(invoices);
      expect(summary.totalCollected, equals(3000.0));
    });

    test('totalPending = totalBilled - totalCollected', () {
      final invoices = [
        {'status': 'PAID', 'amount': 1500.0},
        {'status': 'UNPAID', 'amount': 1500.0},
      ];

      final summary = FinanceCalculator.summariseInvoices(invoices);
      expect(summary.totalPending, equals(1500.0));
    });

    test('handles empty invoice list', () {
      final summary = FinanceCalculator.summariseInvoices([]);
      expect(summary.totalBilled, equals(0.0));
      expect(summary.totalCollected, equals(0.0));
      expect(summary.totalInvoices, equals(0));
    });

    test('handles invoice with missing amount field (defaults to 0)', () {
      final invoices = [
        {'status': 'PAID'},
        {'status': 'UNPAID', 'amount': 1500.0},
      ];

      final summary = FinanceCalculator.summariseInvoices(invoices);
      expect(summary.totalBilled, equals(1500.0));
      expect(summary.paidCount, equals(1));
    });

    test('unknown status is treated as unpaid', () {
      final invoices = [
        {'status': 'MYSTERY', 'amount': 1000.0},
      ];

      final summary = FinanceCalculator.summariseInvoices(invoices);
      expect(summary.unpaidCount, equals(1));
      expect(summary.paidCount, equals(0));
    });
  });

  // ── totalExpenses ─────────────────────────────────────────────────────────
  group('FinanceCalculator.totalExpenses', () {
    test('sums all expense amounts', () {
      final expenses = [
        {'amount': 800.0, 'label': 'Cleaning'},
        {'amount': 400.0, 'label': 'Security'},
        {'amount': 300.0, 'label': 'Electricity'},
      ];
      expect(FinanceCalculator.totalExpenses(expenses), equals(1500.0));
    });

    test('returns 0 for empty list', () {
      expect(FinanceCalculator.totalExpenses([]), equals(0.0));
    });

    test('handles missing amount field', () {
      final expenses = [
        {'label': 'Unknown'},
        {'amount': 500.0, 'label': 'Water'},
      ];
      expect(FinanceCalculator.totalExpenses(expenses), equals(500.0));
    });
  });

  // ── netBalance ────────────────────────────────────────────────────────────
  group('FinanceCalculator.netBalance', () {
    test('positive when collected > expenses (surplus)', () {
      expect(FinanceCalculator.netBalance(3000.0, 1200.0), equals(1800.0));
    });

    test('negative when expenses > collected (deficit)', () {
      expect(FinanceCalculator.netBalance(1000.0, 2000.0), equals(-1000.0));
    });

    test('zero when collected equals expenses', () {
      expect(FinanceCalculator.netBalance(1500.0, 1500.0), equals(0.0));
    });
  });

  // ── collectionRate ────────────────────────────────────────────────────────
  group('FinanceCalculator.collectionRate', () {
    test('returns 1.0 when fully collected', () {
      expect(FinanceCalculator.collectionRate(4500.0, 4500.0), equals(1.0));
    });

    test('returns correct fraction for partial collection', () {
      expect(FinanceCalculator.collectionRate(1500.0, 4500.0),
          closeTo(0.333, 0.001));
    });

    test('returns 0 when nothing is billed (avoids divide-by-zero)', () {
      expect(FinanceCalculator.collectionRate(0.0, 0.0), equals(0.0));
    });
  });
}
