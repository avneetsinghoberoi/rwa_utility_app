import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReceiptPdfService {
  static String _ts(dynamic v) {
    // we keep it simple; you can format Timestamp properly later
    return v?.toString() ?? "";
  }

  static Future<File> generateReceiptPdf({
    required String receiptId,
    required Map<String, dynamic> r,
  }) async {
    final pdf = pw.Document();

    final societyName = (r["societyName"] ?? "RWA Utility App").toString();
    final userName = (r["userName"] ?? "User").toString();
    final flat = (r["flat"] ?? "").toString();
    final amount = (r["amount"] ?? 0).toString();
    final method = (r["method"] ?? "-").toString();
    final txnId = (r["txnId"] ?? "-").toString();
    final status = (r["status"] ?? "VERIFIED").toString();
    final createdAt = _ts(r["createdAt"]);
    final paymentId = (r["paymentId"] ?? "-").toString();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Maintenance Payment Receipt",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Text(societyName, style: const pw.TextStyle(fontSize: 12)),
                pw.Divider(),

                pw.SizedBox(height: 8),
                pw.Text("Receipt ID: $receiptId"),
                pw.Text("Payment ID: $paymentId"),
                pw.Text("Status: $status"),
                if (createdAt.isNotEmpty) pw.Text("Created: $createdAt"),

                pw.SizedBox(height: 14),
                pw.Text("Paid By", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text("Name: $userName"),
                if (flat.isNotEmpty) pw.Text("Flat: $flat"),

                pw.SizedBox(height: 14),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Amount: ₹$amount",
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text("Method: $method"),
                      pw.Text("Transaction ID: $txnId"),
                    ],
                  ),
                ),

                pw.Spacer(),
                pw.Divider(),
                pw.Text("System-generated receipt. No signature required.",
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/receipt_$receiptId.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> openPdf(File file) async {
    await OpenFilex.open(file.path);
  }
}