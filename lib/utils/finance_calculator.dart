/// Pure finance calculation helpers extracted from AdminReportsScreen
/// so they can be unit-tested independently of Firestore or widgets.
class FinanceCalculator {
  const FinanceCalculator._();

  /// Processes a list of invoice maps and returns a [FinanceSummary].
  static FinanceSummary summariseInvoices(
      List<Map<String, dynamic>> invoices) {
    int paid = 0, submitted = 0, unpaid = 0;
    double billed = 0, collected = 0;

    for (final inv in invoices) {
      final status = (inv['status'] ?? '').toString();
      final amount = (inv['amount'] ?? 0).toDouble();
      billed += amount;

      if (status == 'PAID') {
        paid++;
        collected += amount;
      } else if (status == 'SUBMITTED') {
        submitted++;
      } else {
        unpaid++;
      }
    }

    return FinanceSummary(
      totalBilled: billed,
      totalCollected: collected,
      totalPending: billed - collected,
      paidCount: paid,
      submittedCount: submitted,
      unpaidCount: unpaid,
    );
  }

  /// Sums the `amount` field across a list of expense maps.
  static double totalExpenses(List<Map<String, dynamic>> expenses) {
    return expenses.fold(
        0.0, (sum, e) => sum + (e['amount'] ?? 0).toDouble());
  }

  /// Net balance = collected - expenses. Positive = surplus, negative = deficit.
  static double netBalance(double collected, double expenses) =>
      collected - expenses;

  /// Collection rate as a 0–1 fraction. Returns 0 if nothing is billed.
  static double collectionRate(double collected, double billed) =>
      billed == 0 ? 0 : collected / billed;
}

class FinanceSummary {
  final double totalBilled;
  final double totalCollected;
  final double totalPending;
  final int paidCount;
  final int submittedCount;
  final int unpaidCount;

  const FinanceSummary({
    required this.totalBilled,
    required this.totalCollected,
    required this.totalPending,
    required this.paidCount,
    required this.submittedCount,
    required this.unpaidCount,
  });

  int get totalInvoices => paidCount + submittedCount + unpaidCount;
}
