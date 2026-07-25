import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TicketPrinterService {
  /// Generate a PDF ticket for thermal printing (58mm roll)
  static Future<Uint8List> generateTicketPdf({
    required String ticketNumber,
    required String busNumber,
    required String fromStop,
    required String toStop,
    required double fare,
    required String passengerName,
    required String date,
    required String time,
    int passengerCount = 1,
  }) async {
    final pdf = pw.Document();

    const roll58 = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: roll58,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('SPOTX TRANSIT',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text('━━━━━━━━━━━━━━━━━━━',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('TICKET',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 6),
              _ticketRow('Ticket #:', ticketNumber),
              pw.SizedBox(height: 2),
              _ticketRow('Bus:', busNumber),
              pw.SizedBox(height: 2),
              _ticketRow('Date:', date),
              pw.SizedBox(height: 2),
              _ticketRow('Time:', time),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('━━━━━━━━━━━━━━━━━━━',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ),
              pw.SizedBox(height: 4),
              pw.Text('FROM:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text(fromStop, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('↓',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey400)),
              ),
              pw.SizedBox(height: 4),
              pw.Text('TO:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text(toStop, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('━━━━━━━━━━━━━━━━━━━',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ),
              pw.SizedBox(height: 4),
              _ticketRow('Passengers:', '$passengerCount'),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('₹${fare.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('Thank you for traveling with SpotX!',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _ticketRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// Print the ticket to a connected thermal printer
  static Future<void> printTicket({
    required String ticketNumber,
    required String busNumber,
    required String fromStop,
    required String toStop,
    required double fare,
    required String passengerName,
    required String date,
    required String time,
    int passengerCount = 1,
  }) async {
    try {
      final pdfBytes = await generateTicketPdf(
        ticketNumber: ticketNumber,
        busNumber: busNumber,
        fromStop: fromStop,
        toStop: toStop,
        fare: fare,
        passengerName: passengerName,
        date: date,
        time: time,
        passengerCount: passengerCount,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'SpotX Ticket $ticketNumber',
      );

      debugPrint('[PRINTER] Ticket printed: $ticketNumber');
    } catch (e) {
      debugPrint('[PRINTER] Print failed: $e');
      rethrow;
    }
  }

  /// Check if printing is available
  static Future<bool> isAvailable() async {
    try {
      return await Printing.info().then((info) => info.canPrint);
    } catch (e) {
      return false;
    }
  }
}
