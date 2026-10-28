import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> exporterRapportPdf({
  required String titre,
  required List<String> entetes,
  required List<List<String>> lignes,
  String? sousTitre,
}) async {
  final pdf = pw.Document();
  final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Salon Perruques BF',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  titre,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                if (sousTitre != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(sousTitre, style: const pw.TextStyle(fontSize: 10)),
                ],
              ],
            ),
            pw.Text(
              'Généré le $now',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: entetes,
          data: lignes,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellHeight: 18,
          cellAlignments: {
            for (var i = 0; i < entetes.length; i++) i: pw.Alignment.centerLeft,
          },
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Total lignes : ${lignes.length}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
    name: '${titre.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
  );
}
