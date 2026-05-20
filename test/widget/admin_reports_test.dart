import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_basic/utils/finance_calculator.dart';

// ── A minimal widget that renders a finance summary card ──────────────────────
// We test the display logic without needing Firebase by using the pure
// FinanceCalculator utility and rendering a simple summary widget.

class _FinanceSummaryWidget extends StatelessWidget {
  final FinanceSummary summary;
  final double expenses;

  const _FinanceSummaryWidget(
      {required this.summary, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final net = FinanceCalculator.netBalance(summary.totalCollected, expenses);
    return Column(
      children: [
        Text('Total Billed: ₹${summary.totalBilled.toStringAsFixed(0)}',
            key: const Key('total_billed')),
        Text('Collected: ₹${summary.totalCollected.toStringAsFixed(0)}',
            key: const Key('collected')),
        Text('Pending: ₹${summary.totalPending.toStringAsFixed(0)}',
            key: const Key('pending')),
        Text('Expenses: ₹${expenses.toStringAsFixed(0)}',
            key: const Key('expenses')),
        Text(
          net >= 0
              ? 'Surplus: ₹${net.toStringAsFixed(0)}'
              : 'Deficit: ₹${net.abs().toStringAsFixed(0)}',
          key: const Key('net_balance'),
        ),
        Text('Paid: ${summary.paidCount}', key: const Key('paid_count')),
        Text('Unpaid: ${summary.unpaidCount}',
            key: const Key('unpaid_count')),
      ],
    );
  }
}

void main() {
  group('Finance summary widget', () {
    final invoices = [
      {'status': 'PAID', 'amount': 1500.0},
      {'status': 'PAID', 'amount': 1500.0},
      {'status': 'SUBMITTED', 'amount': 1500.0},
      {'status': 'UNPAID', 'amount': 1500.0},
    ];
    final summary = FinanceCalculator.summariseInvoices(invoices);
    const expenses = 1200.0;

    testWidgets('renders correct total billed', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _FinanceSummaryWidget(summary: summary, expenses: expenses),
        ),
      ));

      expect(find.byKey(const Key('total_billed')), findsOneWidget);
      expect(find.text('Total Billed: ₹6000'), findsOneWidget);
    });

    testWidgets('renders correct collected amount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _FinanceSummaryWidget(summary: summary, expenses: expenses),
        ),
      ));

      expect(find.text('Collected: ₹3000'), findsOneWidget);
    });

    testWidgets('renders correct pending amount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _FinanceSummaryWidget(summary: summary, expenses: expenses),
        ),
      ));

      expect(find.text('Pending: ₹3000'), findsOneWidget);
    });

    testWidgets('shows surplus when collected > expenses', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _FinanceSummaryWidget(summary: summary, expenses: expenses),
        ),
      ));

      // Net = 3000 collected - 1200 expenses = 1800 surplus
      expect(find.text('Surplus: ₹1800'), findsOneWidget);
    });

    testWidgets('shows deficit when expenses > collected', (tester) async {
      final lowInvoices = [
        {'status': 'PAID', 'amount': 500.0},
      ];
      final lowSummary = FinanceCalculator.summariseInvoices(lowInvoices);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body:
              _FinanceSummaryWidget(summary: lowSummary, expenses: 2000.0),
        ),
      ));

      expect(find.text('Deficit: ₹1500'), findsOneWidget);
    });

    testWidgets('renders paid and unpaid counts', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _FinanceSummaryWidget(summary: summary, expenses: expenses),
        ),
      ));

      expect(find.text('Paid: 2'), findsOneWidget);
      expect(find.text('Unpaid: 1'), findsOneWidget);
    });
  });
}
