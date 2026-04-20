import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPdfService {
  // ── Format a Firestore Timestamp or DateTime as "17 Apr 2026" ─────
  static String _formatDate(dynamic v) {
    if (v is Timestamp) return DateFormat('dd MMM yyyy').format(v.toDate());
    if (v is DateTime)  return DateFormat('dd MMM yyyy').format(v);
    if (v is String && v.isNotEmpty) return v;
    return '-';
  }

  static String _formatCurrency(dynamic v) {
    final n = num.tryParse(v?.toString() ?? '') ?? 0;
    return '₹${NumberFormat('#,##0').format(n)}';
  }

  // ─────────────────────────────────────────────────────────────────
  //  Generate receipt PDF
  //  [r] is the receipt Firestore document data.
  //  Extra fields now supported: purpose, invoice_type, description,
  //  due_date, verified_at, house_no, name.
  // ─────────────────────────────────────────────────────────────────
  static Future<File> generateReceiptPdf({
    required String receiptId,
    required Map<String, dynamic> r,
    // Optionally pass extra invoice data fetched by caller
    Map<String, dynamic>? invoiceData,
  }) async {
    // Noto Sans supports ₹, —, – and all Unicode characters the pdf package
    // default Helvetica cannot render.
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont    = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    // ── Pull fields ────────────────────────────────────────────────
    final invoiceType   = (r['invoice_type'] ?? invoiceData?['type'] ?? 'MAINTENANCE').toString();
    final isDemand      = invoiceType == 'DEMAND';
    final purpose       = (r['purpose'] ?? invoiceData?['title'] ?? (isDemand ? 'Special Due' : 'Monthly Maintenance')).toString();
    final description   = (r['description'] ?? invoiceData?['description'] ?? '').toString();
    final societyName   = (r['societyName'] ?? 'RWA Utility App').toString();
    final userName      = (r['name'] ?? r['userName'] ?? '').toString();
    final houseNo       = (r['house_no'] ?? r['flat'] ?? '').toString();
    final amount        = _formatCurrency(r['amount']);
    final methodStr     = (r['method'] ?? '—').toString();
    final utr           = (r['utr'] ?? r['txnId'] ?? '—').toString();
    final status        = (r['status'] ?? 'VERIFIED').toString();
    final paymentDate   = _formatDate(r['updated_at'] ?? r['created_at']);
    final dueDate       = _formatDate(r['due_date'] ?? invoiceData?['due_date']);
    final month         = (r['month'] ?? invoiceData?['month'] ?? '').toString();

    // Month label for maintenance dues
    String monthLabel = '';
    if (!isDemand && month.isNotEmpty) {
      try {
        monthLabel = DateFormat('MMMM yyyy').format(DateTime.parse('$month-01'));
      } catch (_) {
        monthLabel = month;
      }
    }

    // ── Color scheme ───────────────────────────────────────────────
    final PdfColor headerColor = isDemand
        ? const PdfColor.fromInt(0xFF7C3AED)   // purple for demand dues
        : const PdfColor.fromInt(0xFF1A56DB);  // blue for maintenance
    final PdfColor lightBg = isDemand
        ? const PdfColor.fromInt(0xFFF3E8FF)
        : const PdfColor.fromInt(0xFFEBF3FF);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Header band ────────────────────────────────────────
            pw.Container(
              color: headerColor,
              padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PAYMENT RECEIPT',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            societyName,
                            style: pw.TextStyle(fontSize: 12, color: const PdfColor(1, 1, 1, 0.7)),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                        ),
                        child: pw.Text(
                          status,
                          style: pw.TextStyle(
                            color: status == 'VERIFIED'
                                ? const PdfColor.fromInt(0xFF059669)
                                : const PdfColor.fromInt(0xFFEF4444),
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 14),
                  pw.Text('Receipt ID: $receiptId',
                      style: pw.TextStyle(fontSize: 10, color: const PdfColor(1, 1, 1, 0.7))),
                ],
              ),
            ),

            // ── Body ───────────────────────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // ── Purpose section ────────────────────────────
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: lightBg,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          isDemand ? 'Special Demand Due' : 'Monthly Maintenance',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: headerColor,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          purpose,
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                        ),
                        if (monthLabel.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(monthLabel, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                        ],
                        if (description.isNotEmpty) ...[
                          pw.SizedBox(height: 6),
                          pw.Text(description, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                        ],
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 20),

                  // ── Resident info ──────────────────────────────
                  _pdfSectionTitle('Resident Details'),
                  pw.SizedBox(height: 8),
                  _pdfRow('Name', userName.isNotEmpty ? userName : '-'),
                  _pdfRow('House / Flat', houseNo.isNotEmpty ? houseNo : '-'),

                  pw.SizedBox(height: 20),

                  // ── Payment info ───────────────────────────────
                  _pdfSectionTitle('Payment Details'),
                  pw.SizedBox(height: 8),
                  _pdfRow('Amount Paid', amount, bold: true),
                  _pdfRow('Payment Method', methodStr),
                  _pdfRow('Transaction ID / UTR', utr),
                  _pdfRow('Payment Date', paymentDate),
                  if (dueDate != '-') _pdfRow('Due Date', dueDate),

                  pw.SizedBox(height: 24),

                  // ── Amount box ─────────────────────────────────
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFF059669),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL PAID', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13)),
                        pw.Text(amount, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 40),

                  // ── Footer ────────────────────────────────────
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'This is a system-generated receipt. No signature is required.\n'
                    'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/receipt_$receiptId.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _pdfSectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
    );
  }

  static pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> openPdf(File file) async {
    await OpenFilex.open(file.path);
  }
}
