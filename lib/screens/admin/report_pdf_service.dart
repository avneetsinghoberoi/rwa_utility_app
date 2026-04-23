import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Noto Sans supports ₹ (U+20B9), — (U+2014), – (U+2013) and all common
// Unicode characters. Loaded once per PDF generation call.

// ─────────────────────────────────────────────────────────────────────────────
//  Data model for a single resident's dues entry
// ─────────────────────────────────────────────────────────────────────────────
class ResidentDuesEntry {
  final String houseNo;
  final String name;
  final String email;
  final num amount;
  final num paidAmount;
  final String status; // PAID | PARTIAL | UNPAID | NO_BILL

  ResidentDuesEntry({
    required this.houseNo,
    required this.name,
    required this.email,
    required this.amount,
    required this.paidAmount,
    required this.status,
  });

  num get balance => (amount - paidAmount).clamp(0, double.infinity);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Report PDF Service
// ─────────────────────────────────────────────────────────────────────────────
class ReportPdfService {
  static final _curr = NumberFormat('₹#,##0');

  // ── Tint a PdfColor towards white by [factor] (0 = original, 1 = white) ───
  static PdfColor _tint(PdfColor c, double factor) => PdfColor(
    c.red   + (1.0 - c.red)   * factor,
    c.green + (1.0 - c.green) * factor,
    c.blue  + (1.0 - c.blue)  * factor,
  );

  // ── Color constants ────────────────────────────────────────────────────────
  static const _headerColor  = PdfColor.fromInt(0xFF1A56DB);
  static const _paidColor    = PdfColor.fromInt(0xFF059669);
  static const _partialColor = PdfColor.fromInt(0xFFD97706);
  static const _unpaidColor  = PdfColor.fromInt(0xFFDC2626);
  static const _noBillColor  = PdfColor.fromInt(0xFF94A3B8);
  static const _rowAlt       = PdfColor.fromInt(0xFFF8FAFF);

  static PdfColor _statusColor(String s) {
    switch (s) {
      case 'PAID':    return _paidColor;
      case 'PARTIAL': return _partialColor;
      case 'UNPAID':  return _unpaidColor;
      default:        return _noBillColor;
    }
  }

  // ── Fetch all data for a given month ───────────────────────────────────────
  static Future<List<ResidentDuesEntry>> fetchMonthData(String monthKey) async {
    final db = FirebaseFirestore.instance;

    final usersSnap = await db.collection('users').where('role', isEqualTo: 'user').get();

    final invoicesSnap = await db
        .collection('invoices')
        .where('month', isEqualTo: monthKey)
        .get();

    final Map<String, Map<String, dynamic>> invoiceMap = {};
    for (final doc in invoicesSnap.docs) {
      final d = doc.data();
      final uid = d['uid']?.toString() ?? '';
      if (uid.isNotEmpty) invoiceMap[uid] = d;
    }

    final entries = usersSnap.docs.map((doc) {
      final u   = doc.data();
      final inv = invoiceMap[doc.id];
      return ResidentDuesEntry(
        houseNo:    u['house_no']?.toString() ?? '-',
        name:       u['name']?.toString()     ?? '-',
        email:      u['email']?.toString()    ?? '-',
        amount:     num.tryParse(inv?['amount']?.toString()      ?? '') ?? 0,
        paidAmount: num.tryParse(inv?['paid_amount']?.toString() ?? '') ?? 0,
        status:     inv != null ? (inv['status']?.toString() ?? 'UNPAID') : 'NO_BILL',
      );
    }).toList();

    entries.sort((a, b) => a.houseNo.compareTo(b.houseNo));
    return entries;
  }

  // ── Generate PDF and return File ───────────────────────────────────────────
  static Future<File> generateReport({
    required String monthKey,
    required String societyName,
    required List<ResidentDuesEntry> entries,
  }) async {
    // Load Unicode-capable fonts (downloaded once and cached by the printing package)
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont    = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    // ── Derived stats ──────────────────────────────────────────────────────
    final billed     = entries.where((e) => e.status != 'NO_BILL');
    final paid       = entries.where((e) => e.status == 'PAID');
    final partial    = entries.where((e) => e.status == 'PARTIAL');
    final unpaid     = entries.where((e) => e.status == 'UNPAID');
    final noBill     = entries.where((e) => e.status == 'NO_BILL');
    final defaulters = entries.where((e) => e.status == 'UNPAID' || e.status == 'PARTIAL').toList();

    final totalCollected = billed.fold<num>(0, (s, e) => s + e.paidAmount);
    final totalPending   = billed.fold<num>(0, (s, e) => s + e.balance);
    final totalBilled    = billed.fold<num>(0, (s, e) => s + e.amount);

    String monthLabel = monthKey;
    try {
      monthLabel = DateFormat('MMMM yyyy').format(DateTime.parse('$monthKey-01'));
    } catch (e) {
      debugPrint('Could not format month label for "$monthKey": $e');
    }

    final generatedOn = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    // ── Status badge widget ────────────────────────────────────────────────
    // ignore: unused_element
    pw.Widget statusBadge(String status) {
      final color = _statusColor(status);
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          color: _tint(color, 0.85),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          status == 'NO_BILL' ? 'NO BILL' : status,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [

          // ── HEADER BAND ────────────────────────────────────────────────
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: _headerColor,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DUES REPORT',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.SizedBox(height: 4),
                    pw.Text(societyName,
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(monthLabel,
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.SizedBox(height: 4),
                    pw.Text('Generated: $generatedOn',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ── SUMMARY STAT BOXES ─────────────────────────────────────────
          pw.Row(
            children: [
              _statBox('Total Residents', '${entries.length}', PdfColors.blueGrey700),
              pw.SizedBox(width: 10),
              _statBox('Collected', _curr.format(totalCollected), _paidColor),
              pw.SizedBox(width: 10),
              _statBox('Pending', _curr.format(totalPending), _unpaidColor),
              pw.SizedBox(width: 10),
              _statBox('Defaulters', '${defaulters.length}', _partialColor),
            ],
          ),

          pw.SizedBox(height: 8),

          // ── QUICK COUNT ROW ────────────────────────────────────────────
          pw.Row(
            children: [
              _dot('Paid',    '${paid.length}',    _paidColor),
              pw.SizedBox(width: 10),
              _dot('Partial', '${partial.length}', _partialColor),
              pw.SizedBox(width: 10),
              _dot('Unpaid',  '${unpaid.length}',  _unpaidColor),
              pw.SizedBox(width: 10),
              _dot('No Invoice', '${noBill.length}', _noBillColor),
              pw.Spacer(),
              pw.Text('Total Billed: ${_curr.format(totalBilled)}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            ],
          ),

          pw.SizedBox(height: 16),

          // ── TABLE ─────────────────────────────────────────────────────
          pw.Text('RESIDENT-WISE DUES SUMMARY',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            headers: ['Flat/Unit', 'Resident Name', 'Invoice Amt', 'Paid', 'Balance', 'Status'],
            data: entries.map((e) => [
              e.houseNo,
              e.name,
              e.amount > 0 ? _curr.format(e.amount) : '-',
              e.paidAmount > 0 ? _curr.format(e.paidAmount) : '-',
              e.balance > 0 ? _curr.format(e.balance) : '-',
              e.status == 'NO_BILL' ? 'No Bill' : e.status,
            ]).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _headerColor),
            cellStyle: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.center,
            },
            cellHeight: 22,
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: _rowAlt),
          ),

          pw.SizedBox(height: 20),

          // ── DEFAULTERS SECTION ─────────────────────────────────────────
          if (defaulters.isNotEmpty) ...[
            pw.Container(
              decoration: pw.BoxDecoration(
                color: _tint(_unpaidColor, 0.93),
                border: const pw.Border(
                  left: pw.BorderSide(color: _unpaidColor, width: 3),
                ),
              ),
              padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DEFAULTERS / PENDING (${defaulters.length})',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold, color: _unpaidColor),
                  ),
                  pw.SizedBox(height: 8),
                  ...defaulters.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 6, height: 6,
                          decoration: pw.BoxDecoration(
                            color: _statusColor(e.status),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Text(
                            '${e.houseNo}  -  ${e.name}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
                          ),
                        ),
                        pw.Text(
                          'Balance: ${_curr.format(e.balance)}  |  ${e.status}',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: _statusColor(e.status),
                              fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── FOOTER ────────────────────────────────────────────────────
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 6),
          pw.Text(
            'System-generated report from live data. '
            'Covers monthly maintenance invoices for $monthLabel. '
            'Generated on $generatedOn.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );

    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/dues_report_$monthKey.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Share PDF via system share sheet ──────────────────────────────────────
  static Future<void> sharePdf(File file, String monthLabel) async {
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: 'dues_report_$monthLabel.pdf',
    );
  }

  // ── Stat box ──────────────────────────────────────────────────────────────
  static pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: pw.BoxDecoration(
          color: _tint(color, 0.9),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: _tint(color, 0.7), width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  // ── Coloured dot + count ──────────────────────────────────────────────────
  static pw.Widget _dot(String label, String value, PdfColor color) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 8, height: 8,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text('$label: $value',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }
}
